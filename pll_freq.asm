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
;************************************************
; P L L
;************************************************
;
; freq_init         - Frequenzeinstellungen setzen
; freq_init_eep     - Frequenzeinstellungen aus EEPROM holen
; freq_init_rom     - Frequenzeinstellungen aus ROM holen
; pll_init          - PLL initialisieren (D -> Kanalraster | A -> Status)
;
; pll_led           - �berpr�ft PLL Lock alle 500ms (nix | nix)
; pll_chk           - aktiviert rote LED, wenn PLL nicht eingerastet ist (nix)
; pll_lock_chk      - PLL Lock auslesen ( nix | B=0 PLL not locked, $20=PLL locked)
; pll_set_channel   - programmiert die PLL auf den in X:D gegebenen Kanal (X:D -> Kanal | nix )
; pll_set_freq      - programmiert die PLL auf Frequenz ( X -> Zeiger auf Frequenz DWord | nix )
;
; set_rx_freq       - Setzt die Frequenz zum Empfang, Frequenz - 21,4MHz ZF (X -> Zeiger auf Frequenz DWord | nix )
; set_tx_freq       - Setzt die Frequenz zum Senden (X -> Zeiger auf Frequenz DWord | nix )
; set_freq          - programmiert die PLL auf Frequenz (X - Zeiger auf Frequenz (32 Bit) | nix )
; frq_cv_freq_ch    - Umrechnung Frequenz in Kanal ( X - Zeiger auf Frequenz DWord | X:D - Kanal)
; frq_cv_ch_freq    - Umrechnung Kanal in Frequenz ( X:D - Kanal | X:D - Frequenz DWord)
; frq_get_freq      - Liefert die aktuell eingestellte Frequenz ( nix | X:D - Frequenz DWord)
; frq_calc_freq     - Umrechnung Eingabe in Frequenz
;                     ( D - Zeiger auf Eingabe (String), X - Zeiger auf Platz f�r Frequenz DWord)
; frq_sub_offset    - Zieht FBASE von Frequenz ab, n�tig f�r Kanalberechnung
;                     ( X  - Pointer auf Frequenz DWord, D  - Pointer auf DWord f�r Frequenz - FBASE )
; frq_add_offset    - Zieht FBASe von Frequenz ab, n�tig f�r Kanalberechnung
;                     ( X  - Pointer auf Frequenz DWord, D  - Pointer auf DWord f�r Frequenz - FBASE )
;
; frq_update        - Teilt Control Task mit, dass eine neue Frequenz gesetzt wurde
; freq_print        - Gibt Frequenz auf Display aus
; freq_offset_print - Gibt aktuelles Offset auf Display aus
;
;
;************************************************
; F R E Q U E N C Y
;************************************************
;********************
; F R E Q   I N I T
;********************
;
; Frequenzeinstellungen setzen
;
; Versucht zun�chst Frequenzeinstellungen aus EEPROM zu laden,
; schl�gt dies fehl wird aus dem ROM initialisiert, die gelbe LED blinkt dabei
;
; Parameter    : none
;
; Ergebnis     : A - 0 = OK (Init aus EEPROM)
;
;
; changed Regs : A, B, X
;
freq_init
                jsr  freq_init_eep      ; Versuchen Frequenzeinstellunegen aus EEPROM zu lesen
                tsta
                beq  fri_end            ; Bei Fehler
                jsr  freq_init_rom      ; Aus ROM initialisieren
                ldaa #1
fri_end
                rts

;***************************
; F R E Q   I N I T   E E P
;***************************
;
; Frequenzeinstellungen aus EEPROM holen
;
; Parameter : None
;
; Ergebnis : A -   0 = OK
;               Rest = Lesefehler
;
; Changed Regs : A,B,X
;
;
freq_init_eep
                tsx
                xgdx
                subd #12
                xgdx
                txs                      ; 12 Bytes Platz auf dem Stack reservieren (3 DWords)

