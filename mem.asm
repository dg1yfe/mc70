;****************************************************************************
;
;    MC 70    v1.0.1 - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2007  Felix Erckenbrecht, DG1YFE
;
;    This program is free software; you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation; either version 2 of the License, or
;    any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program; if not, write to the Free Software
;    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;
;
;****************************************************************************
;************************************************
; M E M O R Y
;************************************************
;
; Memory related Subroutines
;
; mem_init - Testet und Initialisiert RAM & EEPROM ( nix | A - Status (0=OK))
; mem_chk - Überprüft das externe RAM ( nix | A - Status (0=OK))
; mem_fill - Füllt einen Speicherbereich von maximal 256 Bytes mit dem angegebenen Wert
;            ( B - Füllwert, A - Bytecount, X - Startadresse | nix )
; mem_trans - Kopiert Daten im RAM ( D - Zieladresse, X - Quelladresse, Stack - Bytecount | nix )
;
;
;
;
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; MCPOCSAG
;*************************
; M E M   I N I T
;*************************
;
; Testet & Initialisiert RAM / EEPROM
;
; Parameter : Keine
;
; Ergebnis : A - Status:   0 = OK
;
;                        $11 = RAM Error
;
;                        $20 = Kein EEPROM Speicher an Adresse 0 vorhanden (I2C Deviceadresse prüfen! )
;
;                        $3x = Fehler beim Lesen des Config Bereichs
;                          1 - Kein ACK nach Device/Pageadresse
;                              (kein EEPROM mit der Adresse vorhanden?)
;                          2 - Kein ACK nach Byteadresse
;                          3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;                        $41 = CRC Fehler im Config Bereich
;
;                        $5x = Lesefehler beim Kopieren
;                          1 - Kein ACK nach Device/Pageadresse
;                              (kein EEPROM mit der Adresse vorhanden?)
;                          2 - Kein ACK nach Byteadresse
;                          3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;                        $60 = Nicht genug Speicher für EP_CH_SLOTS
;                              verfügbare Anzahl von Slots steht in ep_slots
;
;                        $8x = Fehler beim Kopieren der Kanäle ins RAM
;                          1 - Kein ACK nach Device/Pageadresse
;                              (kein EEPROM mit der Adresse vorhanden?)
;                          2 - Kein ACK nach Byteadresse
;                          3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;                        $Ex = Nicht genug Speicher für EP_CH_SLOTS
;                              UND Fehler beim Kopieren der Kanäle ins RAM
;                          1 - Kein ACK nach Device/Pageadresse
;                              (kein EEPROM mit der Adresse vorhanden?)
;                          2 - Kein ACK nach Byteadresse
;                          3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;
;
; changed Regs : A,X
;
; changed Mem  : eep_mirror... , ep_slots
;
;
;*************************
; M E M   I N I T *BROKEN*
;*************************
;
; Testet & Initialisiert RAM / EEPROM
;
; Parameter : Keine
;
; Ergebnis : A - Status:   0 = OK
;
;                        $11 = RAM Error
;
;                        $20 = Kein EEPROM Speicher an Adresse 0 vorhanden (I2C Deviceadresse prüfen! )
;
;                        $3x = Fehler beim Lesen des Config Bereichs
;                          1 - Kein ACK nach Device/Pageadresse
;                              (kein EEPROM mit der Adresse vorhanden?)
;                          2 - Kein ACK nach Byteadresse
;                          3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;                        $41 = CRC Fehler im Config Bereich
;
;                        $5x = Lesefehler beim Kopieren
;                          1 - Kein ACK nach Device/Pageadresse
;                              (kein EEPROM mit der Adresse vorhanden?)
;                          2 - Kein ACK nach Byteadresse
;                          3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;                        $60 = Nicht genug Speicher für EP_CH_SLOTS
;                              verfügbare Anzahl von Slots steht in ep_slots
;
;                        $8x = Fehler beim Kopieren der Kanäle ins RAM
;                          1 - Kein ACK nach Device/Pageadresse
;                              (kein EEPROM mit der Adresse vorhanden?)
;                          2 - Kein ACK nach Byteadresse
;                          3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;                        $Ex = Nicht genug Speicher für EP_CH_SLOTS
;                              UND Fehler beim Kopieren der Kanäle ins RAM
;                          1 - Kein ACK nach Device/Pageadresse
;                              (kein EEPROM mit der Adresse vorhanden?)
;                          2 - Kein ACK nach Byteadresse
;                          3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;
;
; changed Regs : A,X
;
; changed Mem  : eep_mirror... , ep_slots
;
;
mem_init
                pshb

                jsr  mem_chk               ; RAM überprüfen

                tsta
                bne  mei_ram_err

                jsr  eep_get_size          ; EEPROM Größe feststellen
                std  eep_size              ; und speichern

                beq  mei_no_ep_err         ; kein EEPROM vorhanden?

                jsr  eep_chk_crc           ; CRC des Config-Bereichs prüfen
                cmpa #8                    ; Lesefehler aufgetreten? (Fehler Code >=8)

                bcc  mei_cfg_rd_err

                tsta                       ; CRC OK (=0)

                bne  mei_cfg_crc_err       ; Nein? CRC Error aufgetreten

                                           ; CRC is ok, also gültige Config vorhanden
                clra                       ; Config für schnelleren Zugriff ins RAM kopieren
