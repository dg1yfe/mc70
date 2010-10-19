;*****************************
; TEST
;*****************************
                .ORG $1000
                ldx  #$FEDC
                ldd  #$BA98
                .db  0,1,2,3,4,5,6,7,8,9,$a,$b,$c,$d,$e,$f  ; Input Ringbuffer - 16 Byte
                .db  0,1,2,3,4,5,6,7,8,9,$a,$b,$c,$d,$e,$f  ; Input Ringbuffer - 16 Byte
_pgm_hex_file
                pshx                      ; Adresse f�r tempor�ren Speicher (RAM) - 5
                                          ; Gr��e entsprechend l�ngster Zeile im Hexfile
                pshx                      ;
                pshx                      ;
                psha                      ; 5 Byte f�r lokale Variablen
                                          ; (Zieladresse, Checksumme, Offset, Bytecount)
                                          ;       4,3           2         1        0
_phf_begin
                jsr  _phf_getchar-$2000
                cmpa #':'                 ; Record Begin?
                bne  _phf_begin           ; Nein, dann warten
; get Bytecount
                jsr  _phf_get_byte-$2000  ; n�chstes Byte (2 Zeichen) holen - Bytecount
                tsx
                stab 0,x                  ; Bytecount auf Stack speichern
                stab 2,x                  ; Neue Checksumme speichern
; get Address
                jsr  _phf_get_byte-$2000  ; n�chstes Byte (2 Zeichen) holen - Adress HiByte
                tsx
                stab 3,x                  ; Adress HiByte auf Stack speichern
                addb 2,x                  ; zu Checksumme addieren
                stab 2,x                  ; Neue Checksumme speichern

                jsr  _phf_get_byte-$2000  ; n�chstes Byte (2 Zeichen) holen - Adress LoByte
                tsx
                stab 4,x                  ; Adress LoByte auf Stack speichern
                addb 2,x                  ; zu Checksumme addieren
                stab 2,x                  ; Neue Checksumme speichern
; get Type
                jsr  _phf_get_byte-$2000  ; n�chstes Byte (2 Zeichen) holen - Record Type
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
                jsr  _phf_get_byte-$2000  ; n�chstes Datenbyte holen

                tba                       ; Byte nach A
                tsx
                ldab 1,x                  ; Offset holen
                ldx  5,x                  ; Adresse vom tempor�ren Speicher holen
                abx                       ; Adresse+Offset
                staa 0,x                  ; Byte im tempor�ren Speicher ablegen

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
                bne  _phf_check_failed    ; CRC nicht ok - Fehlermeldung ausgeben und zur�ck zum Anfang

                                          ; Checksumme ist ok, Zeile in Speicher schreiben (nur RAM)
                ldd  5,x                  ; Quelladresse = tempor�rer Speicher
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
                pulx                      ; Parameter vom Stack l�schen

                ldab #'+'
                jmp  _phf_begin-$2000     ; Auf n�chste Zeile warten
_phf_check_failed
                ldab #'-'
                jmp  _phf_begin-$2000     ; Auf n�chste Zeile warten
_phf_terminate
                jsr  _phf_get_byte-$2000  ; n�chstes Datenbyte holen, mu� $FF sein (CRC f�r $01)
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
                pulx                      ; lokale Variablen etc. vom Stack l�schen
                rts                       ; R�cksprung


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
                anda #%01011111           ; in Gro�buchstaben "umwandeln"
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
; Char einlesen und auf g�ltigkeit �berpr�fen,
; g�ltig sind '0'-'9', ':', 'A'-'F'
; Abgebrochen werden kann mit Escape ($1B)
;
; Parameter    : none
;
; Ergebnis     :  A - Char
;                IP - Bei Fehler oder Escape, R�cksprung zu ge�nderter Adresse
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
                cmpb #'0'                 ; Char mu� >=$30 (48 bzw '0') sein
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
                pulx                      ; fiese Sache: R�cksprungadresse holen
                ldx  #_phf_begin-$2000    ; Adresse f�r phf_begin holen
                pshx                      ; und als neue R�cksprungadresse verwenden
                pshb
_pgc_end
                tba                       ; Char nach A
                pulb                      ; B wiederherstellen
                rts
_pgc_escape
                pulb
                pulx                      ; nochmal fiese Sache: R�cksprungadresse holen
                ldx  #_phf_end-$2000      ; Adresse vom Routinenende holen
                pshx                      ; und als neue R�cksprungadresse festlegen
                pshb
                bra  _pgc_end
;*****************
; G E T   B Y T E
;*****************
; 2 Chars einlesen (mit _phf_getchar), auf G�ltigkeit �berpr�fen und Byte zur�ckgeben
;
; Parameter    : none
;
; Ergebnis     :  B - Byte
;                IP - Bei Fehler oder Escape, R�cksprung zu ge�nderter Adresse
;
; changed Regs : A, B, X, IP (!!!)
;
_phf_get_byte
                pulx                      ; R�cksprungadresse nach X
                                          ; Hintergrund: phf_get_char springt bei Fehler/Escape direkt zu
                                          ; _phf_begin / _phf_end zur�ck und erspart so mehrfaches Tests
                                          ; des zur�ckgegebenen Status, der jedesmal zum selben Ergebnis
                                          ; (Sprung zu _phf_begin oder _phf_end) f�hren w�rde
                                          ; Das klappt wunderbar f�r direkte Aufrufe von _get_char, nach
                                          ; Aufruf von _phf_get_byte befindet sich jedoch zus�tzlich die
                                          ; entsprechende R�cksprungadresse auf dem Stack und w�rde von
                                          ; _get_char NICHT entfernt werden. Daher mu� sie manuell entfernt
                                          ; und bei erfolgreichem Abschlu� der Routine wieder hinzugef�gt
                                          ; werden.
                                          ; ...ich hoffe das war verst�rnlich. Ist etwas 'tricky' aber erspart
                                          ; eine Menge gleichf�rmigen Code

                jsr  _phf_getchar-$2000   ; n�chstes Zeichen holen
                jsr  _phf_char_to_nibble-$2000; HiNibble holen
                tab                       ; HiNibble nach B
                jsr  _phf_getchar-$2000   ; n�chstes Zeichen holen
                jsr  _phf_char_to_nibble-$2000; LoNibble konvertieren (or HiNibble -> Bytewert in B)

                pshx                      ; R�cksprungadresse wieder auf Stack
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
