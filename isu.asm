;****************************************************************************
;
;    MC70 - Firmware for the Motorola MC micro trunking radio
;           to use it as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2011  Felix Erckenbrecht, DG1YFE
;
;     This file is part of MC70.
;
;     MC70 is free software: you can redistribute it and/or modify
;     it under the terms of the GNU General Public License as published by
;     the Free Software Foundation, either version 3 of the License, or
;     (at your option) any later version.
; 
;     MC70 is distributed in the hope that it will be useful,
;     but WITHOUT ANY WARRANTY; without even the implied warranty of
;     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;     GNU General Public License for more details.
; 
;     You should have received a copy of the GNU General Public License
;     along with MC70.  If not, see <http://www.gnu.org/licenses/>.
; 
;
;
;****************************************************************************
;**********************************************************
; In System Update Modul
;**********************************************************
; erstellt: 06.02.2007
; letzte Änderung: 07.02.2007
;
; In System Programmierung des Flash (AMD - AM29F010B)
;
; - Flash Programmierung direkt mittels HEX Files
; - serielle Kommunikation mit Host (1200,n,8,1)
; - Stackbereich im internen RAM $0040 - $0140 (4kB Bereich $1000-$1FFF frei verfügbar)
; - IRQs verboten
; - Löschen von Sektoren im Flash
; - Löschen des kompletten Flash
; - Empfang von Daten im Intel HEX Format (derzeit nur RAM)
;
#DEFINE ISUOFS $2000
#DEFINE jsrr(adr) jsr adr-ISUOFS
#DEFINE jmpr(adr) jmp adr-ISUOFS
#DEFINE ldxr(adr) ldx #adr-ISUOFS
;
;
isu_module      .MODULE isu
isu_begin       .ORG ISUOFS+$0200
                sei
                lds  #$013F                      ; Stack auf internes RAM ($0140) setzen

                ldab #12                         ; SCI initialisieren, 4800 Bit/s
                stab TCONR
                ldab #%10000
                stab TCSR3
                ldab #%100100                    ; 8 Bit, Async, Clock=T2
                stab RMCR
                ldab #%000                       ; 1Stop Bit, keine Parity
                stab TRCSR2
                ldab #%1010
                stab TRCSR1                      ; TX & RX enabled, no Int
                aim  #%11111011,Port6_Data       ; Page 0 anwählen
                ldab Port6_DDR_buf               ; /OE override (P61) und A16 (P62)
                orab #%00000110                  ; auf
                stab Port6_DDR_buf               ; Ausgang
                stab Port6_DDR                   ; schalten
                aim  #%11111001,Port6_Data       ; /OE freigeben, Page 0 anwählen

                ldd  #isu_end-ISUOFS
                pshb
                tab
                jsrr(_print_hex)
                pulb
                jsrr(_print_hex)                  ; Letzte von der Routine genutzte Adresse senden
_loop
                ldxr(_cmds_str)                   ;
                jsrr(_print)                      ; Kommandos ausgeben (E - Erase, P - Program)
                jsrr(_sci_rdne)                   ; Eingabe holen
                cmpb #$20
                bcs  _loop                        ; < Leerzeichen nicht beachten (CR/LF)
                orab #$20                         ; in Kleinbuchstaben wandeln
                cmpb #'e'                         ; Erase?
                beq  _erase                       ;
                cmpb #'p'                         ; Oder Program?
                beq  _program
                cmpb #'r'
                bne  _loop                        ; Alles andere ignorieren
                jmpr(_run_debug)

;
;************************************************
;
_erase
                ldxr(_er_choice_str)              ; Chip oder Sector Erase ?
                jsrr(_print)
                jsrr(_sci_rdne)
                cmpb #'0'
                bcs  _loop
                cmpb #'8'                         ; Auf Eingabe für Sector Erase prüfen (0-7)
                bcc  _chk_er_all
                subb #$30                         ; ASCII Ziffer in Wert umwandeln
                jsrr(_erase_sector)               ; Sektor löschen
                bra  _er_result
_chk_er_all
                orab #$20
                cmpb #'a'                         ; Bei 'A'
                bne  _loop
                jsrr(_erase_flash)                ; ganzen Chip löschen
_er_result
                tab
                bsr  _print_hex                   ; Nummer ausgeben
                bra  _loop
