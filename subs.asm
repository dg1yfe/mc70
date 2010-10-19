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
;**********************************************************
; Subroutines
;**********************************************************
;
; watchdog_toggle - I2C Watchdog bedienen
; watchdog_lo - I2C Data auf Lo
; watchdog_hi - I2C Data auf Eingang/Hi
; wait_ms - Wartet 0-65535 ms ( X - Wartezeit in ms | nix )
; ptt_chk - Prüft PTT ( nix | B - 0=keine PTT, 1=PTT )
; squelch - Squelch testen, RX Audio & grüne LED entsprechend setzen ( nix | nix )
; pwr_sw_chk - prüft den Ein-/Ausschalter und schaltet das Gerät ggf. aus ( CPU in Standby Mode )
; vco_switch - VCO für RX oder TX auswählen ( B - 0=RX | nix )
; crc16 - berechnet CRC16 über die angegebene Anzahl von Bytes
;        ( D - Bytecount, X - Startadresse, Stack - Init-Wert | D - CRC16, Stack - CRC16 )
;
;
;
;********************************
; W A T C H D O G   T O G G L E
;********************************
watchdog_toggle
                pshb
                ldab irq_wd_flag
                bne  wdt_set_hi
                inc  irq_wd_flag
                ldab Port2_DDR_buf
                orab #%10                        ; Data auf Ausgang
                stab Port2_DDR_buf
                stab Port2_DDR
                aim  #%11111101,Port2_Data       ;Data auf 0
                pulb
                rts
wdt_set_hi
                clr  irq_wd_flag
                ldab Port2_DDR_buf
                andb #%11111101                  ; Data auf Eingang/Hi
                stab Port2_DDR_buf
                stab Port2_DDR
                pulb
                rts

watchdog_toggle2
                ldab Port2_DDR_buf
                orab #%10                        ; Data auf Ausgang
                stab Port2_DDR_buf
                stab Port2_DDR
                aim  #%11111101,Port2_Data       ;Data auf 0
                nop
                nop
                ldab Port2_DDR_buf
                andb #%11111101                  ; Data auf Eingang/Hi
                stab Port2_DDR_buf
                stab Port2_DDR
                rts

;***********************
; W A T C H D O G   L O
;***********************
watchdog_lo
                pshb
                ldab Port2_DDR_buf
                orab #%10                        ; Data auf Ausgang
                stab Port2_DDR_buf
                stab Port2_DDR
                aim  #%11111101,Port2_Data       ;Data auf 0
                pulb
                rts
;***********************
; W A T C H D O G   H I
;***********************
watchdog_hi
                pshb
                ldab Port2_DDR_buf
                andb #%11111101                  ; Data auf Eingang/Hi
                stab Port2_DDR_buf
                stab Port2_DDR
                pulb
                rts
;************************
; W A I T _ M S
;************************
wait_ms         ; X : Time to wait in ms
                ; changed Regs: X

                pshb
                psha

                xgdx                  ; Wartezeit nach D
                addd tick_ms          ; aktuellen Tickzähler addieren
                xgdx                  ; wieder nach X
                bcc  wms_loop2        ; Kein Überlauf bei der Addition? Dann Sprung
wms_loop1
                cpx  tick_ms          ; Es gab einen Überlauf - Dann müssen wir warten
                swi
                bcs  wms_loop1        ; bis tick_ms auch überläuft
wms_loop2
                cpx  tick_ms          ; und dann noch solange bis tick_ms
                swi
                bcc  wms_loop2        ; größer ist als unsere Wartezeit

                pula
                pulb
                rts


;*************************
; P T T _ C H K
;*************************
;
; Parameter: none
;
; Ergebnis:  B - 0=keine PTT, 1=PTT
;
; changed Regs: B
;
ptt_chk
                ldab Port6_Data             ; Port6 Data lesen
                andb #%10000000             ; alles ausser PTT Bit ausblenden
                bne  ptc_on                 ;
                clrb
                bra  ptc_end
ptc_on
                ldab #1
ptc_end
                rts

