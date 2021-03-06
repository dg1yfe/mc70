;****************************************************************************
;
;    MC70 - Firmware for the Motorola MC micro trunking radio
;           to use it as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2013  Felix Erckenbrecht, DG1YFE
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
; Subroutines
;**********************************************************
;
; watchdog_toggle - I2C Watchdog bedienen
; watchdog_lo - I2C Data auf Lo
; watchdog_hi - I2C Data auf Eingang/Hi
; ptt_chk - Pr�ft PTT ( nix | B - 0=keine PTT, 1=PTT )
; squelch - Squelch testen, RX Audio & gr�ne LED entsprechend setzen ( nix | nix )
; pwr_sw_chk - pr�ft den Ein-/Ausschalter und schaltet das Ger�t ggf. aus ( CPU in Standby Mode )
; vco_switch - VCO f�r RX oder TX ausw�hlen ( B - 0=RX | nix )
; crc16 - berechnet CRC16 �ber die angegebene Anzahl von Bytes
;        ( D - Bytecount, X - Startadresse, Stack - Init-Wert | D - CRC16, Stack - CRC16 )
;
;
;
;********************************
; W A T C H D O G   T O G G L E
;********************************
watchdog_toggle
                ldab Port2_DDR_buf               ; Port2 DDR lesen
                eorb #%10                        ; Bit 1 invertieren
                stab Port2_DDR_buf
                stab Port2_DDR                   ; neuen Status setzen
                aim  #~SRDATABIT,SRDATAPORT       ;Data auf 0
                rts
watchdog_toggle_ms
               ldab tick_ms+1                  ; toggle wd line every ms
               andb #2                         ; even if called more often
               beq  wdtm_zero
               ldab #SRDATABIT
wdtm_zero
               ldaa Port2_DDR_buf               ; Port2 DDR lesen
               anda #~SRDATABIT
               aba
               staa Port2_DDR_buf
               staa Port2_DDR                   ; neuen Status setzen
               aim  #~SRDATABIT,SRDATAPORT       ;Data auf 0
               rts
;******************
; W D   R E S E T
;******************
wd_reset
               tst  bus_busy                    ; w�hren I2C Zugriff,
               bne  wd_reset_end                ; keinen Watchdog Reset durchf�hren
               bra  watchdog_toggle_ms
wd_reset_end
               rts

;******************************
; P T T   G E T   S T A T U S
;******************************
;
; last change: 8/2012
;
; Paramenter: none
;
; Returns:    A - new TRX Status (debounced) (MSB = event Bit, 0 = RX, 1 = TX)
;
; changed Regs: A, B, X
ptt_get_status
                ldaa rxtx_state             ; Alten Status holen

                ldab PTTPORT                ; Port6 Data lesen
                andb #PTTBIT                ; alles ausser PTT Bit ausblenden
                bne  ptc_on                 ;
                clrb
                bra  ptc_end
ptc_on
                ldab #1
ptc_end
                orab ui_ptt_req             ; Senderequest von UI Task?
                andb #1
                cba                         ; Mit aktuellen Status vergleichen
                bne  pgs_change             ; Verzweigen, wenn Status ungleich (PTT gedr�ckt & RX / PTT frei & TX)
                clr  ptt_debounce           ; Es hat sich nix ge�ndert, "debounce" auf 0
                bra  pgs_end                ; und zum Ende springen
pgs_change
                ldab ptt_debounce           ; Debounce Counter erh�hen
                incb
                stab ptt_debounce
                cmpb #PTT_DEBOUNCE_VAL      ; PTT mu� f�r mindestens 'PTT_DEBOUNCE_VAL' Durchg�nge gedr�ckt/gel�st sein
                bcs  pgs_end                ; Wenn nicht -> Ende
                eora #$81                   ; Status umkehren (TX -> RX / RX -> TX), MSB setzen als 'change Flag'
pgs_end
                rts
;
;****************
; R E C E I V E
;****************
;
; last change: 15.8.2012
;
; Paramenter: none
;
; Returns: nothing
;
; Set TRX to receive (deactivate PA & Mic, etc...)
;
receive
                ldab tx_ctcss_flag
                andb #TX_CTCSS              ; check if CTCSS tone should be enabled
                beq  rcv_ledoff
                jsr  tone_stop_pl           ; disable CTCSS tone generator
rcv_ledoff
                ldab #YEL_LED+LED_OFF
                jsr  led_set                ; gelbe LED aus