; zuletzt eingestellten Kanal aus EEPROM lesen
;
; Parameter : X - Zeiger auf Speicher f�r Frequenz, TxShift, Offset
;
; Ergebnis  : A - 0 = OK
                tsx
                pshx                        ; Zieladresse auf Stack speichern
                ldd  #$01FA                 ; EEPROM Adresse $01FA
                ldx  #3                     ; 3 Bytes lesen
                jsr  eep_seq_read
                pulx                        ; Adresse von Stack l�schen
                tsta
                bne  ife_r_end              ; Fehler zur�ckgeben
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
                ldd  #FBASE%65536       ; Basisfrequenz (unterste einstellbare Frequenz) holen
                ldx  #FBASE>>16

                ADD32

                tsx
                pula
                pulb
                std  8+4,x                  ; HiWord speichern
                pula
                pulb
                std  10+4,x                 ; LoWord speichern
                tsx
                ldd  1+0,x
                anda #%00000001             ; Nur 1 Bit vom Highword
                ldx  #25000
                jsr  multiply               ; mit 25000 multiplizieren

                pshb
                pshx
                tsx
                ldab 1+3,x
                andb #%00000010             ; Vorzeichen testen (+/- Shift)
                pulx
                pulb
                beq  ife_r_keep_sign

                SIGINV32

                bra  ife_r_store_txshift
ife_r_keep_sign
ife_r_store_txshift

                pshx                        ; HiWord sichern
                tsx
                std  6+2,x                  ; LoWord vom Offset speichern
                pula
                pulb
                std  4+2,x                  ; HiWord vom Offset speichern

                tsx
                ldab 1+0,x
                andb #%00000100             ; TX Shift aktiviert?
                bne  ife_r_store_offset     ; Ja, dann Shiftwert auch nach "Offset" kopieren
                ldd  #0
                std  0+0,x
                std  2+0,x                  ; Offset deaktiviert
                bra  ife_r_end
ife_r_store_offset
                ldd  6+0,x                  ; LoWord TxShift holen
                std  2+0,x                  ; Im Platz f�r Offset speichern
                ldd  4+0,x                  ; HiWord TXShift holen
                std  0+0,x                  ; Im Platz f�r Offset speichern

                clra
ife_r_end
                tsta                     ; Lesen erfolgreich?
                beq  ife_ok              ; Ja? Dann alles ok
                tsx
                xgdx
                addd #12
                xgdx
                txs                      ; Stackspeicher freigeben
                bra  ife_end             ; Mit Fehlermeldung enden
ife_ok
                pulx
                stx  offset              ; Offset holen
                pulx
                stx  offset+2            ; und speichern

                pulx
                stx  txshift
                pulx                     ; TxShift holen
                stx  txshift+2           ; Und speichern

                pulx
                stx  frequency
                pulx                     ; Frequenz holen
                stx  frequency+2         ; und speichern
                clra                     ; Alles ok -> A=0
ife_end
                rts

;***************************
; F R E Q   I N I T   R O M
;***************************
;
; Frequenzeinstellungen aus ROM holen
;
; Parameter    : none
;
; Ergebnis     : none
;
; changed Regs : none
;
freq_init_rom
                pshx
                pshb
                psha

                ldx  #FDEF%65536        ; Default Frequenz setzen (433,5)
                stx  frequency+2

                ldx  #FDEF>>16
                stx  frequency

                ldx  #FOFF0
                stx  offset
                stx  offset+2

                ldx  #FTXOFF>>16
                stx  txshift
                ldx  #FTXOFF%65536
                stx  txshift+2

                pula
                pulb
                pulx
                rts