;******************************
; P T T   G E T   S T A T U S
;******************************
;
; last change: 19.1.2007
;
; Paramenter: none
;
; Returns:    A - new TRX Status (debounced) (MSB = event Bit, 0 = RX, 1 = TX)
;
ptt_get_status
                pshb
                pshx
                ldaa rxtx_state             ; Alten Status holen
                jsr  ptt_chk                ; PTT abfragen
                orab ui_ptt_req             ; Senderequest von UI Task?
                cba                         ; Mit aktuellen Status vergleichen
                bne  pgs_change             ; Verzweigen, wenn Status ungleich (PTT gedrückt & RX / PTT frei & TX)
                clr  ptt_debounce           ; Es hat sich nix geändert, "debounce" auf 0
                bra  pgs_end                ; und zum Ende springen
pgs_change
                ldab ptt_debounce           ; Debounce Counter erhöhen
                incb
                stab ptt_debounce
                cmpb #PTT_DEBOUNCE_VAL      ; PTT muß für mindestens 'PTT_DEBOUNCE_VAL' Durchgänge gedrückt/gelöst sein
                bcs  pgs_end                ; Wenn nicht -> Ende
                eora #$81                   ; Status umkehren (TX -> RX / RX -> TX), MSB setzen als 'change Flag'
pgs_end
                pulx
                pulb
                rts
;****************
; R E C E I V E
;****************
;
; last change: 19.1.2007
;
; Paramenter: none
;
; Returns: none
;
; aktiviert Empfänger
;
receive
                pshb
                psha
                pshx

                ldab #YEL_LED+OFF
                jsr  led_set                ; gelbe LED aus

                ldab #%01000000             ; PA disable
                ldaa #%11011111             ; Mic disable
                jsr  send2shift_reg

                ldab #TX_TO_RX_TIME
                stab gp_timer               ; 5ms warten
rcv_wait
                swi                         ; Taskswitch
                ldab gp_timer
                bne  rcv_wait               ; Timer schon bei 0 angekommen?

                ldab #%00000000             ;
                ldaa #%11111110             ; TX/RX Switch auf RX
                jsr  send2shift_reg

                clrb
                jsr  vco_switch             ; RX VCO aktivieren

                ldx  #frequency
                jsr  set_rx_freq            ; RX Frequenz setzen

                clr  rxtx_state             ; Status auf RX setzen

;                ldab #%00010000            ; Audio PA enable
                ldab #%10000000             ; RX Audio enable
                ldaa #%11111111             ;
                jsr  send2shift_reg
                com  sql_flag               ; Squelch auf jedenfall neu prüfen/setzen lassen
                clr  sql_timer              ; und zwar sofort

                pulx
                pula
                pulb
                rts

;*****************
; T R A N S M I T
;*****************
;
; last change: 19.1.2007
;
; Paramenter: none
;
; Returns: none
;
; aktiviert Sender
;
transmit
                pshb
                psha
                pshx

                ldab #YEL_LED+ON            ; gelbe LED an
                jsr  led_set

                ldab #1
                jsr  vco_switch             ; TX VCO aktivieren, TX/RX Switch freigeben

                ldx  #frequency
                jsr  set_tx_freq            ; Frequenz setzen

                ldab #%00000001
                ldaa #%11111111             ; TX/RX Switch auf TX
                jsr  send2shift_reg

                ldab #RX_TO_TX_TIME
                stab gp_timer               ; 5ms warten
tnt_wait
                swi                         ; Taskswitch
                ldab gp_timer
                bne  tnt_wait               ; Timer schon bei 0 angekommen?

                ldab #%00100000             ; Mic enable
                ldaa #%10111111             ; Driver enable
                jsr  send2shift_reg

                ldab #%00000000             ;
;                ldaa #%11101111             ; Audio PA disable
                ldaa #%01111111             ; RX Audio disable
                jsr  send2shift_reg

                ldab #1
                stab rxtx_state             ; Status setzen

                pulx
                pula
                pulb
                rts

;****************
; S Q U E L C H
;****************
;
; last change: 6.2.07 / 1.0.0
;
; Parameter: none
;
; Ergebnis:  none
;
; changed Regs: Port 53 (Ext Alarm)
;               SR RX Audio enable
;
;
squelch
                pshb
                psha

                ldab sql_timer
                orab rxtx_state            ; Im Sendefall Squelch nicht prüfen
                bne  cql_end

                ldab #150                  ; alle 150ms checken
                stab sql_timer

                ldab sql_mode              ; Squelch aktiviert?
                cmpb #$20
                beq  sq_audio_on

                ldab Port5_Data            ; Squelch Input auslesen