#ifdef EVA5
                ldaa #~SR_MIC                ; disable Mic
                ldab #SR_nTXPWR              ; disable tx power control
                jsr  send2shift_reg
#endif
#ifdef EVA9
                oim  #%00100000, Port2_Data ; Driver disable

                ldab #%00000000             ;
                ldaa #%10111111             ; Mic disable
                jsr  send2shift_reg
#endif
                ldab #TX_TO_RX_TIME
                stab gp_timer               ; wait 5ms
rcv_wait
                swi                         ; Taskswitch
                ldab gp_timer
                bne  rcv_wait               ; Timer reached 0 ?

#ifdef EVA5
                ldaa #~SR_RFPA               ; Disable RF PA
                clrb
                jsr  send2shift_reg
#endif
                clrb
                jsr  vco_switch             ; RX VCO aktivieren

                sei
                ldab #2
                stab pll_timer              ; Update PLL LED in 200 ms
                aim  #~BIT_PLL_UPDATE_NOW,pll_update_flag   ; update pll after given time
                cli

                ldx  #frequency
                jsr  set_rx_freq            ; RX Frequenz setzen

                clr  rxtx_state             ; Set state to rx
#ifdef EVA5
                ldaa #-1
                ldab #SR_RXAUDIO            ; RX Audio enable
                jsr  send2shift_reg
#endif
#ifdef EVA9
                ldab #%10000000             ; RX Audio enable
                ldaa #%11111111             ;
                jsr  send2shift_reg
#endif
                clr  sql_timer              ; und zwar sofort

                rts

;*****************
; T R A N S M I T
;*****************
;
; last change: 15.8.2012
;
; Paramenter: none
;
; Returns: none
;
; changed Regs: A,B,X
;
; aktiviert Sender
;
transmit

                ldab #YEL_LED+LED_ON        ; gelbe LED an
                jsr  led_set

                ldab #1
                jsr  vco_switch             ; TX VCO aktivieren, TX/RX Switch freigeben

                ldx  #frequency
                jsr  set_tx_freq            ; Frequenz setzen

#ifdef EVA5
                ldaa #-1
                ldab #SR_RFPA               ; activate rf pa
                jsr  send2shift_reg
#endif
#ifdef EVA9
                ldab #%00000100             ; TR Shift und TX/RX Switch auf TX
                ldaa #%01111111             ; RX Audio disable
                jsr  send2shift_reg
#endif
                ldab #RX_TO_TX_TIME
                stab gp_timer               ; 5ms warten
tnt_wait
;                swi                         ; Taskswitch
                ldab gp_timer
                bne  tnt_wait               ; Timer schon bei 0 angekommen?
#ifdef EVA5
                ldab #SR_MIC                ; enable Mic Amp
                ldaa #~SR_nTXPWR            ; enable TX power control loop
                jsr  send2shift_reg

                ldaa #~SR_RXAUDIO            ; RX Audio disable
                clrb
                jsr  send2shift_reg
#endif
#ifdef EVA9
                ldab pwr_mode               ; Power/Squelch Mode lesen
                andb #BIT_PWRMODE           ; Bit 3 isolieren (Pwr)
                beq  tnt_pwrhi
                ldab #SR_RFPWRHI            ;
tnt_pwrhi
                orab #%01000000             ; Mic enable
                oraa #%11110111
                jsr  send2shift_reg

                aim  #%11011111, Port2_Data ; Driver enable
#endif

                ldab #1
                stab rxtx_state             ; Status setzen
                sei
                ldab #2
                stab pll_timer              ; Update PLL LED in 200 ms
                aim  #~BIT_PLL_UPDATE_NOW,pll_update_flag   ; update pll after given time
                cli

                ldab tx_ctcss_flag
                andb #TX_CTCSS              ; check if CTCSS tone should be enabled
                beq  tnt_end                ;
                jsr  ctcss_start
tnt_end
                rts
;****************
; S Q U E L C H
;****************
;
; last change: 8/2012 / 12 001
;
; Parameter: none
;
; Ergebnis:  none
;
; changed Regs: A,B
;
; changed Mem:  Port 53 (Ext Alarm)
;               SR RX Audio enable
;
;
squelch
                ldab sql_timer
                orab rxtx_state            ; Im Sendefall Squelch nicht pr�fen
                bne  sq_end

                ldab #5                    ; alle 5ms checken
                stab sql_timer

                ldab sql_mode              ; Squelch aktiviert?
#ifdef EVA9
                andb #SQBIT
