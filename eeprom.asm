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
;**************
; E E P R O M
;**************
;
; eep_rand_read - Liest ein beliebiges Byte aus dem gewählten EEPROM
;                ( B - Datenadresse im EEPROM, A - NoSTOP Flag (MSB), Dev.&Pageadr.(3 LS Bits) |
;                  B - gelesenes Byte, A - Status (0=OK))
;
; eep_read - Liest das Byte an der aktuellen Adresse im gewählten EEPROM "current address read"
;            ( A - NoSTOP-Flag(MSB), Device&Page Adresse (3 LS Bits) |
;              B - gelesenes Byte, A - Status (0=OK))
;
; eep_seq_read - Kopiert einen Block vorgegebener Größe aus dem/den EEPROM(s) ins RAM
;                ( A - Dev.&Page Adresse (3 Bit), B - Startadr., X - Zieladr.(RAM),
;                  Stack - Bytecount (Word) |
;                  A - Status (0=OK), X - Zahl der tatsächlich gelesenen Bytes)
;
; eep_write - Schreibt ein Byte ins EEPROM
;             ( A - Dev.&Page Adresse (3 LSBs), B - Datenadresse im EEPROM, Stack - Datenbyte |
;               A - Status (0=OK) )
;
; eep_get_size - Prüft die Größe des EEPROMs ( nix | D - EEPROM Größe )
;
;
; eep_chk_crc - Bildet CRC über den Config Bereich ( nix | A - Status, X - CRC )
;
; eep_write_crc - CRC16 über Config Block bilden und schreiben ( nix | X - CRC, A - Status )
;
;
;
;
;
;
;***************************
; E E P   R A N D   R E A D
;***************************
;
; Liest ein beliebiges Byte aus dem gewählten EEPROM
;
;
; Parameter: B - Datenadresse im EEPROM (Byte Adresse)
;            A - NoSTOP-Flag(MSB), Device&Page Adresse (3 Bit, LSB)
;                Wenn das MSB gesetzt ist, wird KEINE STOP Condition
;                generiert.
;
; Ergebnis : B - gelesenes Byte
;            A - Status: 0 - OK
;                        1 - Kein ACK nach Device/Pageadresse (kein EEPROM mit der Adresse vorhanden?)
;                        2 - Kein ACK nach Byteadresse
;                        3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;
; changed Regs : A,B
;
eep_rand_read
                pshx                    ; X sichern

                inc  bus_busy       ; I2C Zugriff, kein Watchdog Reset im IRQ
                inc  tasksw_en          ; Keine Taskswitches während Schreibzugriff

                jsr  i2c_start          ; Start Condition senden
                psha                    ; Device & Pageadresse sichern
                lsla                    ; Adresse ein Bit nach links schieben
                anda #%00001110         ; Dummy-write zur Adresseingabe senden
                oraa #%10100000         ; 1/0/1/0 Pattern + 3Bit Device/Page Adr + Write Bit(0)
                pshb                    ; Byteadresse sichern
                tab
                jsr  i2c_tx             ; Device und Pageadresse senden
                jsr  i2c_tstack         ; ACK testen
                tsta
                pulb                    ; Byteadresse wiederholen
                bne  err_error1         ; Fehler aufgetreten, abbrechen
                jsr  i2c_tx             ; Byte Adresse senden
                jsr  i2c_tstack         ; ACK testen
                tsta
                bne  err_error2         ; kein ACK -> Fehler aufgetreten, abbrechen

                tsx
                ldaa 0,x                ; Device und Pageadresse wiederholen
                oraa #$80               ; MSB setzen, 'eep_read' soll keine STOP Condition senden
                jsr  eep_read           ; "Current Read" durchführen
                tsta
                bne  err_end            ; Fehler aufgetreten, Fehlercode ist schon in A

                ldaa 0,x
                anda #$80               ; War No-Stop Flag MSB in Device Adresse gesetzt?
                bne  err_no_stop        ; Dann keine STOP Condition senden
                jsr  i2c_stop           ; STOP Condition senden
err_no_stop
                clra                    ; Kein Fehler aufgetreten
                                        ; Datenbyte in B