;                andb #%01000000
                andb sql_mode              ; Carrier Squelch oder RSSI Input wählen
                cmpb sql_flag              ; mit gespeicherten Werten vergleichen
                beq  cql_end               ; Keine Änderung -> nichts machen
                tstb                       ; Signal vorhanden
                beq  sql_no_sig            ; Wenn nicht, dann springen
sq_audio_on
                stab sql_flag
                aim  #%11110111, Port5_Data; "Ext Alarm" auf 0
                ldaa #%01111111
                ldab #%10000000
                jsr  send2shift_reg        ; RX Audio an
                bra  cql_end
sql_no_sig
                stab sql_flag
                oim  #%00001000, Port5_Data; "Ext Alarm" auf 1
                ldaa #%01111111
                ldab #%00000000
                jsr  send2shift_reg        ; RX Audio aus
cql_end
                pula
                pulb
                rts

;**********************
; P W R   S W   C H K
;**********************
;
; Parameter: B - Store ( 0 - speichert aktuelle Frequenzeinstellungen)
;
; Ergebnis:  none
;
; changed Regs: none
;
;
; prüft den Ein-/Ausschalter und schaltet das Gerät ggf. aus (CPU in Standby Mode)
;
pwr_sw_chk
                pshb
                psha

                ldaa Port5_Data
                anda #%100                 ; SWB+ ?
                beq  still_on

                tstb                       ; Frequenzeinstellungen
                bne  psc_no_store          ; speichern?
;                jsr  store_current         ; derzeit angezeigten Kanal speichern
psc_no_store
                ldaa #%01111111
                ldab #%00000000
                jsr  send2shift_reg        ; RX Audio aus

                ldaa #%01101101
                ldab #%00000000
                jsr  send2shift_reg        ;Gerät ist aus,
                                           ; Audio PA aus,
                                           ; RX Audio aus,
                                           ; STBY Signal an & 9,6V Regler aus
                ; hier sollte es NIE weitergehen, da das Gerät in den Stanby Mode gesetzt wird
                ; und erst mit einem Reset wieder "geweckt" wird
still_on
                pula
                pulb
                rts

;************************
; V C O   S W I T C H
;************************
;
; Parameter: B - RX:0
;
; Ergebnis:  none
;
; changed Regs: none
;
vco_switch
                pshb
                psha
                pshx

                tstb                             ; TX oder RX?
                bne  vcs_tx                      ; TX, dann jump
                aim  #%11011111,Port2_Data       ; für RX, Portbit löschen
                bra  vcs_end
vcs_tx
                oim  #%00100000,Port2_Data       ; Für TX, Portbit setzen
vcs_end
                pulx
                pula
                pulb
                rts

;*************************
; C R C 1 6
;*************************
;
; berechnet CRC16 über die angegebene Anzahl von Bytes
;
; Parameter : D - Bytecount
;             X - Startadresse
;             Stack - Initialisierungswert
;
; Ergebnis : D - CRC16
;            Stack - CRC16
;
crc16
                pshx                 ; Startadresse sichern
                tsx
                addd 0,x             ; Bytecount + Adresse
                pshb
                psha                 ; Endadresse sichern
                ldd  4,x             ; Initialisierungswert/CRC holen
                ldx  0,x             ; Startadresse holen
crc_loop
                pshx                 ; Adresse sichern
                pshb                 ; CRC LoByte sichern
                eora 0,x             ; CRC/HiByte XOR Datenbyte
                tab                  ; nach B kopieren (wird Index für Tabelle)
                ldx  #crc_table      ; Basisadresse der CRC Tabelle holen
                abx                  ;
                abx                  ; Index 2* addieren (2 Byte pro Eintrag)
                pula                 ; CRC LoByte holen -> wird HiByte (8 Bit Shift)
                ldab 1,x             ; neues CRC LoByte
                eora 0,x             ; Mit Wert aus Tabelle verknüpfen, neues CRC Byte berechnen
                pulx                 ; Adresse holen
                pshb
                psha                 ; CRC sichern
                inx                  ; Adresse erhöhen
                pshx                 ; Adresse sichern
                xgdx
                tsx
                subd 4,x             ; Endadresse erreicht?
                pulx                 ; Adresse wiederholen
                pula
                pulb                 ; CRC wiederholen
                bne  crc_loop        ; loop bis Endadresse erreicht...
                pulx                 ; Startadresse vom Stack löschen
                tsx
                std  4,x             ; CRC auf Stack speichern, Initialisierungswert überschreiben
                pulx                 ; Endadresse vom Stack löschen
                rts