;
;************************************************
;
_program
                ldxr(_bank_str)
                jsrr(_print)
                jsrr(_sci_rdne)
                subb #'0'
                beq  _sel_bank0
                decb
                bne  _loop
_sel_bank1
                oim  #%00000100,Port6_Data            ; A16 = 1 (Bank 1)
                bra  _prog
_sel_bank0
                aim  #%11111011,Port6_Data            ; A16 = 0 (Bank 0)
_prog
                ldxr(_ok_send_str)
                bsr  _print
                jsrr(_pgm_hex_file)
                bsr  _print_hex
                jmpr(_loop)
;
;************************************************
;
_print
                ldab 0,x
                beq  _prt_end
                jsrr(_sci_tx)
                inx
                bra  _print
_prt_end
                rts
;************************************************
;
_print_hex
                pshb
                psha
                pshx
                pshb
                ldaa #$10
                mul
                tab                               ; A/16 (*16, dann /256)
                bsr  _phx_prnt_num                ; Hi Nibble ausgeben
                pulb
                bsr  _phx_prnt_num                ; Lo Nibble ausgeben
                pulx
                pula
                pulb
                rts
_phx_prnt_num
                andb #$0f
                addb #$30
                cmpb #'9'+1
                bne  _phx_dec
                addb #7
_phx_dec
                jsrr(_sci_tx)
                rts
;
;************************************************
;
; Hex-File empfangen und im Speicher ablegen (Intel HEX Format)
;
; "ESC" ($1B) - Abbruch
;
; Intel Hex Object Format
;
; This is the default object file format.
; This format is line oriented and uses only printable ASCII characters except
; for the carriage return/line feed at the end of each line. The format is
; symbolically represented as:
; :NN AAAA RR HH CC CRLF
;
; Where:
;
; :    - Record Start Character (colon)
; NN   - Byte Count (2 hex digits)
; AAAA - Address of first byte (4 hex digits)
; RR   - Record Type (00 except for last record which is 01)
; HH   - Data Bytes (a pair of hex digits for each byte of data in the record)
; CC   - Check Sum (2 hex digits)
; CRLF - Line Terminator (CR/LF for DOS, LF for LINUX)
;
; The last line of the file will be a record conforming to the above format
; with a byte count of zero.
;
; The checksum is defined as:
;
; byte_count+address_hi+address_lo+record_type+(sum of all data bytes)+checksum = 0
;
;
_pgm_hex_file
                tsx
                xgdx
                subd #50                  ; 50 Byte temporären Speicher auf dem Stack reservieren
                xgdx
                txs

                pshx                      ; Adresse für temporären Speicher (RAM) - 5
                                          ; Größe entsprechend längster Zeile im Hexfile
                pshx                      ;
                pshx                      ;
                psha                      ; 5 Byte für lokale Variablen
                                          ; (Zieladresse, Checksumme, Offset, Bytecount)
                                          ;       4,3           2         1        0
_phf_begin
                jsrr(_phf_getchar)
                cmpa #':'                 ; Record Begin?
                bne  _phf_begin           ; Nein, dann warten
; get Bytecount
                jsrr(_phf_get_byte)       ; nächstes Byte (2 Zeichen) holen - Bytecount
                tsx
                stab 0,x                  ; Bytecount auf Stack speichern
                stab 2,x                  ; Neue Checksumme speichern
; get Address
                jsrr(_phf_get_byte)       ; nächstes Byte (2 Zeichen) holen - Adress HiByte
                tsx
                stab 3,x                  ; Adress HiByte auf Stack speichern
                addb 2,x                  ; zu Checksumme addieren
                stab 2,x                  ; Neue Checksumme speichern

                jsrr(_phf_get_byte)       ; nächstes Byte (2 Zeichen) holen - Adress LoByte
                tsx
                stab 4,x                  ; Adress LoByte auf Stack speichern
                addb 2,x                  ; zu Checksumme addieren
                stab 2,x                  ; Neue Checksumme speichern
; get Type
                jsrr(_phf_get_byte)       ; nächstes Byte (2 Zeichen) holen - Record Type
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
                jsrr(_phf_get_byte)       ; nächstes Datenbyte holen

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
                jsrr(_phf_get_byte)       ; Checksumme holen
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
                jsrr(_move)               ; Kopieren
                pulx
                pulx
                pulx                      ; Parameter vom Stack löschen

                ldab #'+'
                bra  _phf_prnt_state
