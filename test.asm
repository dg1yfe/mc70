;*****************************
; TEST
;*****************************
                .ORG $1000
                ldx  #$FEDC
                ldd  #$BA98
                .db  0,1,2,3,4,5,6,7,8,9,$a,$b,$c,$d,$e,$f  ; Input Ringbuffer - 16 Byte
                .db  0,1,2,3,4,5,6,7,8,9,$a,$b,$c,$d,$e,$f  ; Input Ringbuffer - 16 Byte
_pgm_hex_file
                pshx                      ; Adresse für temporären Speicher (RAM) - 5
                                          ; Größe entsprechend längster Zeile im Hexfile
                pshx                      ;
                pshx                      ;
                psha                      ; 5 Byte für lokale Variablen
                                          ; (Zieladresse, Checksumme, Offset, Bytecount)
                                          ;       4,3           2         1        0
_phf_begin
                jsr  _phf_getchar-$2000
                cmpa #':'                 ; Record Begin?
                bne  _phf_begin           ; Nein, dann warten
; get Bytecount
                jsr  _phf_get_byte-$2000  ; nächstes Byte (2 Zeichen) holen - Bytecount
                tsx
                stab 0,x                  ; Bytecount auf Stack speichern
                stab 2,x                  ; Neue Checksumme speichern
; get Address
                jsr  _phf_get_byte-$2000  ; nächstes Byte (2 Zeichen) holen - Adress HiByte
                tsx
                stab 3,x                  ; Adress HiByte auf Stack speichern
                addb 2,x                  ; zu Checksumme addieren
                stab 2,x                  ; Neue Checksumme speichern

                jsr  _phf_get_byte-$2000  ; nächstes Byte (2 Zeichen) holen - Adress LoByte
                tsx
                stab 4,x                  ; Adress LoByte auf Stack speichern
                addb 2,x                  ; zu Checksumme addieren
                stab 2,x                  ; Neue Checksumme speichern
; get Type
                jsr  _phf_get_byte-$2000  ; nächstes Byte (2 Zeichen) holen - Record Type
                tba
                adda 2,x                  ; zu Checksumme addieren
                staa 2,x                  ; Neue Checksumme speichern

                cmpb #$01                 ; Termination ? (Type 1)
                beq  _phf_terminate
                tstb                      ; no Data ? (no Type 0)
                bne  _phf_begin           ; Operation abbrechen
; get Data
                tsx
                ldaa 0,x                  ; Bytecount von Anfang an = 0 ?
                beq  _phf_checksum        ; Ja dann Checksumme holen
                clr  1,x                  ; Offset=0
_phf_data_lp
                jsr  _phf_get_byte-$2000  ; nächstes Datenbyte holen

                tba                       ; Byte nach A
                tsx
                ldab 1,x                  ; Offset holen
                ldx  5,x                  ; Adresse vom temporären Speicher holen
                abx                       ; Adresse+Offset
                staa 0,x                  ; Byte im temporären Speicher ablegen

                tsx
                adda 2,x                  ; Checksumme addieren
                staa 2,x                  ; Neue Checksumme speichern
                inc  1,x                  ; Offset++

                dec  0,x                  ; Bytecount--

                bne  _phf_data_lp         ; Loop bis Bytecount erreicht
_phf_checksum
                jsr  _phf_get_byte-$2000  ; Checksumme holen
                tsx
                addb 2,x                  ; Checksumme addieren, sollte 0 ergeben
                bne  _phf_check_failed    ; CRC nicht ok - Fehlermeldung ausgeben und zurück zum Anfang

                                          ; Checksumme ist ok, Zeile in Speicher schreiben (nur RAM)
                ldd  5,x                  ; Quelladresse = temporärer Speicher
                pshb
                psha                      ; Als 1. Parameter auf Stack legen

                clra
                ldab 1,x                  ; Offset vom letzten Byte (Bytecount) holen
                addd 5,x                  ; Startadresse addieren -> Endadresse
                pshb
                psha                      ; Quell-Endadresse auf Stack

                ldd  3,x                  ; Zieladresse holen
                pshb
                psha                      ; und als 3. Parameter auf den Stack legen
                pulx
                pulx
                pulx                      ; Parameter vom Stack löschen

                ldab #'+'
                jmp  _phf_begin-$2000     ; Auf nächste Zeile warten
_phf_check_failed
                ldab #'-'
                jmp  _phf_begin-$2000     ; Auf nächste Zeile warten
_phf_terminate
                jsr  _phf_get_byte-$2000  ; nächstes Datenbyte holen, muß $FF sein (CRC für $01)
                cmpb #$FF
                bne  _phf_check_failed
                ldab #$0c
                ldab #$0a
                ldab #'O'
                ldab #'K'
_phf_end
                pula
                pulx
                pulx
                pulx                      ; lokale Variablen etc. vom Stack löschen
                rts                       ; Rücksprung