;****************
; C H K   I S U
;****************
;
; Prüft gebrückten "TEST" Eingang und gibt die Kontrolle ggf. an das Update Modul weiter
;
; Parameter : none
;
; Ergebnis : none
;
;
chk_isu
                pshb
                ldab Port6_Data      ; TEST Pins gebrückt?
;                ldab Port5_Data      ; HUB/PGM auf Masse?
                andb #%00010000      ; (P64 gegen Masse)
                bne  cki_end         ; Nein, dann zurück

                jmp  isu_copy
cki_end
                pulb
                rts
;****************
; C H K   I S U
;****************
;
; Prüft gebrückten "TEST" Eingang und gibt die Kontrolle ggf. an das Update Modul weiter
;
; Parameter : none
;
; Ergebnis : none
;
;
chk_debug
                pshb
                ldab Port6_Data      ; TEST Pins gebrückt?
                andb #%00010000      ; (P64 gegen Masse)
                bne  ckd_end         ; Nein, dann zurück

                jmp  debug_loader
ckd_end
                pulb
                rts

;***********************
; B A N K   S W I T C H
;***********************
;
; Routinen zur Steuerung des 17. Adressbits (A16)
; Nur im RAM ausführbar! ('bank0', 'bank1')
;
; Parameter : Stack - Adresse zu der nach Umschaltung verzweigt werden soll
;
; Ergebnis  : none
;
; changed Regs: IP (!!)
;
bank_switch_cpy
                aim  #%11111011,Port6_Data  ; switch to Bank 0
                rts
                oim  #%00000100,Port6_Data  ; Dazu P62 als Ausgang und auf Hi schalten
                rts
bank_switch_end

;***************************
; N O   T A S K
;***************************
notask
                swi
                ldx  start_task            ; Um Task 2 zu starten, Adresse in 'start_task' schreiben
                jmp  0,x

;**********************
; T O N E   S T A R T
;**********************
;
; Startet Ausgabe des 1750 Hz Ruftons
;
; Parameter : None
;
; Ergebnis : None
;
; changed Regs : None
;
tone_start
                pshb
                psha

                ldd  FRC
;                addd #570                  ; ca 3500 mal pro sek Int auslösen (1749,47 Hz)
                addd #285
                std  OCR2
                aim  #%11110111, TCSR1     ;
                oim  #%00001000, TCSR2     ; Timer compare Interrupt aktivieren

                clr  tone_index
                ldab #7
                stab oci_ctr

                pula
                pulb
                rts

;********************
; T O N E   S T O P
;********************
;
;
;
tone_stop
                aim  #%11110111, TCSR2     ;

                ldd  FRC
                addd #1194                 ; in einer ms wieder OCI ausführen
                std  OCR1
                oim  #%00001000, TCSR1     ; Timer compare Interrupt aktivieren
                aim  #%10011111, Port6_Data; Pin auf 0 setzen
                rts

;*************************
; R E A D   E E P   C H
;*************************
;
; Frequenzeinstellungen aus EEPROM holen
;
; Parameter : B - zu lesender Speicherslot
;             X - Zeiger auf Speicher für Frequenz
;
; Ergebnis : A - 0 = OK
;
; Changed Regs : A
;
;
read_eep_ch
                pshb
                pshx

                tsx
                xgdx
                subd #10
                xgdx
                txs                         ; 10 Byte Stackspeicher reservieren

                ldaa #10                    ;
                mul                         ; 10 Bytes pro Slot
                ldx  #$0100                 ; Basisadresse $0100
                abx                         ; Slot-Adresse im EEPROM berechnen (D)
                xgdx                        ; Von X nach D


                tsx                         ; Zieladresse = Stackspeicher
                pshx                        ; Zieladresse auf Stack speichern
                ldx  #10                    ; 10 Bytes lesen
                jsr  eep_seq_read
                pulx                        ; Adresse von Stack löschen
                tsta
                bne  rec_end                ; Fehler zurückgeben
                tsx
                ldd  0,x                    ; Kanal holen
                lsrd
                lsrd
                lsrd                        ; Nur obere 12 Bit berücksichtigen

                ldx  #1250                  ; Frequenz berechnen
                jsr  multiply               ; 16 Bit Multiply

                pshb
                psha
                pshx                        ; 32 Bit Ergebnis sichern

                ldx  f_base
                ldd  f_base+2
                jsr  add32                  ; Basisadresse addieren

                tsx
                ldx  14,x                   ; Zieladresse für Frequenz holen
                pula
                pulb
                std  0,x                    ; HiWord speichern
                pula
                pulb
                std  2,x                    ; LoWord speichern
                tsx
                ldd  1,x                    ; TX Shift holen (in 12,5 kHz Kanälen)
                anda #%00000001             ; Nur 2 Bit vom Highword berücksichtigen

                ldx  #25000
                jsr  multiply               ; mit 12500 multiplizieren

                std  ui_txshift+2           ; neue Shift setzen (lassen)
                stx  ui_txshift

                clra
