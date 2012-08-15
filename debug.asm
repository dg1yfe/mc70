;****************************************************************************
;
;    MC70 - Firmware for the Motorola MC micro trunking radio
;           to use it as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2012  Felix Erckenbrecht, DG1YFE
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
; DEBUG Modul
;**********************************************************
; erstellt: 31.10.2005
; letzte Änderung: 14.01.2007
;
; Monitorprogramm mit folgenden Funktionen:
;
; - TODO:
; - Flash Programmierung direkt mittels HEX Files
; - relozierbarer Code, in beliebigen Speicherbereich (auch RAM) ausführbar
;   Momentan nur ab $0800 ausführbar
; - DONE:
; - serielle Kommunikation mit Host (1200,n,8,1)
; - Stackbereich ab $0FFF (4kB Bereich $1000-$1FFF frei verfügbar)
; - IRQs verboten
; - Dump von Blöcken zu max. 256 Bytes ab beliebiger Speicheradresse
; - Schreiben von Datenblöcken zu max. 256 Bytes an beliebige Speicheradresse (sinnvoll nur im RAM Bereich)
; - Ausführen von Code an beliebiger Speicherstelle
; - Programmieren von einzelnen Bytes im Flash
; - Programmieren von Datenblöcken ins Flash
; - Verifizieren von (kopierten/programmierten) Speicherinhalten
; - Löschen von Sektoren im Flash
; - Löschen des kompletten Flash
; - Empfang von Daten im Intel HEX Format (derzeit nur RAM)
;
#DEFINE DBGOFS $8000
debug_module    .MODULE debug
_cpy_begin      .ORG DBGOFS+$800
                sei
                lds  #$0fff                      ; Stack auf $0fff setzen, Bereich $1000-$2000 frei
                                                 ; Rückkehr aus Debug Modul nur über Reset

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

                ldx  #14                         ; 14x $FF senden
                ldab #$FF
_lp2
                jsr  _sci_tx-DBGOFS
                dex
                bne  _lp2

                aim  #%11111011,Port6_Data       ; Page 0 anwählen
                ldab Port6_DDR_buf               ; /OE override (P61) und A16 (P62)
                orab #%00000110                  ; auf
                stab Port6_DDR_buf               ; Ausgang
                stab Port6_DDR                   ; schalten
                aim  #%11111001,Port6_Data       ; /OE freigeben, Page 0 anwählen

                ldd  #_cpy_end
                pshb
                tab
                bsr  _sci_tx
                pulb
                bsr  _sci_tx                     ; Letzte von der Routine genutzte Adresse senden
_main_loop
                ldab #$0c                        ; CR
                bsr  _sci_tx
                ldab #$0a                        ; LF
                bsr  _sci_tx
                ldab #'>'                        ; > (Prompt)
                bsr  _sci_tx
                bsr  _sci_read
                cmpb #'c'                        ; COPY - $10 AH AL Bytecount Data...
                beq  _cpy_bridge
                cmpb #'m'                        ; MOVE - $20 ROM/RAM AH AL, ROM/RAM AH AL, RAM AH AL
                beq  _move_bridge                ;            Quell/Start    Quell/Stop     Ziel/Start
                cmpb #'d'                        ; DUMP - $30 AH AL Bytecount
                beq  _dump_bridge
                cmpb #'r'                        ; RUN - $40, AH AL, XH, XL, A, B - returns B,A,XH,XL
                beq  _run_bridge
                cmpb #'b'                        ; Byte-Program - $50 AH AL Databyte
                beq  _pgm_flash_bridge
                cmpb #'p'                        ; Area-Program - $60 RAM AH AL, RAM AH AL, Flash AH AL
                beq  _pgm_area_bridge            ;                    Start      Stop       Start
                cmpb #'v'                        ; Verify - $70  AH AL, AH AL, AH AL
                beq  _verify_bridge              ;               Start  Stop   Start
                cmpb #'k'                        ; Chip-Erase - $80
                beq  _er_flash_bridge
                cmpb #'e'                        ; Sector-Erase - $90 SA
                beq  _er_sector_bridge
                cmpb #'h'                        ; Program Hex File
                beq  _pgm_hex_bridge
                bra  _main_loop
;
;************************************************
;
;************************
; S C I   R E A D
;************************
_sci_read        ;B : rxd Byte
                ;changed Regs: A, B
;                bsr  sci_rx
;                tsta

                bsr  _sci_rx
                jsr  _watchdog_toggle-DBGOFS
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
;                ldaa TRCSR1
                ldaa TRCSR1
                anda #%10010000            ;Byte empfangen?