err_end
                dec  bus_busy       ; I2C Zugriff beendet, Watchdig Reset wieder über Timer IRQ
                dec  tasksw_en          ; Keine Taskswitches während Schreibzugriff

                ins
                pulx
                rts
err_error1
                ldaa #1
                bra  err_end
err_error2
                ldaa #2
                bra  err_end

;*****************
; E E P   R E A D
;*****************
;
; Liest das Byte an der aktuellen Adresse im gewählten EEPROM mittels "current address read"
;
;
; Parameter: A - NoSTOP-Flag(MSB), Device&Page Adresse (3 Bit, LSB)
;                Wenn das MSB gesetzt ist, wird KEINE STOP Condition
;                generiert.

;
; Ergebnis : B - gelesenes Byte
;            A - Status: 0 - OK
;                        3 - Kein ACK nach Device/Pageadresse
;                        5 - Power Failure
;
eep_read
               ldab Port5_Data
               andb #2                  ; check power fail input
               bne  epr_err5            ; don't start read access if power is failing NOW

                pshx
                inc  bus_busy       ; I2C Zugriff, kein Watchdog Reset
                inc  tasksw_en          ; Keine Taskswitches während Schreibzugriff
                jsr  i2c_start          ; Start Condition senden
                psha                    ; Device & Pageadresse sichern
                lsla                    ; Adresse ein Bit nach links schieben
                tab
                andb #%00001110         ; Nur Device&Page Adressbits berücksichtigen
                orab #%10100001         ; 1/0/1/0 Pattern + Adressbits + Read Bit

                jsr  i2c_tx
                jsr  i2c_tstack         ; Auf ACK warten
                tsta
                bne  epr_error          ; Fehler aufgetreten

                jsr  i2c_rx             ; Byte vom I2C Bus lesen
                tsx
                ldaa 0,x                ; Device & Pageadresse wiederholen
                anda #$80               ; No-Stop Flag testen
                bne  epr_no_stop        ; Soll keine STOP Condition gesendet werden?
                jsr  i2c_stop           ; STOP Condition senden
epr_no_stop
                ldaa #0                 ; kein Fehler
epr_end
                dec  bus_busy       ; WD Reset über IRQ wieder zulassen
                dec  tasksw_en          ; Keine Taskswitches während Schreibzugriff
                ins
                pulx
                rts
epr_error
                ldaa #3                 ; Fehler aufgetreten
                bra  epr_end
epr_err5
                ldaa #5                 ; Fehler aufgetreten
                rts
;******************************
; E E P   S E Q   R E A D
;******************************
;
; Transferiert einen Block vorgegebener Größe aus dem/den EEPROM(s) ins RAM,
; dabei wird innerhalb einer Page mittels "sequential read" gelesen, was einen
; Geschwindigkeitsvorteil gegenüber Random Read bringt, da Device- ,Page- und Startadresse
; nur einmal pro Page transferiert werden müssen.
;
; EEP SEQ READ funktioniert deviceübergreifend: Mehrere EEPROMs werden als ein Speicherblock
; betrachtet, solange ihre Deviceadressen entsprechend gesetzt sind.
;
;
; Parameter: A - Device&Page Adresse (3 Bit)
;            B - Startadresse
;            X - Bytecount
;            STACK - Zieladresse (im RAM)
;
; Ergebnis : A - Status: 0 - OK
;                        1 - Kein ACK nach Device/Pageadresse
;                           (kein EEPROM mit der Adresse vorhanden?)
;                        2 - Kein ACK nach Byteadresse
;                        3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;            X - Zahl der tatsächlich gelesenen Bytes
;
;
eep_seq_read
                pshx                    ; Bytecount sichern
                pshb                    ; Startadresse sichern
                psha                    ; Device & Pageadresse sichern
                ldx  #0                 ; Bytecounter auf 0 initialisieren
                pshx                    ; und speichern

               ldaa Port5_Data
               anda #2                  ; check power fail input
               bne  esr_err5            ; don't start read access if power is failing NOW

                inc  bus_busy
                inc  tasksw_en          ; Keine Taskswitches während Schreibzugriff
