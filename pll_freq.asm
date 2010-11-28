;****************************************************************************
;
;    MC2_E9   v1.0   - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2009  Felix Erckenbrecht, DG1YFE
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
; pll_led           - Überprüft PLL Lock alle 500ms (nix | nix)
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
;                     ( D - Zeiger auf Eingabe (String), X - Zeiger auf Platz für Frequenz DWord)
; frq_sub_offset    - Zieht FBASE von Frequenz ab, nötig für Kanalberechnung
;                     ( X  - Pointer auf Frequenz DWord, D  - Pointer auf DWord für Frequenz - FBASE )
; frq_add_offset    - Zieht FBASe von Frequenz ab, nötig für Kanalberechnung
;                     ( X  - Pointer auf Frequenz DWord, D  - Pointer auf DWord für Frequenz - FBASE )
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
; Versucht zunächst Frequenzeinstellungen aus EEPROM zu laden,
; schlägt dies fehl wird aus dem ROM initialisiert, die gelbe LED blinkt dabei
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

                tsx                      ; Adresse nach X
                jsr  read_current        ; Frequenz, TXShift und Offset aus EEPROM lesen
                tsta                     ; Lesen erfolgreich?
                beq  ife_ok              ; Ja? Dann alles ok
ife_fail
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

                ldx  #FOFF76>>16		; TODO: MACRO einfŸhren
                stx  txshift
                ldx  #FOFF76%65536
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
                aim  #%11110111, Port6_Data ; PTT Syn Latch = 0

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
                bne  pli_error              ; Kanalraster zu groß (obere 16 Bit <>0)
                pshx
                pula
                pulb                        ; X -> D
                anda #%11000000             ; Referenz Teiler ist 14 Bit groß,
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
                clr  rxtx_state             ; State auf RX zurücksetzen
                clr  ptt_debounce           ; Debounce Counter zurücksetzen
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
; Überprüft PLL Lock wenn PLL Timer abgelaufen ist
; aktiviert rote LED, wenn PLL nicht eingerastet ist
;
; Parameter    : Keine
;
; Ergebnis     : Nichts
;
; changed Regs : A,B
;
pll_led
                ldab pll_timer
                bne  plc_end                 ; PLL check timer abgelaufen? nein, dann Ende
                ldab #PLLCHKTIMEOUT
                stab pll_timer

                ldab Port5_Data
                andb #%01000000
                tba
                eorb pll_locked_flag         ; Wenn sich nichts geändert hat (Bit6=0)
                beq  plc_end                 ; gleich zum Ende springen
                staa pll_locked_flag         ; sonst neuen Status speichern
                tsta
                bne  plc_locked
                ldab #RED_LED+ON             ; Rote LED an
                jsr  led_set
                bra  plc_end
plc_locked
                ldab #RED_LED+OFF
                jsr  led_set
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
;               $20 = PLL locked
;
; changed Regs: B
;
pll_lock_chk
                ldab Port5_Data
                andb #%00100000                  ; nur PTT Lock detect Bit lesen
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

                ldd  #PRESCALER             ; Vorteiler 127 für 70cm, 40 für 2m Version

                                            ; PLL Teiler für %128 Vorteiler berechnen
                jsr  divide32               ; 32 Bit Division, Dividend auf Stack, Divisor in D,
                                            ;                  Ergebnis auf Stack, Rest in X
                xgdx                        ; Teiler N = Quotient,
                                            ; Teiler A = Rest
                pulx                        ; Quotient HiWord vom Stack löschen
                pulx                        ; Quotient LoWord (Teiler für N holen)

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
pll_set_freq
                 jsr  frq_cv_freq_ch         ; Frequenz in Kanal mit Schrittweite f_step umrechnen
                                             ; Kanal kommt in X:D
                 jsr  pll_set_channel        ; PLL programmieren
 
                 rts

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

                tsx                         ; Ergebnis (RX VCO Frequenz) liegt auf Stack
                jsr  pll_set_freq           ; RX VCO Frequenz setzen

                pulx
                pulx                        ; RX VCO Frequenz vom Stack löschen

                jsr  frq_get_freq           ; eingestellte Frequenz (entsprechend Kanalraster) holen

                pshb
                psha
                pshx

                ldx  #RXZF>>16
                ldd  #RXZF%65536

                jsr  add32                  ; ZF addieren

                pulx
                stx  frequency
                pulx
                stx  frequency+2            ; und Empfangsfrequenz speichern

                rts                         ; Rücksprung

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
                tsx                         ; Ergebnis (TX VCO Frequenz) liegt auf Stack
                jsr  pll_set_freq           ; TX VCO Frequenz setzen

                pulx
                pulx                        ; TX VCO Frequenz vom Stack löschen

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
; Setzt die Frequenz auf die X zeigt, prüft vorher ob gesendet oder empfangen wird
;
; Parameter    : X - Zeiger auf Frequenz (32 Bit)
;
; Ergebnis     : Nichts
;
; changed Regs : none
;
;
set_freq
                pshb
                psha
                pshx
                ldab rxtx_state          ; senden oder empfangen wir gerade?
                bne  sfq_tx              ; entsprechend status die Frequenz setzen
                jsr  set_rx_freq
                bra  sfq_end