;                anda #%10000000            ;Byte empfangen?
;                tsta
                beq  _scr_no_rx
                ldab RDR
_scr_no_rx
                rts

;
;
;************************
; S C I   T X
;************************
_sci_tx         ;B : TX Byte

                stab TDR
_st_wait_tdr_empty
                ldaa TRCSR1
                anda #%100000
;                jsr  _watchdog_toggle-DBGOFS
                tsta
                beq  _st_wait_tdr_empty
                rts

_pgm_hex_bridge
                ldx  #_pgm_hex_file-DBGOFS
                pshx
                bra  _0run
_cpy_bridge
                ldx  #_cpy-DBGOFS                ; Copy Routine aufrufen
                bra  _3run                      ; 3 Byte Parameter abfragen 1&2->Stack, 3->B, Routine in X aufrufen
_move_bridge
                ldx  #_move-DBGOFS
                bra  _6run                      ; 6 Byte Parameter abfragen & auf Stack legen, Routine in X aufrufen
_dump_bridge
                ldx  #_dump-DBGOFS               ; Speicherdump durchführen
                bra  _3run                      ; 3 Byte Parameter abfragen 1&2->Stack, 3->B, Routine in X aufrufen

_run_bridge
                bsr  _sci_read                  ; Address HiByte holen
                pshb                            ; und sichern
                bsr  _sci_read                  ; Address LoByte holen
                pula
                pshb
                psha                            ; Adresse auf Stack legen
                jsr  _run-DBGOFS
                pulx
                jmp  _main_loop-DBGOFS

_pgm_flash_bridge
                ldx  #_pgm_flash-DBGOFS
_3run
                bsr  _sci_read                  ; Adresse HiByte holen
                pshb
                bsr  _sci_read                  ; Adresse LoByte holen
                pula
                pshb
                psha                            ; Adresse auf Stack
                bsr  _sci_read                  ; Datenbyte holen
_0run
                jsr  0,x
                pulx                            ; Stack bereinigen
_main_loop_bridge
                jmp  _main_loop-DBGOFS
_er_flash_bridge
                jsr  _er_flash-DBGOFS
                bra  _main_loop_bridge

_er_sector_bridge
                bsr  _sci_read                  ; Sektor holen
                jsr  _er_sector-DBGOFS
                bra  _main_loop_bridge

_pgm_area_bridge
                ldx  #_pgm_area-DBGOFS
                bra  _6run
_verify_bridge
                ldx  #_verify-DBGOFS
_6run                                           ; Holt 6 Bytes Parameter (3 16Bit Adressen),
                                                ; verzweigt danach zur Routine @X
                bsr  _sci_read                  ; Adresse HiByte holen
                pshb
                bsr  _sci_read                  ; Adresse LoByte holen
                pula
                pshb
                psha                            ; RAM Startadresse auf Stack   - 4

                bsr  _sci_read                  ; Adresse HiByte holen
                pshb
                bsr  _sci_read                  ; Adresse LoByte holen
                pula
                pshb
                psha                            ; RAM Endadresse auf Stack     - 2

                jsr  _sci_read-DBGOFS            ; Adresse HiByte holen
                pshb
                jsr  _sci_read-DBGOFS            ; Adresse LoByte holen
                pula
                pshb
                psha                            ; Flash Startadresse auf Stack - 0

                jsr  0,x

                pulx
                pulx
                pulx                            ; Stack bereinigen
                bra  _main_loop_bridge


;
;************************************************
;
_cpy
                tsx
                ldx  2,x                        ; Zieladresse holen
_cpy_lp
                pshb                            ; Bytecount sichern
                jsr  _sci_read-DBGOFS            ; Datenbyte holen
                stab 0,x                        ; und speichern
                inx                             ; Adresse++
                pulb                            ; Bytecount holen
                decb                            ; Bytecount--
                bne  _cpy_lp                    ; Loop bis 0 erreicht ist
                rts                             ; Rücksprung
;
;************************************************
;
_move
                tsx
                ldd  2,x
                subd #$2000
                bcs  _mve_ram                   ; Zieladresse = Flash?
;                jmp  _pgm_area                  ; zu Flash Routine verzweigen
_mve_ram
                ldd  6,x                        ; Quell-Zieladresse - 4
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
                bsr  _watchdog_toggle           ; Watchdog bedienen

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