;*****************
; P L L   I N I T
;*****************
;
; Initialisiert PLL
;
; Parameter: D - Kanalraster
;
; Ergebnis : A - Status: 0=OK
;                        1=Fehler (Kanalraster zu klein)
;
; changed Regs: A,B
;
pll_init
                pshx
                pshb
                psha
                aim  #~BIT_PLLLATCH, PORT_PLLLATCH ; PTT Syn Latch = 0

                ldx  #FREF%65536            ; Referenzfrequenz LoWord
                pshx                        ; Auf Stack
                ldx  #FREF>>16              ; Referenzfrequenz HiWord
                pshx                        ; auf Stack
                                            ; Divisor (Kanalraster) befindet sich schon in D
                jsr  divide32
                pula
                pulb
                pulx
                subd #0
                bne  pli_error              ; Kanalraster zu gro� (obere 16 Bit <>0)
                pshx
                pula
                pulb                        ; X -> D
                anda #%11000000             ; Referenz Teiler ist 14 Bit gro�,
                bne  pli_error              ; alles >14 Bit -> Fehler

                ldaa #1                     ; select R
                clrb
                jsr  send2pll               ; set R

                pula
                pulb                        ; Kanalraster holen
;                std  f_step                 ; Kanalraster speicher
                pshb

                clra
pli_end
                clr  rxtx_state             ; State auf RX zur�cksetzen
                clr  ptt_debounce           ; Debounce Counter zur�cksetzen
                pulb
                pulx
                rts
pli_error
                pula
                ldaa #1
                bra  pli_end

;***************
; P L L   L E D
;***************
;
; �berpr�ft PLL Lock wenn PLL Timer abgelaufen ist
; aktiviert rote LED, wenn PLL nicht eingerastet ist
;
; Check PLL lock state
; if pll_timer is zero OR
; update is enforced (A != 0)
;
; Parameter    : A : Force (A=1 forces update)
;
; Ergebnis     : Nichts
;
; changed Regs : A,B
;
pll_led
                ldab LOCKPORT
                andb #LOCKBIT
                tsta
                bne  plc_force_update
                ldaa pll_update_flag
                anda #BIT_PLL_UPDATE_NOW     ; check if UI task requests immediate
                bne  plc_force_update        ; update of PLL state

                ldaa pll_timer
                bne  plc_end                 ; PLL check timer is zero? If not, exit
                tba                          ; transfer state to A
                beq  plc_state_is_0          ; check if bit is zero
                ldaa #BIT_PLL_STATE          ; else set PLL state bit
                                             ; (this is different from the port bit!)
plc_state_is_0
                eora pll_locked_flag         ; Check for state change
                anda #BIT_PLL_STATE          ; if there was no change
                beq  plc_end                 ; exit here
                ldaa #PLLCHKTIMEOUT          ; in case something changed
                staa pll_timer               ; delay display of next change by
                                             ; a small time, to avoid congestion of the
                                             ; display comm if lock is unstable
plc_force_update
                tstb
                bne  plc_locked
                aim  #~(BIT_PLL_STATE),pll_locked_flag  ; save new status (PLL unlocked)
                ldab #RED_LED+LED_ON         ; activate red LED
                bra  plc_set_led
plc_locked
                oim  #(BIT_PLL_STATE),pll_locked_flag  ; save new status (PLL locked)
                ldab #RED_LED+LED_OFF        ; deactivate red LED
plc_set_led
                jsr  led_set                 ; set LED state
                aim  #~(BIT_PLL_UPDATE_NOW),pll_update_flag ; signal update of PLL state
plc_end
                rts
;
;************************
; P L L   L O C K   C H K
;************************
;
; Liest PLL Lock Status von PLL IC ein
;
; Parameter : None
;
; Returns : B - Status
;                 0 = NOT locked
;             "LOCKBIT" = PLL locked
;
; changed Regs: B
;
pll_lock_chk
                ldab LOCKPORT
                andb #LOCKBIT                  ; nur PTT Lock detect Bit lesen
                rts