#endif
#ifdef EVA5
                andb #SQBIT_BOTH
#endif
                beq  sq_audio_on           ; Squelch off -> activate Audio
sq_check
                ldaa sql_ctr               ; get squelch counter
#ifdef EVA5
                lslb
                lslb
#endif
                andb PORT_SQ               ; Squelch Input auslesen
                beq  sq_cnt_down           ; Kein Signal vorhanden? Dann springen

                cmpa #SQL_HYST             ; Hysteresis level reached?
                beq  sq_audio_on           ; yes? then activate audio
                inca                       ; otherwise increment hysteresis counter
                staa sql_ctr
                bra  sq_end
sq_audio_on
                ldab SR_data_buf
                andb #SR_RXAUDIO           ; check if audio is already activated
                bne  sq_end                ; do nothing if it is

#ifdef EVA5
                aim  #~BIT_SQEXT, PORT_SQEXT ; "Ext Alarm" auf 0
                ldaa #-1
                ldab #SR_RXAUDIO
                jsr  send2shift_reg        ; RX Audio an
#endif
#ifdef EVA9
                ldaa #~SR_EXTALARM         ; "Ext Alarm" = 0
                ldab #(SR_RXAUDIO|SR_AUDIOPA); RX Audio an, Audio PA an
                jsr  send2shift_reg
#endif
                ldab #YEL_LED+LED_ON
                jsr  led_set
                bra  sq_end
sq_cnt_down
                tsta                       ; hysteresis counter at zero?
                beq  sq_audio_off          ; yes? then deactivate audio
                deca                       ; otherwise decrement (wait a bit longer)
                staa sql_ctr
                bra  sq_end
sq_audio_off
                ldab SR_data_buf
                andb #SR_RXAUDIO           ; check if audio is already DEactivated
                beq  sq_end                ; exit here if it is
#ifdef EVA5
                oim  #BIT_SQEXT, PORT_SQEXT ; "Ext Alarm" auf 1

                ldaa #~SR_RXAUDIO
                clrb
                jsr  send2shift_reg        ; RX Audio aus
#endif
#ifdef EVA9
                ldaa #~SR_RXAUDIO          ; RX Audio aus
                ldab #SR_EXTALARM          ; "Ext Alarm" = 1 / open
                jsr  send2shift_reg
#endif
                ldab #YEL_LED+LED_OFF
                jsr  led_set
sq_end
                rts

;**********************
; P W R   S W   C H K
;**********************
;
; Parameter: B - Store ( 0 - speichert aktuelle Frequenzeinstellungen)
;
; Returns  : nothing
;
; changed Regs: A
;
; further effects : If radio is switched off, Audio PA is turned off,
;                   9.6V regulator is turned off and CPU goes into STBY, then reset
;
; pr�ft den Ein-/Ausschalter und schaltet das Ger�t ggf. aus (CPU in Standby Mode)
;
pwr_sw_chk
               ldaa PORT_SWB
               anda #%BIT_SWB            ; SWB+ ?
               bne  psc_turn_it_off
               rts
psc_turn_it_off
               tstb                     ; check if we should store the current channel
               beq  psc_no_store        ; if not, just turn power down the radio
#ifdef EVA5
               ldaa PORT_PWRFAIL
               anda BIT_PWRFAIL         ; check if power is failing
               bne  psc_no_store        ; if it is, do not access EEPROM
                                        ; to prevent data corruption
#endif
               jsr  store_current       ; else store current channel & shift
psc_no_store
#ifdef EVA5
                ldaa #%01111111
                ldab #%00000000
                jsr  send2shift_reg        ; RX Audio aus

                ldaa #%01101101
                ldab #%00000000
                jsr  send2shift_reg        ;Ger�t ist aus,
                                           ; Audio PA aus,
                                           ; RX Audio aus,
                                           ; Audio PA aus,
                                           ; Ext Alarm auf 1 - kein Carrier detect anzeigen
                                           ; STBY Signal an & 9,6V Regler aus