esr_page_read
                tsx
                ldaa 2,x                ; Device & Pageadresse und
                oraa #$80               ; Keine STOP Condition von eep_rand_read senden lassen
                ldab 3,x                ; Byteadresse wiederholen
                jsr  eep_rand_read      ; SEQ Read mit Random Read an Startadresse beginnen
                tsta                    ; Fehler aufgetreten?
                bne  esr_end            ; dann hier abbrechen
                tsx
                ldx  8,x                ; Zieladresse wiederholen
                stab 0,x                ; Byte speichern
                inx                     ; Zieladresse++
                xgdx                    ; Zialadresse nach D
                tsx
                std  8,x                ; Zieladresse wieder speichern
                pulx
                inx                     ; kopierte_Bytes++
                pshx
                tsx
                ldx  4,x                ; Bytecount holen
                dex                     ; Bytecount--
                beq  esr_read_ok        ; letztes Byte kopiert? Dann zum Ende springen
                xgdx
                tsx
                std  4,x                ; Bytecount sichern
                inc  3,x                ; Byteadresse++
                beq  esr_new_page       ; Page Ende erreicht? Dann neue Device&Pageadresse berechnen

esr_sr_loop                             ; hier beginnt der eigentliche Sequential Read
                jsr  i2c_ack            ; ACK senden
                jsr  i2c_rx             ; Byte vom I2C Bus lesen
                tsx
                ldx  8,x                ; Zieladresse wiederholen
                stab 0,x                ; Byte speichern
                inx                     ; Zieladresse++
                xgdx                    ;
                tsx
                std  8,x                ; Zieladresse wieder speichern
                pulx
                inx                     ; kopierte_Bytes++
                pshx
                tsx
                ldx  4,x                ; Bytecount holen
                dex                     ; Bytecount--
                beq  esr_read_ok        ; letztes Byte kopiert? Dann zum Ende springen
                xgdx
                tsx
                std  4,x                ; Bytecount sichern
                inc  3,x                ; Byteadresse++
                bne  esr_sr_loop        ; Page Ende noch nicht erreicht? Dann weitermachen
esr_new_page
                jsr  i2c_stop           ; STOP Condition senden
                inc  2,x                ; Device & Pageadresse erhöhen
                bra  esr_page_read
esr_read_ok
                clra                    ; keine Fehler aufgetreten
                jsr  i2c_stop           ; STOP Condition senden
esr_end
                pulx                    ; Zahl der gelesenen Bytes holen
                ins
                ins
                ins
                ins                     ; Stack bereinigen
                dec  bus_busy       ; WD Reset über IRQ wieder zulassen
                dec  tasksw_en          ; Keine Taskswitches während Schreibzugriff
                rts
esr_err5
                ldaa #5
                bra  esr_end
;*****************************
; E E P   W R I T E
;*****************************
;
; Parameter: B - zu schreibendes Byte
;
;            STACK (1 / 6) - Datenadresse im EEPROM (Byte Adresse)
;            STACK (0 / 5) - Device&Page Adresse (3 Bit, LSB)
;
; Ergebnis : A - Status: 0 - OK
;                        1 - Kein ACK nach Device/Pageadresse
;                           (kein EEPROM mit der Adresse vorhanden?)
;                        2 - Kein ACK nach Byteadresse
;                        3 - Kein ACK nach Datenbyte
;                        4 - Timeout beim ACK Polling nach Schreibvorgang
;                        5 - Power Fail
;
eep_write
               ldaa Port5_Data
               anda #2                  ; check power fail input
               bne  epw_err5            ; don't start write access if power is failing NOW
                inc  bus_busy           ; I2C Zugriff, kein Watchdog Reset
                inc  tasksw_en          ; Keine Taskswitches während Schreibzugriff
                pshb
                pshx
                tsx
                jsr  i2c_start          ; Start Condition senden