_phf_check_failed
                ldab #'-'
_phf_prnt_state
                jsrr(_sci_tx)             ; Status ausgeben ('+' / '-')
                jmpr(_phf_begin)          ; Auf nächste Zeile warten
_phf_terminate
                jsrr(_phf_get_byte)       ; nächstes Datenbyte holen, muß $FF sein (CRC für $01)
                cmpb #$FF
                bne  _phf_check_failed
                ldxr(_ok_str)
                jsrr(_print)              ; "OK" ausgeben
_phf_end
                pula
                pulx
                pulx
                pulx                      ; lokale Variablen etc. vom Stack löschen

                tsx
                xgdx
                addd #50                  ; 50 Byte temporären Speicher auf dem Stack reservieren
                xgdx
                txs

                rts                       ; Rücksprung
_ok_str         .db "\n\rOK",0
;
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
                jsrr(_sci_rdne)
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
                ldxr(_phf_begin)          ; Adresse für phf_begin holen
                pshx                      ; und als neue Rücksprungadresse verwenden
                pshb
_pgc_end
                tba                       ; Char nach A
                pulb                      ; B wiederherstellen
                rts
_pgc_escape
                pulb
                pulx                      ; nochmal fiese Sache: Rücksprungadresse holen
                ldxr(_phf_end)            ; Adresse vom Routinenende holen
                pshx                      ; und als neue Rücksprungadresse festlegen
                pshb
                bra  _pgc_end
;
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

                bsr  _phf_getchar         ; nächstes Zeichen holen
                bsr  _phf_char_to_nibble  ; HiNibble holen
                tab                       ; HiNibble nach B
                bsr  _phf_getchar         ; nächstes Zeichen holen
                bsr  _phf_char_to_nibble  ; LoNibble konvertieren (or HiNibble -> Bytewert in B)

                pshx                      ; Rücksprungadresse wieder auf Stack
                rts

;************************
; S C I   R D N E
;************************
;
; Read ohne Echo
;
_sci_rdne        ;B : rxd Byte
                ;changed Regs: A, B

                jsrr(_sci_rx)
                jsrr(_watchdog_toggle)
                tsta
                beq  _sci_rdne
		rts
;
;************************************************
;
;************************
; S C I   R E A D
;************************
;
; Read mit Echo
;
_sci_read        ;B : rxd Byte
                ;changed Regs: A, B
                bsr  _sci_rx
                jsrr(_watchdog_toggle)
                tsta
                beq  _sci_read
                psha
                pshb
                bsr  _sci_tx
                pulb
                pula
		rts
;************************
; S C I   R X
;************************
_sci_rx          ;A : Status (0=no RX)
                ;B : rxd Byte
                ;changed Regs: A, B
                ldaa TRCSR1
                anda #%10010000            ;Byte empfangen?
                beq  scr_no_rx
                ldab RDR
scr_no_rx
                rts
;
;
;************************
; S C I   T X
;************************
_sci_tx          ;B : TX Byte
                ldaa TRCSR1
                anda #%100000
                jsrr(_watchdog_toggle)
                tsta
                beq  _sci_tx
                stab TDR
                rts

;
;************************************************
;
_move
                tsx
                ldd  2,x
                subd #$0200                     ; internes RAM & Register NICHT schreiben
                bcs  _mve_ret
                ldd  2,x
                subd #$2000                     ; Zieladresse im RAM oder ROM?
                bcs  _mve_ram                   ;
                jmpr(_pgm_area)                 ; zu Flash Routine verzweigen
_mve_ram
                ldd  6,x                        ; Quell-Startadresse- 4
                pshb
                psha
                ldd  4,x                        ; Quell-Endadresse  - 2
                pshb
                psha
                ldd  2,x                        ; Zieladresse       - 0
                pshb
                psha
                tsx
_mve_lp
                bsr  _watchdog_toggle            ; Watchdog bedienen

                ldx  4,x                        ; Quelladresse holen
                ldab 0,x                        ; Datenbyte lesen
                pulx                            ; Zieladresse von Stack holen
                stab 0,x                        ; Datenbyte speichern
                inx                             ; Zieladresse++
                pshx                            ; und wieder sichern

                tsx
                ldd  4,x                        ; Quelladresse holen
                addd #1                         ; Quelladresse++
                std  4,x                        ; und wieder speichern
                subd 2,x                        ; Letzte Adresse schon erreicht?

                bne  _mve_lp                    ; Nein? Dann nächstes Byte programmieren
                pulx
                pulx
                pulx