#endif
#ifdef EVA9
                                        ; Rx Audio enable = 0
                                        ; Mic enable = 0
                                        ; Sel5 Att = 0
                                        ; /Ext Alarm = 1
                                        ; Hi/Lo Power = 1 (Lo Power)
                                        ; TX / #RX     = 0
                                        ; STBY&9,6V    = 1
                                        ; Audio PA enable = 0
                ldaa #%00010010
                ldab #%00010010
                jsr  send2shift_reg      ; RX Audio aus, Audio PA aus, Ext Alarm aus, Hi Power, RX

                WAIT(10)
                sei                      ; no need to serve interrupts anymore
                clrb
                stab Port2_DDR_buf
                stab Port2_DDR           ; set Port2 DDR to input
                                         ; effectively inhibiting "send2shift_reg" to latch
                                         ; data to SR outputs
                ldaa #%00010000
                ldab #%00010000
                jsr  send2shift_reg      ; radio is off,
                                         ; RX Audio off,
                                         ; Audio PA off,
                                         ; Ext Alarm is open - (do not display 'carrier detected')
                                         ; STBY Signal on & 9.6 V regulator off
                ldx  #$DEAD
                ldab #%10000000
                stab Port2_Data          ; latch latests SR data to SR outputs
                stab Port2_DDR           ; Set Latch output to output
                ; in a couple of cycles, CPU will be set to Standby and then put into reset
                ; estimated time is about 50 cycles for signal to discharge capacitance and
                ; set /STBY to a level recognized as "low" by CPU
                ; do not execute any meaningful code after this point
                ldd #$BEEF
                aim #%10011111, RP5CR    ; Disable internal RAM and enter Standby mode immediately
#endif
psc_loop
                bra psc_loop             ; Should not be executed, CPU is in STDBY

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
#ifdef EVA5
                aim  #%11011111,Port2_Data       ; f�r RX, Portbit l�schen
#endif
#ifdef EVA9
                ldab #%00000000
                ldaa #~SR_TXRX                  ; f�r RX, T/R Shift Bit l�schen
                jsr  send2shift_reg
#endif
                bra  vcs_end
vcs_tx
#ifdef EVA5
                oim  #%00100000,Port2_Data       ; F�r TX, Portbit setzen
#endif
#ifdef EVA9
                ldab #SR_TXRX
                ldaa #%11111111                  ;
                jsr  send2shift_reg              ; F�r TX, T/R bit setzen
#endif
vcs_end
                pulx
                pula
                pulb
                rts

;*************************
; C R C 1 6
;*************************
;
; berechnet CRC16 �ber die angegebene Anzahl von Bytes
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
                tab                  ; nach B kopieren (wird Index f�r Tabelle)
                ldx  #crc_table      ; Basisadresse der CRC Tabelle holen
                abx                  ;
                abx                  ; Index 2* addieren (2 Byte pro Eintrag)
                pula                 ; CRC LoByte holen -> wird HiByte (8 Bit Shift)
                ldab 1,x             ; neues CRC LoByte
                eora 0,x             ; Mit Wert aus Tabelle verkn�pfen, neues CRC Byte berechnen
                pulx                 ; Adresse holen
                pshb
                psha                 ; CRC sichern
                inx                  ; Adresse erh�hen
                pshx                 ; Adresse sichern
                xgdx
                tsx
                subd 4,x             ; Endadresse erreicht?
                pulx                 ; Adresse wiederholen
                pula
                pulb                 ; CRC wiederholen
                bne  crc_loop        ; loop bis Endadresse erreicht...
                pulx                 ; Startadresse vom Stack l�schen
                tsx
                std  4,x             ; CRC auf Stack speichern, Initialisierungswert �berschreiben
                pulx                 ; Endadresse vom Stack l�schen
                rts
#ifdef EVA5
;****************
; C H K   I S U
;****************
;
; Pr�ft gebr�ckten "TEST" Eingang und gibt die Kontrolle ggf. an das Update Modul weiter
;
; Parameter : none
;
; Ergebnis : none
;
;
chk_isu
               pshb
               ldab Port6_DDR_buf
               pshb
               andb #%11101111
               stab Port6_DDR_buf
               stab Port6_DDR

               ldab Port6_Data      ; TEST Pins shorted?
               andb #%00010000      ; (P64 gegen Masse)
               bne  cki_end         ; no? then exit

               jmp  isu_copy        ; else start In-System-Update
cki_end
               pulb
               stab Port6_DDR_buf
               stab Port6_DDR
               pulb
               rts
#endif
;*******************
; C H K   D E B U G
;*******************
;
; Pr�ft gebr�ckten "TEST" Eingang und gibt die Kontrolle ggf. an das Update Modul weiter
;
; Parameter : none
;
; Ergebnis : none
;
;
;chk_debug
;                pshb
;                ldab Port6_Data      ; TEST Pins gebr�ckt?
;                andb #%00010000      ; (P64 gegen Masse)
;                bne  ckd_end         ; Nein, dann zur�ck
; 
;                 jmp  debug_loader
; ckd_end
;                 pulb
;                 rts
; 
;***********************
; B A N K   S W I T C H
;***********************
;
; Routinen zur Steuerung des 17. Adressbits (A16)
; Nur im RAM ausf�hrbar! ('bank0', 'bank1')
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