;                pshb                    ; Byteadresse sichern
                ldaa 5,x
                lsla                    ; Adresse ein Bit nach links schieben
                anda #%10101110         ;
                oraa #%10100000         ; 1/0/1/0 Pattern + 3Bit Device/Page Adr + Write Bit(0)
                psha                    ; Device & Pageadresse sichern
                tab
                jsr  i2c_tx             ; Device- & Pageadress etc. senden
                jsr  i2c_tstack         ; Auf ACK warten
                tsta
                bne  epw_err1           ; Fehler aufgetreten
                tsx
                ldab 7,x                ; Byteadresse wiederholen
                jsr  i2c_tx             ; Byte Adresse senden
                jsr  i2c_tstack         ; ACK testen
                tsta
                bne  epw_err2           ; Fehler aufgetreten
                ldab 3,x                ; zu schreibendes Byte holen
                jsr  i2c_tx             ; Byte senden
                jsr  i2c_tstack         ; Auf ACK prüfen
                tsta
                bne  epw_err3           ; Kein ACK, Fehler aufgetreten

                jsr  i2c_stop           ; Kein Fehler -> STOP Condition senden

                ldab #11
                stab ui_timer           ; maximal 11ms warten
                tsx
epw_ack_poll
                jsr  i2c_start
                ldab 0,x                ; Deviceadresse wiederholen
                jsr  i2c_tx             ; Mit Deviceadresse etc. pollen und auf ACK warten
                jsr  i2c_tstack
                tsta
                beq  epw_end            ; ACK empfangen, Byte erfolgreich geschrieben
                ldaa ui_timer
                bne  epw_ack_poll       ; maximal 11ms warten
                ldaa #4                 ; Timeout
epw_end
                jsr  i2c_stop           ; Stop Condition senden
                ins                     ; Deviceadresse löschen
                pulx                    ; X zurückholen
                pulb
                dec  tasksw_en          ; Taskswitches wieder erlauben
                dec  bus_busy       ; WD Reset über IRQ wieder zulassen
epw_exit
                rts
epw_err1
                ldaa #1
                bra  epw_end
epw_err2
                ldaa #2
                bra  epw_end
epw_err3
                ldaa #3
                bra  epw_end
epw_err5
                ldaa #5
                rts

;***************************
; E E P   W R I T E   S E Q
;***************************
;
; Mehrere Bytes hintereinander schreiben (maximal 256)
;
; Parameter: STACK(4)(9) - Datenadresse im Speicher
;            STACK(3)(8) - Datenadresse im EEPROM (Byte Adresse)
;            STACK(2)(7) - Device&Page Adresse (3 Bit, LSB)
;            STACK(0)(5) - Bytecount
;
; Ergebnis : A - Status: 0 - OK
;                        1 - Kein ACK nach Device/Pageadresse
;                           (kein EEPROM mit der Adresse vorhanden?)
;                        2 - Kein ACK nach Byteadresse
;                        3 - Kein ACK nach Datenbyte
;                        4 - Timeout beim ACK Polling nach Schreibvorgang
;                        5 - Power Failure
;
eep_write_seq
                inc  bus_busy       ; I2C Zugriff, kein Watchdog Reset
                inc  tasksw_en          ; Keine Taskswitches während Schreibzugriff
                pshb
                pshx
                tsx
                ldd  5,x               ; Bytecount holen
ews_loop
                std  5,x               ; Bytecount speichern
                ldx  9,x               ; Adresse im RAM holen
                ldab 0,x               ; Datenbyte holen
                tsx
                ldx  7,x               ; EEPROM Adresse holen
                pshx                   ; und auf Stack
                jsr  eep_write         ; Byte schreiben
                pulx
                tsta                   ; Fehler aufgetreten?
                bne  ews_end           ; Ja, dann beenden
                tsx
                ldd  9,x               ; Leseadresse (RAM) holen
                addd #1                ; erhöhen
                std  9,x               ; und speichern
                ldd  7,x               ; Schreibadresse holen
                addd #1                ; erhöhen
                std  7,x               ; und speichern
                ldd  5,x               ; Bytecount holen
                subd #1                ; Bytecount --
                bne  ews_loop          ; Solange nicht auf 0, weiterschreiben
                clra
ews_end
                pulx                   ; X wiederherstellen
                pulb                   ; B wiederherstellen
                dec  bus_busy       ; I2C Zugriff, Watchdog Reset wieder zulassen
                dec  tasksw_en          ; Keine Taskswitches während Schreibzugriff
                rts

;*************************
; E E P   G E T   S I Z E
;*************************
;
; Parameter: keine
;
; Ergebnis : D - EEPROM Größe in Bytes
;
;
eep_get_size
                clrb
                clra