;                ldab 4,x
;                jsr  _sci_tx-DBGOFS
;                bsr  _sci_tx
;                ldab 3,x
;                jsr  _sci_tx-DBGOFS
;                bsr  _sci_tx
                pulx
                pulx
                pulx
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
_dump
                tsx
                ldx  2,x                        ; Adresse holen (Parameter auf Stack)
                pshb
_dump_lp
                ldab 0,x                        ; Byte lesen
                inx                             ; Adresse++
                jsr  _sci_tx-DBGOFS              ; Byte senden
                pulb                            ; Bytecount holen
                decb                            ; Bytecount--
                pshb                            ; Bytecount sichern
                bne  _dump_lp                   ; Loop, bis Bytecount = 0
                ins                             ; Stack bereinigen
                rts                             ; Rücksprung


;
;************************************************
;
_run
                tsx
                ldx  2,x
                bsr  _watchdog_toggle          ; Watchdog bedienen
                jsr  0,x
                pshb
                tab
                jsr  _sci_tx-DBGOFS   ; A
                pulb
                jsr  _sci_tx-DBGOFS   ; B
                pshx
                pulb
                jsr  _sci_tx-DBGOFS   ; XH
                pulb
                jsr  _sci_tx-DBGOFS   ; XL
                rts

;
;************************************************
;
;  Flash-Program Routine, Adresse auf Stack, B=Byte
_pgm_flash
                tsx
                ldx  2,x                         ; X vom Stack holen
                pshb                             ; zu schreibendes Byte auf Stack legen

                oim  #%10,Port6_Data             ; /OE (Flash) = high

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
                bsr  _watchdog_toggle
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
_pgm_area
                tsx
                ldd  6,x
                pshb
                psha
                ldd  4,x
                pshb
                psha
                ldd  2,x
                pshb
                psha
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

                pulx
                pulx
                pulx                            ; Stack bereinigen
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
;Verify
_verify
                tsx
                ldd  6,x                        ; Startadresse 1 - 4
                pshb
                psha
                ldd  4,x                        ; Endadresse1    - 2
                pshb
                psha
                ldd  2,x                        ; Startadresse2  - 0
                pshb
                psha
                tsx
_ver_lp
                jsr  _watchdog_toggle-DBGOFS    ; Watchdog bedienen

                ldx  4,x                        ; Adresse1 holen
                ldab 0,x                        ; Datenbyte lesen
                pulx                            ; Adresse2 von Stack holen
                cmpb 0,x                        ; Datenbyte vergleichen
                tpa                             ; Status sichern
                inx                             ; Adresse2 ++
                pshx                            ; und wieder sichern
                tap                             ; Status wiederholen
                tsx
                bne  _ver_failure               ; Bei Fehler abbrechen

                ldd  4,x                        ; Adresse1 holen
                addd #1                         ; Adresse1 ++
                std  4,x                        ; und wieder speichern
                subd 2,x                        ; Letzte Adresse schon erreicht?

                bne  _ver_lp                    ; Nein? Dann nächstes Byte programmieren
_ver_failure
                ldab 4,x
                jsr  _sci_tx-DBGOFS
                ldab 5,x
                jsr  _sci_tx-DBGOFS
                pulx
                pulx
                pulx
                rts

;
;************************************************
;  Sector-Erase Routine
_er_sector
                tba
                clrb                             ; Sektor LoByte=0
                xgdx                             ; Sektoradresse nach X
                ldab #$30                        ; Sektor-Erase Kommando=$30
;
;************************************************
;
; gemeinsame Erase-Routine
;
_flash_erase
                pshb                             ; Sektor oder Chip-Erase ($10=Chip, $30=Sektor)

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

                pulb                             ; Erase Befehl holen
                stab 0,x                         ; Befehl schreiben ... Sektor/Chip löschen

                ldaa #100                        ; Sektor Erase Timeout von 50us abwarten (100x4 Takte@8MHz)
_fle_lp
                deca
                bne  _fle_lp

                aim  #%11111101,Port6_Data       ; /OE wieder freigeben

_fle_dq7
                jsr  _watchdog_toggle-DBGOFS
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
                rts                              ; Rücksprung
;
;************************************************
;
;  Flash-Erase Routine
_er_flash
                ldx  #$5555                      ; Adresse für Chiperase $555(5)
                ldab #$10                        ; Chip-Erase Kommando=$10
                bra  _flash_erase
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
;
_pgm_hex_file
                ldx  #ext_ram             ; Temp Speicher an Anfang von ext RAM ($0200)
                pshx                      ; Adresse für temporären Speicher (RAM) - 5
                                          ; Größe entsprechend längster Zeile im Hexfile
                pshx                      ;
                pshx                      ;
                psha                      ; 5 Byte für lokale Variablen
                                          ; (Zieladresse, Checksumme, Offset, Bytecount)
                                          ;       4,3           2         1        0