_mve_ret
                rts
;
;************************************************
;
_watchdog_toggle
                pshb
                ldab Port2_DDR_buf
                orab #%10                        ; Data auf Ausgang
                stab Port2_DDR_buf
                stab Port2_DDR
                aim  #%11111101,Port2_Data       ;Data auf 0
                nop
                nop
                nop
                ldab Port2_DDR_buf
                andb #%11111101                  ; Data auf Eingang/Hi
                stab Port2_DDR_buf
                stab Port2_DDR
                pulb
                rts

;
;************************************************
;
_pgm_area
                tsx
                ldd  6,x
                pshb
                psha                            ;
                ldd  4,x
                pshb
                psha                            ;
                ldd  2,x
                pshb
                psha                            ;
                tsx
_pab_lp
                ldx  4,x                        ; RAM Adresse holen
                ldab 0,x                        ; Datenbyte lesen
                                                ; Flashadresse ist bereits auf Stack
                bsr  _pgm_flash                 ; Byte programmieren
                pulx                            ; Flashadresse von Stack holen
                inx                             ; Flashadresse++
                pshx                            ; und wieder sichern
                tsx
                ldd  4,x                        ; RAM Adresse holen
                addd #1                         ; RAM Adresse++
                std  4,x                        ; und wieder speichern
                subd 2,x                        ; Letzte Adresse schon erreicht?

                bne  _pab_lp                    ; Nein? Dann nächstes Byte programmieren
_pab_end
                pulx
                pulx
                pulx                            ; Stack bereinigen
                rts
;
;************************************************
;
;  Flash-Program Routine, Adresse auf Stack, B=Byte, A=Bank (0/1)
;
_pgm_flash
                tsx
                ldx  2,x                         ; X vom Stack holen
                pshb                             ; zu schreibendes Byte auf Stack legen

                oim  #%00000010,Port6_Data       ; /OE (Flash) = high

                ldab #$AA                        ; Unlock cycle 1 schreiben
                stab $5555
                comb
                stab $2AAA

                ldaa #$A0                        ; Program Setup Kommando
                staa $5555                       ; schreiben
                pulb                             ; zu programmierendes Byte holen
                stab 0,x                         ; und schreiben

                aim  #%11111101,Port6_Data       ; /OE wieder freigeben

                tba
_pgf_dq7
                jsrr(_watchdog_toggle)
                eora 0,x                         ; DQ7 = Data7?
                bpl  _pgf_ok                     ; Dann war das Programmieren erfolgreich
                ldaa 0,x                         ; Status holen
                anda #%00100000                  ; DQ5=1 ? (Timeout)
                bne  _pgf_dq7                    ; Nein, dann warten bis Proggen fertig
                tba
                eora 0,x                         ; DQ7 = Data7?
                beq  _pgf_ok                     ; Wenn ja, dann war das Programmieren trotz Timeout erfolgreich

                bsr  _flash_reset
                ldaa #$FF                        ; Status = Failure
                bra  _pgf_end
_pgf_ok
                clra                             ; Status = OK
_pgf_end
                rts
;
;************************************************
;
_flash_reset
                ldab #$F0                        ; Reset Kommando muß nach Timeout gesendet werden
                oim  #%00000010,Port6_Data       ; dazu /OE (Flash) auf high
                stab 0,x                         ; Kommando schreiben (Adresse ist egal)
                aim  #%11111101,Port6_Data       ; /OE wieder freigeben
                rts
;
;************************************************
;
;  Flash-Erase Routine
_erase_flash
                ldx  #$5555                      ; Adresse für Chiperase $555(5)
                ldab #$10                        ; Chip-Erase Kommando=$10
                clra
                bra  _flash_erase