rec_end
                tsx
                xgdx
                addd #10
                xgdx
                txs                         ; Stackspeicher freigeben

                pulx
                pulb
                rts

;*************************
; S T O R E   E E P   C H
;*************************
;
; Frequenzeinstellungen in EEPROM Slot speichern
;
; Parameter : B - zu schreibender Slot
;
; Ergebnis :  A - 0 = OK
;
; Changed Regs : A
;
;
store_eep_ch
                pshx
                pshb

                tsx
                xgdx
                subd #10
                xgdx
                txs                         ; 10 Byte reservieren auf Stack

                ldx  frequency+2
                pshx
                ldx  frequency
                pshx                        ; Subrathend auf Stack

                ldx  f_base                 ;
                ldd  f_base+2               ; Minuend nach X:D
                jsr  sub32                  ; f_base von eingestellter Frequenz abziehen

                ldd  #1250                  ; durch 1250 (Hz) teilen
                jsr  divide32               ;

                pulx
                pula                        ; 32 Bit Quotienten löschen
                pulb
                lsld
                lsld
                lsld                        ; Ergebnis 3 Bit nach links schieben
                tsx
                std  0,x                    ; und im temporären Speicher sichern

                ldx  offset+2
                pshx
                ldx  offset
                pshx
                ldd  #25000
                jsr  divide32               ; Shift durch 12500 teilen

                pulx
                pulx
                tsx
                stab 2,x                    ; Low Byte speichern
                anda #%00000001             ; nur 10 Bit berücksichtigen
                oraa 1,x                    ; Mit bereits gespeichertem Byte verknüpfen
                staa 1,x                    ; und speichern

                clrb                        ; noch keinen Namen speichern
                stab 3,x

                ldab 10,x                   ; Slotnummer holen
                ldaa #10                    ; mit 10 multiplizieren
                mul                         ; da 10 Bytes pro Slot
                pshx                        ; Stack Adresse speichern
                ldx  #$0100                 ; Basisadresse im EEPROM $0100
                abx                         ; Slot-Adresse im EEPROM berechnen (D)
                pshx                        ; auf Stack legen
                ldx  #10                    ; 10 Byte schreiben
                pshx                        ; auf Stack legen

                jsr  eep_write_seq

                pulx
                pulx
                pulx

                tsx
                xgdx
                addd #10
                xgdx
                txs                         ; Stackspeicher freigeben

                pulb
                pulx
                rts
;***************************
; S T O R E   C U R R E N T
;***************************
;
; Frequenzeinstellungen in EEPROM Slot speichern
;
; Parameter : none
;
; Ergebnis : A = Status (O=OK)
;
; Changed Regs : none
;
;
store_current
                pshx
                pshb
                psha

                pshx
                pshx
                pshb                        ; 5 Byte reservieren auf Stack

                ldx  frequency+2
                pshx
                ldx  frequency
                pshx                        ; Subrathend auf Stack

                ldx  f_base                 ;
                ldd  f_base+2               ; Minuend nach X:D
                jsr  sub32                  ; f_base von eingestellter Frequenz abziehen

                ldd  #1250                  ; Ergebnis durch 1250 (Hz) teilen
                jsr  divide32               ;

                pulx
                pula
                pulb                        ; 32 Bit Quotienten löschen
                lsld
                lsld
                lsld                        ; Ergebnis (Quotient/LoWord) 3 Bit nach links schieben
                tsx
                std  0,x                    ; und im temporären Speicher sichern

                clrb
                pshb
                ldd  txshift+2
                ldx  txshift
                bpl  scu_keep_sign
                jsr  sig_inv32