;*******************************
; P L L   S E T   C H A N N E L
;*******************************
;
; programmiert die PLL auf den in X:D gegebenen Kanal
;
; Parameter    : X:D - Kanal
;
; Ergebnis     : Nichts
;
; changed Regs : none
;
;
pll_set_channel
                stx  channel
                std  channel+2              ; Kanal speichern
                pshb
                psha
                pshx                        ; Dividend auf Stack

                ldd  #PRESCALER             ; Vorteiler 127 f�r 70cm, 40 f�r 2m Version

                                            ; PLL Teiler f�r %128 Vorteiler berechnen
                jsr  divide32               ; 32 Bit Division, Dividend auf Stack, Divisor in D,
                                            ;                  Ergebnis auf Stack, Rest in X
                xgdx                        ; Teiler N = Quotient,
                                            ; Teiler A = Rest
                pulx                        ; Quotient HiWord vom Stack l�schen
                pulx                        ; Quotient LoWord (Teiler f�r N holen)

                clra                        ; A = Reg Select (0=AN, 1=R)
                jsr  send2pll               ; X = Divider Value N
                                            ; B = Divider Value A

                ldaa #1                     ; select R
                clrb
                ldx  #PLLREF
                jsr  send2pll               ; set R

                rts

;**************************
; P L L   S E T   F R E Q
;**************************
;
; programmiert die PLL auf Frequenz
;
; Parameter    : X - Zeiger auf Frequenz (32 Bit)
;
; Ergebnis     : Nichts
;
; changed Regs : none
;
;
; pll_set_freq
;                 jsr  frq_cv_freq_ch         ; Frequenz in Kanal mit Schrittweite f_step umrechnen
;                                             ; Kanal kommt in X:D
;                 jsr  pll_set_channel        ; PLL programmieren
;
;                 rts

;**************************
; S E T   R X   F R E Q
;**************************
;
; Setzt die Frequenz zum Empfang (Frequenz - 21,4MHz ZF)
;
; Parameter    : X - Zeiger auf Frequenz (32 Bit)
;
; Ergebnis     : Nichts
;
; changed Regs : A, B, X
;
;
set_rx_freq
                ldd  2,x                    ; Frequenzwort LoWord nach D
                pshb
                psha                        ; Lo Word auf Stack
                ldx  0,x                    ; Frequenzwort HiWord nach X
                pshx                        ; HiWord auf Stack

                ldd  #RXZF%65536            ; RXZF LoWord
                ldx  #RXZF>>16              ; RXZF HiWord
                jsr  sub32                  ; RXZF von Frequenzwort abziehen -> RX VCO Frequenz berechnen
;                SUB32
;****
; RX VCO Frequenz setzen
; Frequenz in Kanal mit Schrittweite f_step umrechnen
                tsx
                pshx                        ; Zeiger auf Dividend auf Stack legen
                ldd  #FSTEP                      ; Divisor holen
                jsr  divide32s                  ; Durch Kanalabstand teilen
                ins
                ins
                ldd  #FSTEP                      ; Kanalabstand holen
                lsrd                             ; durch 2 teilen
                xgdx                             ; nach X bringen und Rest nach D
                pshx                             ; Kanalabstand/2 auf Stack
                tsx
                subd 0,x                         ; Ist der Rest >= halber Kanalabstand?
                pulx                             ; Stack bereinigen
                pulx                             ; HiWord vom Stack holen
                pula
                pulb                             ; LoWord vom Stack holen
                bcs  srf_cfc_end                 ; abrunden wenn Rest < f_step/2
                addd #1                          ; oder aufrunden
                xgdx
                adcb #0
                adca #0                         ; eventuellen �bertrag ber�cksichtigen
                xgdx
srf_cfc_end
;****
                jsr  pll_set_channel        ; PLL programmieren

                jsr  frq_get_freq           ; eingestellte Frequenz (entsprechend Kanalraster) holen

                pshb
                psha
                pshx

                ldx  #RXZF>>16
                ldd  #RXZF%65536

                jsr  add32                  ; ZF addieren
;                ADD32
                pulx
                stx  frequency
                pulx
                stx  frequency+2            ; und Empfangsfrequenz speichern

                rts                         ; R�cksprung

;**************************
; S E T   T X   F R E Q
;**************************
;
; Setzt die Frequenz zum Senden
;
; Parameter    : X - Zeiger auf Frequenz (32 Bit)
;
; Ergebnis     : Nichts
;
; changed Regs : none
;
;
set_tx_freq
                ldd  2,x                    ; Frequenzwort LoWord nach D
                pshb
                psha
                ldx  0,x                    ; Frequenzwort HiWord nach X
                pshx                        ; auf Stack

                ldd  offset+2
                ldx  offset
                jsr  sub32                  ; Offset von Frequenzwort abziehen -> TX VCO Frequenz berechnen