_phf_begin
                jsr  _phf_getchar-DBGOFS
                cmpa #':'                 ; Record Begin?
                bne  _phf_begin           ; Nein, dann warten
; get Bytecount
                jsr  _phf_get_byte-DBGOFS  ; nächstes Byte (2 Zeichen) holen - Bytecount
                tsx
                stab 0,x                  ; Bytecount auf Stack speichern
                stab 2,x                  ; Neue Checksumme speichern
; get Address
                jsr  _phf_get_byte-DBGOFS  ; nächstes Byte (2 Zeichen) holen - Adress HiByte
                tsx
                pshb
                andb #$0F
                orab #$10
                stab 3,x                  ; Adress HiByte auf Stack speichern
                pulb
                addb 2,x                  ; zu Checksumme addieren
                stab 2,x                  ; Neue Checksumme speichern

                jsr  _phf_get_byte-DBGOFS  ; nächstes Byte (2 Zeichen) holen - Adress LoByte
                tsx
                stab 4,x                  ; Adress LoByte auf Stack speichern
                addb 2,x                  ; zu Checksumme addieren
                stab 2,x                  ; Neue Checksumme speichern
; get Type
                jsr  _phf_get_byte-DBGOFS  ; nächstes Byte (2 Zeichen) holen - Record Type
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
                jsr  _phf_get_byte-DBGOFS  ; nächstes Datenbyte holen

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
                jsr  _phf_get_byte-DBGOFS  ; Checksumme holen
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
                jsr  _move-DBGOFS          ; Kopieren
                pulx
                pulx
                pulx                      ; Parameter vom Stack löschen

                ldab #'+'
                jsr  _sci_tx-DBGOFS        ; "OK" ausgeben
                jmp  _phf_begin-DBGOFS     ; Auf nächste Zeile warten
_phf_check_failed
                ldab #'-'
                jsr  _sci_tx-DBGOFS
                jmp  _phf_begin-DBGOFS     ; Auf nächste Zeile warten
_phf_terminate
                jsr  _phf_get_byte-DBGOFS  ; nächstes Datenbyte holen, muß $FF sein (CRC für $01)
                cmpb #$FF
                bne  _phf_check_failed
                ldab #$0c
                jsr  _sci_tx-DBGOFS
                ldab #$0a
                jsr  _sci_tx-DBGOFS
                ldab #'O'
                jsr  _sci_tx-DBGOFS
                ldab #'K'
                jsr  _sci_tx-DBGOFS        ; "OK" ausgeben
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
                jsr  _sci_rdne-DBGOFS
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
                ldx  #_phf_begin-DBGOFS    ; Adresse für phf_begin holen
                pshx                      ; und als neue Rücksprungadresse verwenden
                pshb
_pgc_end
                tba                       ; Char nach A
                pulb                      ; B wiederherstellen
                rts
_pgc_escape
                pulb
                pulx                      ; nochmal fiese Sache: Rücksprungadresse holen
                ldx  #_phf_end-DBGOFS      ; Adresse vom Routinenende holen
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

                jsr  _phf_getchar-DBGOFS   ; nächstes Zeichen holen
                jsr  _phf_char_to_nibble-DBGOFS; HiNibble holen
                tab                       ; HiNibble nach B
                jsr  _phf_getchar-DBGOFS   ; nächstes Zeichen holen
                jsr  _phf_char_to_nibble-DBGOFS; LoNibble konvertieren (or HiNibble -> Bytewert in B)

                pshx                      ; Rücksprungadresse wieder auf Stack
                rts

;************************
; S C I   R E A D
;************************
_sci_rdne        ;B : rxd Byte
                ;changed Regs: A, B

                jsr  _sci_rx-DBGOFS
                jsr  _watchdog_toggle-DBGOFS
                tsta
                beq  _sci_rdne
		rts


_cpy_end
;
;
;
debug_loader
                ldx  #_cpy_begin
                pshx
                ldx  #_cpy_end
                pshx
                ldx  #_cpy_begin-DBGOFS
                pshx
                jsr  _move
                                                     ; Stackpointer wird gleich neu gesetzt, muß nicht bereinigt werden
                jmp  $_cpy_begin-DBGOFS