;*************************
; R E A D   E E P   C H
;*************************
;
; Frequenzeinstellungen aus EEPROM holen
;
; Parameter : B - zu lesender Speicherslot
;             X - Zeiger auf Speicher f�r Frequenz
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
                pulx                        ; Adresse von Stack l�schen
                tsta
                bne  rec_end                ; Fehler zur�ckgeben
                tsx
                ldd  0,x                    ; Kanal holen
                lsrd
                lsrd
                lsrd                        ; Nur obere 13 Bit ber�cksichtigen

                ldx  #1250                  ; Frequenz berechnen
                jsr  multiply               ; 16 Bit Multiply

                pshb
                psha
                pshx                        ; 32 Bit Ergebnis sichern

                ldd  #FBASE%65536           ; Basisfrequenz (unterste einstellbare Frequenz) holen
                ldx  #FBASE>>16
                jsr  add32                  ; Basisadresse addieren

                tsx
                ldx  14,x                   ; Zieladresse f�r Frequenz holen
                pula
                pulb
                std  0,x                    ; HiWord speichern
                pula
                pulb
                std  2,x                    ; LoWord speichern
                tsx
                ldd  1,x                    ; TX Shift holen (in 12,5 kHz Kan�len)
                anda #%00000001             ; Nur 2 Bit vom Highword ber�cksichtigen

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

                ldd  #FBASE%65536
                ldx  #FBASE>>16             ; Minuend nach X:D
                jsr  sub32                  ; f_base von eingestellter Frequenz abziehen

                ldd  #1250                  ; durch 1250 (Hz) teilen
                jsr  divide32               ;

                pulx
                pula                        ; 32 Bit Quotienten l�schen
                pulb
                lsld
                lsld
                lsld                        ; Ergebnis 3 Bit nach links schieben
                tsx
                std  0,x                    ; und im tempor�ren Speicher sichern

                ldx  offset+2
                pshx
                ldx  offset
                pshx
                ldd  #25000
                jsr  divide32               ; Shift durch 25000 teilen

                pulx
                pulx
                tsx
                stab 2,x                    ; Low Byte speichern
                anda #%00000001             ; nur 10 Bit ber�cksichtigen
                oraa 1,x                    ; Mit bereits gespeichertem Byte verkn�pfen
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

                ldd  #FBASE%65536
                ldx  #FBASE>>16             ; Minuend nach X:D
                jsr  sub32                  ; f_base von eingestellter Frequenz abziehen

                ldd  #1250                  ; Ergebnis durch 1250 (Hz) teilen
                jsr  divide32               ;

                pulx
                pula
                pulb                        ; 32 Bit Quotienten l�schen
                lsld
                lsld
                lsld                        ; Ergebnis (Quotient/LoWord) 3 Bit nach links schieben
                tsx
                std  0,x                    ; und im tempor�ren Speicher sichern

                clrb
                pshb
                ldd  txshift+2
                ldx  txshift
                bpl  scu_keep_sign
                jsr  sig_inv32
scu_invert_sign
                pshx
                tsx
                inc  2,x                    ; Bit f�r Offset Vorzeichen
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
                stab 4,x                    ; Bit einf�gen
scu_ofs_nonzero
                ldd  #25000
                jsr  divide32               ; Shift durch 25000 teilen
                pulx
                pulx
                tsx
                stab 3,x                    ; Low Byte speichern
                anda #%00000001             ; nur  9 Bit ber�cksichtigen
                oraa 0,x                    ; Vorzeichen hinzuf�gen (1=neg)
                oraa 2,x                    ; Mit bereits gespeichertem Byte verkn�pfen
                staa 2,x                    ; und speichern
                ins
                tsx
                pshx                        ; Adresse im RAM
                ldd  #$01FA                 ; Adresse im EEPROM
                ldx  #3                     ; Anzahl der Bytes
                jsr  eep_seq_verify         ; Pr�fen ob dieser Inhalt bereits im EEPROM steht
                tsta
                beq  scu_omit_write         ; falls dem so ist, keinen Schreibzugriff durchf�hren
                                            ; andernfalls

                pulx                        ; remove RAM address from Stack (was altered)
                tsx
                pshx                        ; set RAM address (data is on Stack)
                ldx  #$01FA                 ; Adresse im EEPROM $01FA
                pshx                        ; auf Stack legen
                ldx  #3                     ; 3 Byte schreiben
                pshx                        ; auf Stack legen

                jsr  eep_write_seq

                pulx
                pulx