stf_set
;********
; TX VCO Frequenz setzen
; Frequenz in Kanal mit Schrittweite f_step umrechnen
                ldd  #FSTEP                      ; Divisor holen
                jsr  divide32                    ; Durch Kanalabstand teilen
                ldd  #FSTEP                      ; Kanalabstand holen
                lsrd                             ; durch 2 teilen
                xgdx                             ; nach X bringen und Rest nach D
                pshx                             ; Kanalabstand/2 auf Stack
                tsx
                subd 0,x                         ; Ist der Rest >= halber Kanalabstand?
                pulx                             ; Stack bereinigen
                pulx                             ; HiWord vom Stack holen
                pula
                pulb                             ; LoWord vom Stack holen
                bcs  stf_cfc_end                 ; abrunden wenn Rest < f_step/2
                addd #1                          ; oder aufrunden
                xgdx
                adcb
                adca                             ; eventuellen �bertrag ber�cksichtigen
                xgdx
stf_cfc_end
;********
                jsr  pll_set_channel        ; PLL programmieren

                jsr  frq_get_freq           ; eingestellte Frequenz (entsprechend Kanalraster) holen
                pshb
                psha
                pshx

                ldx  offset
                ldd  offset+2
                jsr  add32

                pulx
                stx  frequency
                pulx
                stx  frequency+2            ; und neue Frequenz speichern

                rts

;**************************
; S E T   F R E Q
;**************************
;
; Setzt die Frequenz auf die X zeigt, pr�ft vorher ob gesendet oder empfangen wird
;
; Parameter    : X - Zeiger auf Frequenz (32 Bit)
;
; Ergebnis     : Nichts
;
; changed Regs : none
;
;
set_freq
                ldab rxtx_state          ; senden oder empfangen wir gerade?
                bne  sfq_tx              ; entsprechend status die Frequenz setzen
                jmp  set_rx_freq
sfq_tx
                jmp  set_tx_freq

;******************************
; F R Q   C V   F R E Q   C H
;******************************
;
; Umrechnung Frequenz in Kanal
;
; Parameter    : X - Zeiger auf Frequenz DWord
;
; Ergebnis     : X:D - Kanal (Kanalabstand = f_step)
;
; changed Regs : D,X
;
;
frq_cv_freq_ch
                ldd  2,x                         ; Frequenz LoWord und
                ldx  0,x                         ; Frequenz HiWord holen
                pshb
                psha
                pshx                             ; Frequenz=Dividend auf Stack
                ldd  #FSTEP                      ; Divisor holen
                jsr  divide32                    ; Durch Kanalabstand teilen
                ldd  #FSTEP                      ; Kanalabstand holen
                lsrd                             ; durch 2 teilen
                xgdx                             ; nach X bringen und Rest nach D
                pshx                             ; Kanalabstand/2 auf Stack
                tsx
                subd 0,x                         ; Ist der Rest >= halber Kanalabstand?
                pulx                             ; Stack bereinigen
                pulx                             ; HiWord vom Stack holen
                pula
                pulb                             ; LoWord vom Stack holen
                bcs  cfc_end                     ; abrunden wenn Rest < f_step/2
                addd #1                          ; oder aufrunden
                xgdx
                adcb
                adca                             ; eventuellen �bertrag ber�cksichtigen
                xgdx
cfc_end
                rts

;******************************
; F R Q   C V   C H   F R E Q
;******************************
;
; Umrechnung Kanal in Frequenz
;
;  Parameter    : X:D - Kanal
;
;  Ergebnis     : X:D - Frequenz des aktuell eingestellten Kanals
;
;  changed Regs : D,X
;
;
frq_cv_ch_freq
                pshb
                psha
                pshx                             ; Kanal auf Stack speichern
                ldd  #FSTEP                      ; Kanalabstand holen
                ldx  #0                          ; HiWord = 0
                jsr  multiply32                  ; Frequenz berechnen
                rts