;                ldab #EP_CONF_MEM          ; 52 Byte Config Daten
                pshb
                psha                       ; Bytecount auf Stack
                clrb                       ; EEPROM Startadresse 0
;                ldx  #eep_mirror           ; speichern bei "eep_mirror"
;                jsr  eep_seq_read
                pulx                       ; Bytecount vom Stack löschen
                tsta                       ; Fehler beim Lesen aufgetreten?
                bne  mei_cpy_err           ; Dann hier abbrechen
                clra
                ldd  eep_size              ; EEPROM Größe holen
;                subd #EP_CONF_MEM          ; Speicher für Config abziehen
                pshb
                psha                       ;
;                subd #EP_CH_SLOTS<1        ; genug Platz für Kanalspeicher? (2Byte pro Slot)
                pulx
                bcs  mei_ins_mem_err
                clra                       ; Ja? Dann Kanäle kopieren
;                ldx  #EP_CH_SLOTS<1        ; (2Byte pro Slot)
mei_cpy_ch
                psha                       ; Status sichern
                xgdx
                lsrd                       ; Bytes in Slots umrechnen
;                std  ep_slots              ; Anzahl verfügbarere Slots speichern
                lsld                       ; wieder in Bytes umrechnen
                pshb
                psha                       ; Bytecount auf Stack (Anzahl Kanäle)
;                ldd  #EP_CONF_MEM          ; Nach Config Bereich liegen die Kanäle
                ldx  #ep_m_base            ; Basisadresse für Kanalspeicher holen
;                jsr  eep_seq_read          ; Kanäle von EEPROM ins RAM kopieren
                ins
                ins                        ; Bytecount vom Stack löschen
                tab                        ; Status vom EEPROM Read nach b
                pula                       ; Status wiederholen
                orab                       ; EEPROM Status hinzufügen
                tstb                       ; Fehler beim Lesen aus dem EEPROM aufgetreten?
                bne  mei_ch_cpy_err
mei_end
                pshx                       ; X sichern
                tsx
                oraa 2,x                   ; Fehlercode berechnen
                pulx                       ; X wiederherstellen

                pulb                       ; B wiederherstellen


                rts
mei_ram_err

                oraa #$10
                bra  mei_end
mei_no_ep_err
                oraa #$20
                bra  mei_end
mei_cfg_rd_err
                oraa #$30
                bra  mei_end
mei_cfg_crc_err
                oraa #$40
                bra  mei_end
mei_cpy_err
                oraa #$50
                bra  mei_end
mei_ins_mem_err
                oraa #$60        ; zu Platz im EEPROM
                xgdx             ; dennoch verfügbare Kanäle auslesen
                lsrd             ;
                lsld             ; Auf ganzen 2 Byte Wert abrunden
                xgdx
                bra  mei_cpy_ch