scu_omit_write
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
; Parameter : X - Zeiger auf Speicher f�r Frequenz, TxShift, Offset
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
                pulx                        ; Adresse von Stack l�schen
                tsta
                bne  rcu_end                ; Fehler zur�ckgeben
                tsx
                ldd  0,x                    ; Kanal holen
                lsrd
                lsrd
                lsrd                        ; Nur obere 12 Bit ber�cksichtigen
                ldx  #1250                  ; Frequenz berechnen
                jsr  multiply               ; 16 Bit Multiply
                pshb
                psha
                pshx                        ; 32 Bit Ergebnis sichern
                ldx  #FBASE>>16
                ldd  #FBASE%65536
                jsr  add32                  ; Basisfrequenz addieren
                tsx
                ldx  7,x                    ; Zieladresse f�r Frequenz holen
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
                std  10,x                   ; Im Platz f�r Offset speichern
                ldd  4,x                    ; HiWord TXShift holen
                std  8,x                    ; Im Platz f�r Offset speichern

                clra
rcu_end
                pulb
                pulx                        ; Stackspeicher freigeben

                pulx
                pulb
                rts

;*********
; A T O L
;*********
;
; Umrechnung String -> Integer (long)
;
; conversion ignores non-numeric chars preceeding the number
; conversion stops at NULL or
; 		   at non-numeric char trailing the number
;
; Parameter    : D  - Adresse vom Input String (nullterminiert)
;                X  - Adresse f�r Ergebnis (Integer, 32 Bit)
;
; Ergebnis     : X - *Output (32 Bit Integer)
;
; changed Regs : A, B
;
; local Stack variables:
; 0 - *input
; 2 - *frequenz
atol_new
                pshx                       ; Adresse f�r output auf Stack sichern
                pshb
                psha                       ; Adresse vom Eingabepuffer auf Stack

                clra
                clrb
                std  0,x
                std  2,x                   ; output = 0

                pulx                       ; restore string address
atol_loop
                ldab 0,x
                andb #~CHR_BLINK           ; mask Blink Bit
                beq  atol_end              ; check for end of string (0)?
                cmpb #'0'
                bcs  atol_nonum
                cmpb #'9'+1
                bcs  atol_isnum
atol_nonum
                pshx
                tsx
                ldx  2,x                   ; get *output
                ldab 0,x                   ; get output
                orab 1,x
                orab 2,x
                orab 3,x
                beq  atol_next             ; if output is still zero,
                                           ; ignore non-numeric chars
                pulx
                bra  atol_end              ; else stop conversion here
atol_isnum
                pshx                       ; save bufferaddress (index)
                subb #$30                  ; get number from ascii code

                pshb                       ; store on stack
                ldd  #exp10_1              ; get address of constant "10^1"
                tsx
                ldx  1+2,x                 ; get address of result buffer
                jsr  multiply32p           ; multiply result by 10 (in-place)
                pulb
                clra
                addd 2,x
                std  2,x
                ldd  #0
                adcb 1,x
                stab 1,x
                adca 0,x                   ; add latest digit
                staa 0,x                   ; store new output

atol_next
                pulx                       ; restore string address pointer
        	inx                        ; string address++
                bra  atol_loop             ; continue
atol_end
                pulx                       ; remove result pointer from stack
                rts                        ; return...

;**************
; S T R L E N
;**************
;
; Returns length of zero-terminated string
;
; Parameter    : X  - Address of Input String (nullterminiert)
;
; Ergebnis     : D  - length
;
; changed Regs : A, B
;
strlen
               pshx
               clra
               clrb                       ; initialize result to 0
strl_loop
               tst  0,x                   ; check for zero
               beq  strl_end              ; exit if found
               addd #1                    ; else increase strlen
               inx
               bra  strl_loop             ; loop
strl_end
               pulx                       ; remove result pointer from stack
               rts                        ; return...


;*************************
; C R C   T A B E L L E N
;*************************
crc_rom
                .db "123456789"
crc_init
                .dw $1D0F            ; Initialisierungswert f�r "non-augmented message"  ($FFFF f�r "augmented messages")
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