;******************************
; C H A R   T O   N I B B L E
;******************************
;
; wandelt HexDigit ('0'-'F') in Nibble vom Wert 0-15 um
;
; Parameter    : A - Hex Digit
;                B - HiNibble (optional)
;
; Ergebnis     : A - Hex Value (LoNibble)
;                B - LoNibble OR HiNibble (Bytevalue)
;
; changed Regs : A, B
;
_phf_char_to_nibble
                cmpa #'9'+1
                bcs  _phf_ctn_numeric     ; Alphabetisches Zeichen (A-F/a-f) ?
                anda #%01011111           ; in Großbuchstaben "umwandeln"
                suba #$7                  ; 7 abziehen (A=58)
_phf_ctn_numeric
                suba #$30                 ; 48 ($30) abziehen und Hex Nibble erstellen
                lslb
                lslb
                lslb
                lslb                      ; HiNibble 4 Positionen nach links
                psha
                aba                       ; mit LoNibble kombinieren
                tab
                pula
                rts

;****************
; G E T C H A R
;****************
; Char einlesen und auf gültigkeit überprüfen,
; gültig sind '0'-'9', ':', 'A'-'F'
; Abgebrochen werden kann mit Escape ($1B)
;
; Parameter    : none
;
; Ergebnis     :  A - Char
;                IP - Bei Fehler oder Escape, Rücksprung zu geänderter Adresse
;
; changed Regs : A, IP (!!!)
;
_phf_getchar
                pshb
                jsr  _sci_rdne-$2000
                cmpb #$1b
                beq  _pgc_escape
                cmpb #$10
                beq  _pgc_invalid
                cmpb #$13
                beq  _pgc_invalid
                cmpb #'0'                 ; Char muß >=$30 (48 bzw '0') sein
                bcs  _pgc_invalid
                cmpb #':'+1               ; >='0' und <= ':' dann ok
                bcs  _pgc_end
                cmpb #'A'                 ; >=A und
                bcs  _pgc_invalid
                cmpb #'F'+1               ; <=F dann ok
                bcs  _pgc_end
                cmpb #'a'                 ; >=a und
                bcs  _pgc_invalid
                cmpb #'f'+1               ; <=f dann ok
                bcs  _pgc_end
_pgc_invalid
                pulb
                pulx                      ; fiese Sache: Rücksprungadresse holen
                ldx  #_phf_begin-$2000    ; Adresse für phf_begin holen
                pshx                      ; und als neue Rücksprungadresse verwenden
                pshb
_pgc_end
                tba                       ; Char nach A
                pulb                      ; B wiederherstellen
                rts
_pgc_escape
                pulb
                pulx                      ; nochmal fiese Sache: Rücksprungadresse holen
                ldx  #_phf_end-$2000      ; Adresse vom Routinenende holen
                pshx                      ; und als neue Rücksprungadresse festlegen
                pshb
                bra  _pgc_end
;*****************
; G E T   B Y T E
;*****************
; 2 Chars einlesen (mit _phf_getchar), auf Gültigkeit überprüfen und Byte zurückgeben
;
; Parameter    : none
;
; Ergebnis     :  B - Byte
;                IP - Bei Fehler oder Escape, Rücksprung zu geänderter Adresse
;
; changed Regs : A, B, X, IP (!!!)
;
_phf_get_byte
                pulx                      ; Rücksprungadresse nach X
                                          ; Hintergrund: phf_get_char springt bei Fehler/Escape direkt zu
                                          ; _phf_begin / _phf_end zurück und erspart so mehrfaches Tests
                                          ; des zurückgegebenen Status, der jedesmal zum selben Ergebnis
                                          ; (Sprung zu _phf_begin oder _phf_end) führen würde
                                          ; Das klappt wunderbar für direkte Aufrufe von _get_char, nach
                                          ; Aufruf von _phf_get_byte befindet sich jedoch zusätzlich die
                                          ; entsprechende Rücksprungadresse auf dem Stack und würde von
                                          ; _get_char NICHT entfernt werden. Daher muß sie manuell entfernt
                                          ; und bei erfolgreichem Abschluß der Routine wieder hinzugefügt
                                          ; werden.
                                          ; ...ich hoffe das war verstärnlich. Ist etwas 'tricky' aber erspart
                                          ; eine Menge gleichförmigen Code

                jsr  _phf_getchar-$2000   ; nächstes Zeichen holen
                jsr  _phf_char_to_nibble-$2000; HiNibble holen
                tab                       ; HiNibble nach B
                jsr  _phf_getchar-$2000   ; nächstes Zeichen holen
                jsr  _phf_char_to_nibble-$2000; LoNibble konvertieren (or HiNibble -> Bytewert in B)

                pshx                      ; Rücksprungadresse wieder auf Stack
                rts

;************************
; S C I   R E A D
;************************
_sci_rdne        ;B : rxd Byte
                ;changed Regs: A, B

                jsr  _sci_rx-$2000
                tsta
                beq  _sci_rdne
		rts


                .end