mei_ch_cpy_err
                oraa #$80
                bra  mei_end

;****************
; M E M   C H K
;****************
;
; Überprüft das externe RAM
;
; Parameter : Keine
;
; Ergebnis : A - Status: 0 = OK
;                        1 = Fehler
;
mem_chk
                pshb
                pshx
                ldx  crc_init
                pshx                       ; CRC initialisieren
                ldx  #ext_ram              ; am Beginn des externen RAM beginnen
                ldab #3                    ; Inhalt von A nur bei jeder 3. Adresse erhöhen
                clra
mck_fill_loop
                staa 0,x                   ; Wert ins RAM schreiben
                pshx                       ; RAM Adresse sichern
                pshb                       ; Hilfscounter sichern
                psha                       ; Datenwert sichern
                tsx
                ldd  4,x                   ; CRC holen
                xgdx                       ; Datenadresse nach D, CRC nach X
                pshx                       ; CRC Wert auf Stack
                xgdx                       ; Adresse zurück nach X
                ldd  #1                    ; 1 Byte dazurechnen
                jsr  crc16                 ; CRC berechnen
                pulx
                tsx
                std  4,x                   ; neue CRC speichern
                pula
                pulb
                pulx                       ; Register wiederherstellen
                inca
                decb                       ; Hilfscounter--
                bne  mck_next
                inca                       ; Datenwert++
                ldab #3                    ; Hilfscounter auf 3 zurücksetzen
mck_next
                inx                        ; Adresse++
                cpx  #rom-50               ; schon am Ende vom RAM angekommen? (ca 50 Byte für Stack freihalten)
                bne  mck_fill_loop         ; Nein, dann loop
                pulx                       ; CRC holen
                stx  rom-50                ; CRC auf letzten beiden Bytes speichern

                ldx  crc_init
                pshx                       ; CRC erneut initialisieren
                ldx  #ext_ram              ; wieder am Beginn des externen RAMs starten
                ldd  #rom-ext_ram-50+2     ; und bis zum Ende des RAM berechnen lassen (abzüglich 50 Byte für Stack, +2 Byte CRC)
                jsr  crc16
                pulx
                cpx  #0                    ; CRC müsste 0 sein
                bne  mck_err               ; Wenn nicht, dann ist ein Fehler aufgetreten
                clra                       ; kein Fehler aufgetreten
mck_end
                pulx                       ; X wiederherstellen
                pulb                       ; B wiederherstellen
                rts
mck_err
                ldaa #1                    ; Fehler aufgetreten
                bra  mck_end

;************************
; M E M   F I L L
;************************
;
; Füllt einen Speicherbereich von maximal 256 Bytes mit dem angegebenen Wert
;
; Parameter    : B - Füllwert
;                A - Bytecount
;                X - Startadresse
;
; Ergebnis     : Nichts
;
; changed Regs : A,B,X
;
mem_fill
                psha
mem_fill_loop
                stab 0,x
                inx
                deca
                bne  mem_fill_loop
                pula
                rts


;************************
; M E M   T R A N S
;************************
;
; Kopiert Daten im RAM.
; Speicherbereiche dürfen sich nicht überlappen wenn Zieladresse>Quelladresse!
;
; Parameter : D            - Zieladresse
;             X            - Quelladresse
;             Stack (Word) - Bytecount
;
; Ergebnis     : Nichts
;
; changed Regs : A,B,X
;
;
mem_trans
               std  mem_tr_des
               stx  mem_tr_src
               tsx
               ldx  2,x                  ; Bytecount
               beq  mem_trans_ret        ; Wenn 0 Bytes zu kopieren sind -> Ende
mem_trans_loop
               pshx                      ; Bytecount speichern

               ldx  mem_tr_src
               ldab 0,x
               inx
               stx  mem_tr_src

               ldx  mem_tr_des
               stab 0,x
               inx
               stx  mem_tr_des

               pulx
               dex
               bne  mem_trans_loop
mem_trans_ret
               rts