;**************************
; F R Q   G E T   F R E Q
;**************************
;
;  Liefert die aktuell eingestellte Frequenz
;
;
;  Parameter    : none
;
;  Ergebnis     : X:D - Frequenz des aktuell eingestellten Kanals
;
;  changed Regs : D,X
;
;
frq_get_freq
                ldx  channel+2
                pshx
                ldx  channel
                pshx
                ldd  #FSTEP
                ldx  #0
                jsr  multiply32
                ins
                ins
                ins
                ins  ; Kanal vom Stack l�schen
                rts

;**********************
; F R Q   U P D A T E
;**********************
;
; Funktion wird von UI Task aufgerufen. Teilt Control Task mit, dass eine neue Frequenz gesetzt wurde
;
; Parameter    : X - Zeiger auf Frequenzwort
;
; Returns      : Nothing
;
; changed Regs : None
;
frq_update
                pshb
                psha
                ldd  2,x                      ; Frequenz holen
                std  ui_frequency+2
                ldd  0,x
                std  ui_frequency             ; Frequenz speichern
                swi                           ; Taskswitch durchf�hren
                pula
                pulb
                rts

;********************
; F R E Q   P R I N T
;********************
;
; UI - Task
;
; Gibt Frequenz auf Display aus
;
; Parameter    : X - Zeiger auf Frequenzwort
;
; Returns      : Nothing
;
; changed Regs : A, B, X
;
freq_print
                ldd  0,x              ; Frequenz Hi Word holen
                ldx  2,x              ; Frequenz Lo Word holen

                pshx                  ; Lo Word auf Stack
                pshb
                psha                  ; Hi Word auf Stack

                ldaa #'l'             ; unsigned Longint ausgeben
                ldab #3               ; die letzten 3 Stellen abscheiden
                jsr  putchar

                pulx
                pulx                  ; Frequenz von Stack l�schen

                rts
;
;********************************
; F R E Q   S E T   O F F S E T
;********************************
;
; UI - Task
;
; Gibt aktuelles Offset auf Display aus
;
; Parameter    : None
;
; Returns      : Nothing
;
; changed Regs : None
;


;
;***********************************
; F R E Q   O F F S E T   P R I N T
;***********************************
;
; UI - Task
;
; Gibt aktuelles Offset auf Display aus
;
; Parameter    : None
;
; Returns      : Nothing
;
; changed Regs : A, B, X
;
freq_offset_print
                clra                    ; Arrow = Off

                ldx  offset
                beq  fop_end            ; Offset = 0 -> Pfeil aus
                ldx  offset+2
                beq  fop_end            ; Offset = 0 -> Pfeil aus

                ldx  offset
                bmi  fop_negative       ; TX Shift negativ? -> Pfeil an
                                        ; TX Shift positiv? -> Pfeil blinkt
                ldaa #1
                bra  fop_end
fop_negative
                ldaa #2
fop_end
                ldab #6
                jsr  arrow_set
                rts

;
;**********************
; F R E Q   C H E C K
;**********************
;
; Control - Task
;
; Pr�ft auf �nderung der Frequenz und der TX Shift durch UI Task
; Setzt ggf. Frequenz und/oder Offset neu
;
; Parameter    : None
;
; Returns      : Nothing
;
; chanegd Regs : A, B, X
;
frq_check
                ldx  ui_frequency           ; Neue Frequenz eingegeben?
                beq  frc_chk_shift          ;  = 0? Dann hat sich nix ge�ndert
                ldx  #ui_frequency          ; Zeiger auf Frequenz holen
                jsr  set_freq               ; Frequenz setzen
                ldx  #0
                stx  ui_frequency           ; Frequenz Flag setzen
frc_chk_shift
                ldx  ui_txshift
                cpx  #-1
                beq  frc_end                ; neue Shift ?

                stx  offset
                ldx  ui_txshift+2
                stx  offset+2

                ldx  #-1
                stx  ui_txshift             ; Frequenz Flag setzen
frc_end
                rts