sfq_tx
                jsr  set_tx_freq
sfq_end
                pulx
                pula
                pulb
                rts

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
                adca                             ; eventuellen Übertrag berücksichtigen
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
                ins  ; Kanal vom Stack löschen
                rts

;***************************
; F R Q   C A L C   F R E Q
;***************************
;
; Umrechnung Eingabe -> Frequenz (long)
;
; Parameter    : D  - Adresse vom Eingabe-Buffer (Eingabe = Nullterminierter String)
;                X  - Adresse für Ergebnis (Frequenz, DWord)
;
; Ergebnis     : *X - 32Bit Frequenzwert
;
; changed Regs : A, B , X
;
;
frq_calc_freq
                pshx                       ; Adresse für Frequenz auf Stack sichern
                pshb
                psha                       ; Adresse vom Eingabepuffer auf Stack

                ldd  #0
                std  0,x
                std  2,x                   ; Frequenz = 0

                pulx                       ; Adresse vom String wiederholen
                clra                       ; Zähler auf 0
fcf_loop
                ldab 0,x
                beq  fcf_end               ; Schon das Stringende erreicht?
                pshx                       ; save bufferaddress (index)
                psha                       ; save counter
                subb #$30                  ; get number from ascii code

                pshb                       ; store on stack
                clrb
                pshb
                pshb
                pshb                       ; Faktor 1 auf Stack - Ziffer von Eingabe

                tab
                lslb
                lslb                       ; calc Index for 4 Byte entries

                clra
                addd #exp10                ; add base address
                xgdx
                ldd  2,x
                ldx  0,x                   ; Faktor 2 nach D:X
                jsr  multiply32            ; Multiplizieren
                ins
                ins
                ins
                ins                        ; Faktor 1 vom Stack löschen

                pshx                       ; Highword vom Ergebnis sichern
                tsx
                ldx  5,x                   ; Zieladresse vom Stack holen

                addd 2,x                   ; add new digit to frequency
                std  2,x

                pula
                pulb                       ; Highword vom Stack holen

                adcb 1,x
                stab 1,x
                adca 0,x
                staa 0,x                   ; store new frequency

                pula                       ; Zähler wiederholen
                pulx                       ; String Adresse wiederholen
                inx                        ; Adresse ++
                inca                       ; Zähler --
                cmpa #8                    ; Zähler <8 (maximale Eingabelänge)
                bcs  fcf_loop              ; dann loop
fcf_end
                pulx                       ; sonst: Zieladresse vom Stack löschen und
                rts                        ; Rücksprung


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
                swi                           ; Taskswitch durchführen
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
                pulx                  ; Frequenz von Stack löschen

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
; Prüft auf Änderung der Frequenz und der TX Shift durch UI Task
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
                beq  frc_chk_shift          ;  = 0? Dann hat sich nix geändert
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