scu_invert_sign
                pshx
                tsx
                inc  2,x                    ; Bit für Offset Vorzeichen
                lsl  2,x                    ; erzeugen
                pulx
scu_keep_sign
                pshb
                psha
                pshx
                ldd  offset
                orab offset+2
                orab offset+3
                subd #0                     ; Offset = 0?
                beq  scu_ofs_nonzero        ; Ja, dann Bit nicht setzen
                tsx
                ldab 4,x
                orab #4                     ; Offset aktiviert
                stab 4,x                    ; Bit einfügen
scu_ofs_nonzero
                ldd  #25000
                jsr  divide32               ; Shift durch 25000 teilen
                pulx
                pulx
                tsx
                stab 3,x                    ; Low Byte speichern
                anda #%00000001             ; nur  9 Bit berücksichtigen
                oraa 0,x                    ; Vorzeichen hinzufügen (1=neg)
                oraa 2,x                    ; Mit bereits gespeichertem Byte verknüpfen
                staa 2,x                    ; und speichern
                ins
                tsx
                pshx                        ; Adresse im RAM
                ldx  #$01FA                 ; Adresse im EEPROM $01FA
                pshx                        ; auf Stack legen
                ldx  #3                     ; 3 Byte schreiben
                pshx                        ; auf Stack legen
                jsr  eep_write_seq

                pulx
                pulx
                pulx

                pulx
                pulx
                pulb                        ; Stackspeicher freigeben

                ins
                pulb
                pulx
                rts
;**************************
; R E A D   C U R R E N T
;**************************
;
; zuletzt eingestellten Kanal aus EEPROM lesen
;
; Parameter : X - Zeiger auf Speicher für Frequenz, TxShift, Offset
;
; Ergebnis  : A - 0 = OK
;
; Changed Regs : A
;
;
read_current
                pshb
                pshx                        ; Zieladresse sichern

                pshx
                pshb                        ; 3 Byte Stackspeicher reservieren

                tsx                         ; Zieladresse = Stackspeicher
                pshx                        ; Zieladresse auf Stack speichern
                ldd  #$01FA                 ; EEPROM Adresse $01FA
                ldx  #3                     ; 3 Bytes lesen
                jsr  eep_seq_read
                pulx                        ; Adresse von Stack löschen
                tsta
                bne  rcu_end                ; Fehler zurückgeben
                tsx
                ldd  0,x                    ; Kanal holen
                lsrd
                lsrd
                lsrd                        ; Nur obere 12 Bit berücksichtigen
                ldx  #1250                  ; Frequenz berechnen
                jsr  multiply               ; 16 Bit Multiply
                pshb
                psha
                pshx                        ; 32 Bit Ergebnis sichern
                ldx  f_base
                ldd  f_base+2
                jsr  add32                  ; Basisfrequenz addieren
                tsx
                ldx  7,x                    ; Zieladresse für Frequenz holen
                pula
                pulb
                std  0,x                    ; HiWord speichern
                pula
                pulb
                std  2,x                    ; LoWord speichern
                tsx
                ldd  1,x
                anda #%00000001             ; Nur 1 Bit vom Highword
                ldx  #25000
                jsr  multiply               ; mit 25000 multiplizieren

                pshb
                psha
                pshx
                tsx
                ldab 5,x
                andb #%00000010             ; Vorzeichen testen (+/- Shift)
                beq  rcu_keep_sign
                pulx
                pula
                pulb
                jsr  sig_inv32              ; Vorzeichen umkehren
                bra  rcu_store_txshift
rcu_keep_sign
                pulx
                pula
                pulb
rcu_store_txshift

                pshx                        ; HiWord sichern
                tsx
                ldx  5,x                    ; Zeiger auf Zwischenspeicher holen
                std  6,x                    ; LoWord vom Offset speichern
                pula
                pulb
                std  4,x                    ; HiWord vom Offset speichern

                tsx
                ldab 1,x
                ldx  3,x                    ; Zeiger auf Zwischenspeicher holen
                andb #%00000100             ; TX Shift aktiviert?
                bne  rcu_store_offset       ; Ja, dann Shiftwert auch nach "Offset" kopieren
                ldd  #0
                std  8,x
                std  10,x                   ; Offset deaktiviert
                bra  rcu_end
rcu_store_offset
                ldd  6,x                    ; LoWord TxShift holen
                std  10,x                   ; Im Platz für Offset speichern
                ldd  4,x                    ; HiWord TXShift holen
                std  8,x                    ; Im Platz für Offset speichern

                clra