;
;************************************************
;  Sector-Erase Routine
_erase_sector
                clra
                lsrb
                rora
                lsrb
                rora                             ; A= Sektornummer (0-7) * 64
                adda #$20                        ; Offset von $2000 addieren, um immer im ROM Bereich zu bleiben
                                                 ; und nicht Speicherzellen im RAM zu überschreiben
                aim  #%11111011, Port6_Data      ; Bank 0 aktivieren (A16=0) für Sektoren 0-3
                pshb                             ; A16 sichern
                clrb
                xgdx                             ; Sektoradresse nach X
                ldab #$30                        ; Sektor-Erase Kommando=$30
                pula                             ; A16 holen
;
;************************************************
;
; gemeinsame Erase-Routine
;
_flash_erase
                pshb                             ; Sektor oder Chip-Erase ($10=Chip, $30=Sektor)
                psha                             ; A16 auf Stack

                oim  #%10,Port6_Data             ; /OE für Flash auf "hi" zwingen,
                                                 ; auch wenn Adressdekoder anderer Meinung ist (im Bereich $2000-$FFFF)

                ldab #$AA                        ; Unlock Sequenz 1 schreiben
                stab $5555                       ; $AA / $555(5)
                comb
                stab $2AAA                       ; $55 / $2AA(A)

                ldaa #$80                        ; Erase Setup Kommando
                staa $5555                       ; $80 / $555(5)

                comb                             ; Unlock Sequenz 2
                stab $5555                       ; $AA / $555(5)
                comb
                stab $2AAA                       ; $55 / $2AA(A)

                pula                             ; A16 holen
                tsta                             ; gesetzt?
                beq  _fle_bank0                  ; Nein, dann Sektor in Bank 0 löschen
                oim  #%100,Port6_Data            ; Bank1 aktivieren für Sektoren 4-7
_fle_bank0
                pulb                             ; Erase Befehl holen
                stab 0,x                         ; Befehl schreiben ... Sektor/Chip löschen

                ldaa #100                        ; Sektor Erase Timeout von 50us abwarten (100x4 Takte@8MHz)
_fle_lp
                deca
                bne  _fle_lp

                aim  #%11111101,Port6_Data       ; /OE wieder freigeben
_fle_dq7
                jsrr(_watchdog_toggle)
                ldaa 0,x                         ; Status abfragen
                bmi  _fle_ok                     ; DQ7=1 ? Dann ist Löschvorgang abgeschlossen
                anda #%00100000                  ; Wenn nicht, DQ5 prüfen, DQ5=1 bedeutet Timeout
                beq  _fle_dq7                    ; Solange DQ5=0, DQ7 erneut prüfen (noch kein Timeout)
                ldaa 0,x                         ; Status erneut lesen
                bmi  _fle_ok                     ; DQ7=1 ? Dann zwar Timeout, aber Löschvorgang war noch erfolgreich

                bsr  _flash_reset                ; Löschvorgang war nicht erfolgreich -> Flash reset
                ldaa #$77                        ; Status DQ7 Failed

                bra  _fle_end                    ; Routine beenden
_fle_ok
                clra                             ; Löschvorgang war erfolgreich
_fle_end
                aim  #%11111011,Port6_Data       ; Bank 0 aktivieren (A16=0) für Sektoren 0-3
                rts                              ; Rücksprung
;
;***************************
;
_run_debug
                ldx  #$8800
                pshx
                ldx  #$9000
                pshx
                ldx  #$0800
                pshx
                aim  #%11111011,Port6_Data        ; A16 = 0 (Bank 0)
                jsrr(_move)
                jmp  $0800

;
;***************************
; Strings
;
_bank_str       .db "Bank? (0/1)\n\r",0
_ok_send_str    .db "Send file\n\r",0
_cmds_str       .db "\n\rReady.\n\r\n\rE - Erase\n\r"
                .db "P - Program\n\r",0
_er_choice_str  .db "0-7 - Sector (16kB)\n\r"
                .db "A   - Chip\n\r",0
isu_end
;
;*********************************
; RAM Loader für In System Update
;
isu_copy
                ldx  #isu_begin
                pshx
                ldx  #isu_end
                pshx
                ldx  #isu_begin-ISUOFS
                pshx
                jsr  _move
                jmpr(isu_begin)                   ; Stackpointer wird gleich neu gesetzt, muß nicht bereinigt werden
;
;*********************************
;
                oim  #%00000100,Port6_Data        ; A16 = 1 (Bank 1)
                rts
                aim  #%11111011,Port6_Data        ; A16 = 0 (Bank 0)
                rts