egs_page_loop
                pshb
                psha
                jsr  eep_rand_read  ; pageweise EEPROM Random Read versuchen
                tsta                ; Auf ACK testen
                pula
                pulb
                bne  egs_r_error    ; Kein ACK, dann Ende
                addd #$0080
                cmpa #$08
                bcs  egs_page_loop
egs_r_error
                rts


;******************************
; E E P   S E Q   V E R I F Y
;******************************
;
; Vergleicht den Inhalt in EEPROM(s) und RAM ab den gegebenen Adressen
;
;
; Parameter: A - Device&Page Adresse (3 Bit)
;            B - Startadresse
;            X - Bytecount
;            STACK - Datenadresse (im RAM)
;
; Ergebnis : A - Status: 0 - OK
;                        1 - Kein ACK nach Device/Pageadresse
;                           (kein EEPROM mit der Adresse vorhanden?)
;                        2 - Kein ACK nach Byteadresse
;                        3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;            X - Zahl der geprüften Bytes
;
;
eep_seq_verify
                pshx                    ; Bytecount sichern
                pshb                    ; Startadresse sichern
                psha                    ; Device & Pageadresse sichern

                ldx  #0                 ; Bytecounter auf 0 initialisieren
                pshx                    ; und speichern
                inc  bus_busy
                inc  tasksw_en          ; Keine Taskswitches während Schreibzugriff
esv_page_read
                tsx
                ldaa 2,x                ; Device & Pageadresse und
                oraa #$80               ; Keine STOP Condition von eep_rand_read senden lassen
                ldab 3,x                ; Byteadresse wiederholen
                jsr  eep_rand_read      ; SEQ Read mit Random Read an Startadresse beginnen
                tsta                    ; Fehler aufgetreten?
                bne  esv_end            ; dann hier abbrechen
                tsx
                ldx  8,x                ; Zieladresse holen
                cmpb 0,x                ; Byte prüfen
                bne  esv_error          ; Abbrechen bei Fehler
                inx                     ; Zieladresse++
                xgdx                    ; Zialadresse nach D
                tsx
                std  8,x                ; Zieladresse wieder speichern
                pulx
                inx                     ; geprüfte_Bytes++
                pshx
                tsx
                ldx  4,x                ; Bytecount holen
                dex                     ; Bytecount--
                beq  esv_read_ok        ; letztes Byte kopiert? Dann zum Ende springen
                xgdx
                tsx
                std  4,x                ; Bytecount sichern
                inc  3,x                ; Byteadresse++
                beq  esv_new_page       ; Page Ende erreicht? Dann neue Device&Pageadresse berechnen

esv_sr_loop                             ; hier beginnt der eigentliche Sequential Read
                jsr  i2c_ack            ; ACK senden
                jsr  i2c_rx             ; Byte vom I2C Bus lesen
                tsx
                ldx  8,x                ; Zieladresse holen
                cmpb 0,x                ; Byte prüfen
                bne  esv_error          ; Abbrechen bei Fehler
                inx                     ; Zieladresse++
                xgdx                    ;
                tsx
                std  8,x                ; Zieladresse wieder speichern
                pulx
                inx                     ; geprüfte_Bytes++
                pshx
                tsx
                ldx  4,x                ; Bytecount holen
                dex                     ; Bytecount--
                beq  esv_read_ok        ; letztes Byte geprüft? Dann zum Ende springen
                xgdx
                tsx
                std  4,x                ; Bytecount sichern
                inc  3,x                ; Byteadresse++
                bne  esv_sr_loop        ; Page Ende noch nicht erreicht? Dann weitermachen
esv_new_page
                jsr  i2c_stop           ; STOP Condition senden
                inc  2,x                ; Device & Pageadresse erhöhen
                bra  esv_page_read
esv_read_ok
                clra                    ; keine Fehler aufgetreten
                jsr  i2c_stop           ; STOP Condition senden
esv_end
                pulx                    ; Zahl der gelesenen Bytes holen
                ins
                ins
                ins
                ins                     ; Stack bereinigen
                dec  bus_busy           ; WD Reset wieder zulassen
                dec  tasksw_en          ; Taskswitches wieder zulassen
                rts
esv_error
                ldaa #4                 ; Verify Error
                jsr  i2c_stop           ; STOP Condition senden
                bra  esv_end