rcu_end
                pulb
                pulx                        ; Stackspeicher freigeben

                pulx
                pulb
                rts

;
;*************************
; C R C   T A B E L L E N
;*************************
crc_rom
                .db "123456789"
crc_init
                .dw $1D0F            ; Initialisierungswert für "non-augmented message"  ($FFFF für "augmented messages")
crc_init2       .dw $FFFF
crc_table       ; CCIT / ITU CRC-16
                .dw $0000, $1021, $2042, $3063, $4084, $50a5, $60c6, $70e7 ;00
                .dw $8108, $9129, $a14a, $b16b, $c18c, $d1ad, $e1ce, $f1ef ;08
                .dw $1231, $0210, $3273, $2252, $52b5, $4294, $72f7, $62d6 ;10
                .dw $9339, $8318, $b37b, $a35a, $d3bd, $c39c, $f3ff, $e3de ;18
                .dw $2462, $3443, $0420, $1401, $64e6, $74c7, $44a4, $5485 ;20
                .dw $a56a, $b54b, $8528, $9509, $e5ee, $f5cf, $c5ac, $d58d ;28
                .dw $3653, $2672, $1611, $0630, $76d7, $66f6, $5695, $46b4 ;30
                .dw $b75b, $a77a, $9719, $8738, $f7df, $e7fe, $d79d, $c7bc ;38
                .dw $48c4, $58e5, $6886, $78a7, $0840, $1861, $2802, $3823 ;40
                .dw $c9cc, $d9ed, $e98e, $f9af, $8948, $9969, $a90a, $b92b ;48
                .dw $5af5, $4ad4, $7ab7, $6a96, $1a71, $0a50, $3a33, $2a12 ;50
                .dw $dbfd, $cbdc, $fbbf, $eb9e, $9b79, $8b58, $bb3b, $ab1a ;58
                .dw $6ca6, $7c87, $4ce4, $5cc5, $2c22, $3c03, $0c60, $1c41 ;60
                .dw $edae, $fd8f, $cdec, $ddcd, $ad2a, $bd0b, $8d68, $9d49 ;68
                .dw $7e97, $6eb6, $5ed5, $4ef4, $3e13, $2e32, $1e51, $0e70 ;70
                .dw $ff9f, $efbe, $dfdd, $cffc, $bf1b, $af3a, $9f59, $8f78 ;78
                .dw $9188, $81a9, $b1ca, $a1eb, $d10c, $c12d, $f14e, $e16f ;80
                .dw $1080, $00a1, $30c2, $20e3, $5004, $4025, $7046, $6067 ;88
                .dw $83b9, $9398, $a3fb, $b3da, $c33d, $d31c, $e37f, $f35e ;90
                .dw $02b1, $1290, $22f3, $32d2, $4235, $5214, $6277, $7256 ;98
                .dw $b5ea, $a5cb, $95a8, $8589, $f56e, $e54f, $d52c, $c50d ;A0
                .dw $34e2, $24c3, $14a0, $0481, $7466, $6447, $5424, $4405 ;A8
                .dw $a7db, $b7fa, $8799, $97b8, $e75f, $f77e, $c71d, $d73c ;B0
                .dw $26d3, $36f2, $0691, $16b0, $6657, $7676, $4615, $5634 ;B8
                .dw $d94c, $c96d, $f90e, $e92f, $99c8, $89e9, $b98a, $a9ab ;C0
                .dw $5844, $4865, $7806, $6827, $18c0, $08e1, $3882, $28a3 ;C8
                .dw $cb7d, $db5c, $eb3f, $fb1e, $8bf9, $9bd8, $abbb, $bb9a ;D0
                .dw $4a75, $5a54, $6a37, $7a16, $0af1, $1ad0, $2ab3, $3a92 ;D8
                .dw $fd2e, $ed0f, $dd6c, $cd4d, $bdaa, $ad8b, $9de8, $8dc9 ;E0
                .dw $7c26, $6c07, $5c64, $4c45, $3ca2, $2c83, $1ce0, $0cc1 ;E8
                .dw $ef1f, $ff3e, $cf5d, $df7c, $af9b, $bfba, $8fd9, $9ff8 ;F0
                .dw $6e17, $7e36, $4e55, $5e74, $2e93, $3eb2, $0ed1, $1ef0 ;F8

