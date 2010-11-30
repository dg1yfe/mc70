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
;******************************
; L C D   S U B R O U T I N E N
;******************************
;
; lcd_h_reset   - Hardware Reset des LCD ( nix | nix )
; lcd_s_reset   - LCD Warmstart, Reset Kommando an LCD Controller senden ( nix | nix )
; lcd_backspace - Zeichen links vom Cursor löschen
; lcd_clr       - Löscht Inhalt des Displays und des Buffers
; save_dbuf     - Sichert Displaybuffer ( X - Zieladresse | nix )
; restore_dbuf  - Stellt Displaybuffer wiederher ( X - Quelladresse | nix )
;
;
;
;

;***********************
; L C D _ H _ R E S E T
;***********************
;
; Hardware Reset des LCD
; (Initialisierung / Software Reset zusätzlich nötig)
;
lcd_h_reset
                pshb
                psha

                ldaa  #-1
                ldab  #SR_LCDRESET
                jsr   send2shift_reg ; LCD Reset Leitung auf High (=Reset)
                WAIT(1)
                ldaa  #~SR_LCDRESET
                clrb
                jsr   send2shift_reg ; und wieder low

                pula
                pulb
                rts

;***********************
; L C D _ S _ R E S E T
;***********************
;
; LCD Warmstart - Reset Kommando an LCD Controller senden
;
; Returns: A - 0 = Display Reset
;              1 = Timeout / No Display detected
;
lcd_s_reset
               ldd  #0
               std  lcd_timer

               clrb
               jsr  sci_tx

               sei
               clr  io_inbuf_w
               clr  io_inbuf_r
               cli

               WAIT(80)

               ldd  tick_hms
               addd #20               ; 2 Sek Timeout
               xgdx
lcs_wait_res
			   pshx
               jsr  check_inbuf        ; get number of bytes in inbuf
               tsta
			   beq  lcs_wait_count     ; if zero, loop until time's up
               psha
               jsr  sci_read           ; read char from inbuf
               pula
               pulx
			   deca
			   beq  lcs_chk            ; if there was only one byte left, respond
               bra  lcs_wait_count     ; loop until time is up
lcs_chk
               cmpb #$7E               ; Reset Poll Char received?
               beq  lcs_disp_resp      ; Yes - then respond
lcs_wait_count
               cpx  tick_hms           ; check if time is up?
               bne  lcs_wait_res       ; if not, loop another time
               ldaa #1                 ; Display antwortet nicht innerhalb des Timeouts
               ldab #$7F
               jsr  sci_tx
               rts                     ; Annehmen, dass kein Display vorhanden ist (nur loopback)
lcs_disp_resp
               ldab #$7E               ; respond to reset message
               jsr  sci_tx             ; by sending it back

               WAIT(100)
               ldx  #LCDDELAY*4
               stx  lcd_timer
               ldaa #1
               jsr  lcd_clr            ; LEDs, LCD und Display Buffer löschen

               clra
               rts

;*******************
; L C D _ C L R
;*******************
;
; Löscht Inhalt des Displays und des Buffers
;
;
; Parameter    : A - 1 = LEDs löschen, 0 = nur Display
;
; Ergebnis     : none
;
; changed Regs : none
;
lcd_clr
               pshb
               psha
               pshx

               psha

               ldab #$78
               ldaa #'p'
               jsr  putchar

               clr  cpos              ; Reset CPOS (Cursor auf Pos. 0 setzen)

               ldx  #dbuf
               ldd  #$2020
               std  0,x
               std  2,x
               std  4,x
               std  6,x               ; clear Display Buffer (fill with "Space")
               clr  arrow_buf

               pula                   ; Wenn A<>0, LEDs auch löschen
               tsta
               beq  lcc_end
               clr  led_dbuf          ; LED Display Puffer löschen
               ldab #$7A              ; LED clear Kommando senden
               ldaa #'p'
               jsr  putchar
lcc_end
               pulx
               pula
               pulb
               rts


;***************************
; L C D _ B A C K S P A C E
;***************************
lcd_backspace
                pshb
                psha
                pshx

                clra
                ldab cpos           ; Cursorposition holen
;                beq  lcd_no_dec     ; Wenn Cursor auf Pos. 0, nichts mehr abziehen
                decb                ; Sonst Cursorposition -1
;                stab cpos           ; und wieder speichern
lcd_no_dec
                pshb
                jsr  lcd_cpos       ; Cursor auf Position setzen
                ldab #' '
                ldaa #'c'
                jsr  putchar        ; Zeichen löschen (mit Leerzeichen überschreiben)
                pulb
                jsr  lcd_cpos       ; Cursorposition erneut setzen

                pulx
                pula
                pulb
                rts



;*******************
; S A V E _ D B U F
;*******************
;
;
save_dbuf
                ldx  dbuf
                stx  dbuf2
                ldx  dbuf+2
                stx  dbuf2+2
                ldx  dbuf+4
                stx  dbuf2+4
                ldx  dbuf+6
                stx  dbuf2+6
                ldx  dbuf+7
                stx  dbuf2+7
                rts


;*************************
; R E S T O R E _ D B U F
;*************************
;
; Parameter    : none
;
; Ergebnis     : none
;
; changed Regs : A, B, X
;
restore_dbuf
                ldx  #dbuf2		; TODO: BUG???
                clrb
                jsr  lcd_cpos    ; Position 0
restore_loop
                ldab 0,x
                pshx
                ldaa #'c'
                jsr  putchar
                pulx
                inx              ; Adresse erhöhen
                ldab cpos
                cmpb #8
                bcs  restore_loop

                ldab 0,x         ; CPOS holen
                jsr  lcd_cpos
                rts

;*****************
; L C D   S E N D
;*****************
;
;  Parameter :
;
lcd_send
                pshb
lcs_retrans
                jsr  sci_tx_w    ; Ansonsten Echo
                jsr  sci_rx
                tsta
                bne  lcs_retrans

lcs_end
                pula
                pulb
                rts

;**********************************
; L C D   T I M E R   R E S E T
;**********************************
;
;  Parameter :
;
lcd_timer_reset
                pshx
                ldx  #LCDDELAY
                stx  lcd_timer
                pulx
                rts
;******************
; L C D   C P O S
;******************
;
;  Parameter : B - Cursorposition (0-7)
;
;  Ergebnis : none
;
;  changed Regs : none
;
lcd_cpos
                pshb
                psha
                pshx

                cmpb #8
                bcc  lcp_end           ; Cursorposition muß sich innerhalb von 0-7 befinden

                cmpb cpos
                beq  lcp_end           ; Wenn Cursor schon auf Position steht, nicht neu setzen

                stab cpos              ; neue Position speichern
                addb #$60              ; Befehl zusammensetzen
                ldaa #'p'
                jsr  putchar           ; und ans Display senden
lcp_end
                pulx                   ; das wars
                pula
                pulb
                rts

;******************
; L C D   F I L L
;******************
;
;  Fills LCD from current Cursorposition until end with Spaces
;  Positions containing Space are ignored to gain Speed with the
;  slow Hitachi Display
;  -> simulates LCD Clear which would be slower in cases with less than
;  4 characters to clear
;
;  Parameter : none
;
;  Ergebnis : none
;
;  changed Regs : none
;
lcd_fill
                pshb
                psha
                pshx
                ldab cpos
                pshb                   ; Cursorposition sichern
lcf_loop
                ldab #' '
                ldaa #'c'
                jsr  putchar           ; Space schreiben
                ldab cpos              ; Cursorposition holen
                cmpb #8
                bcs  lcf_loop          ; wiederholen solange Cursorposition <8 ist
lcf_end
                pulb
                jsr  lcd_cpos          ; Cursor auf alte Position setzen

                pulx                   ; das wars
                pula
                pulb
                rts
;****************
; L E D   S E T
;****************
;
; CONTROL TASK -> UI TASK
;
; Setzt Bits in LED Buffer entsprechend Parameter
; Der Buffer wird zyklisch im UI Task abgefragt und eine Änderung
; an das Display ausgegeben.
; Achtung: Durch die langsame Kommunikation mit dem Display kann es
;          vorkommen, dass schnelle Änderungen nicht oder unvollständig
;          dargestellt werden
;
;
; Parameter : B - LED + Status (RED_LED/YEL_LED/GRN_LED + OFF/ON/BLINK/INVERT)
;
;                 RED_LED $33 - 00110011
;                 YEL_LED $31 - 00110001
;                 GRN_LED $32 - 00110010
;                 OFF       0 - 00000000
;                 ON        4 - 00000100
;                 BLINK     8 - 00001000
;                 INVERT  128 - 10000000
;
;
; Returns : nothing
;
; changed Regs: A,B,X
;
led_set

                tba
                anda #%00110011                   ; LED Bits isolieren
                cmpa #RED_LED                     ; Rot?
                beq  lds_red
                cmpa #GRN_LED                     ; Grün?
                beq  lds_grn
lds_yel
                ldaa #1                           ; Gelb = 1 - 00000001
                bra  lds_cont
lds_grn
                ldaa #4                           ; Grün = 4 - 00000100
                bra  lds_cont
lds_red
                ldaa #16                          ; Rot = 16 - 00010000
lds_cont
                psha
                lsla
                psha                              ; 2 Status Bits auf Stack
                tsx                               ; Stackpointer nach X
                ldaa led_buf                      ; LED Buffer lesen

                tstb                              ; Status = Invert ?
                bmi  lds_invert                   ; Ja, dann verzweigen
                andb #%1100                       ; Status = Blink oder On ?
                beq  lds_off                      ; Ja, dann verzweigen
                andb #%1000                       ; Status = Blink?
                bne  lds_blink
                                                  ; Status = On
                com  0,x                          ; Maske erzeugen,
                anda 0,x                          ; BLINK Bit löschen
                oraa 1,x                          ; ON Bit setzen
                bra  lds_store
lds_off
                com  0,x                          ; Maske erzeugen
                com  1,x                          ; um beide Bits
                anda 0,x                          ; zu
                anda 1,x                          ; löschen
                bra  lds_store
lds_blink
                oraa 0,x                          ; Blink Bit setzen
                oraa 1,x                          ; ON Bit setzen
                bra  lds_store
lds_invert
                eora 1,x                          ; On Bit invertieren
lds_store
                ldab led_dbuf
                cba                               ; anzuzeigende LEDs und dargestellte gleich?
                beq  lds_end
                oraa #$80                         ; Nein? Dann changed Bit setzen
lds_end
                staa led_buf
                ins
                ins                               ; Stackspeicher freigeben
                rts

;**********************
; L E D   U P D A T E
;**********************
;
; Prüft LED Buffer auf Veränderung, steuert ggf. LEDs an
;
; Parameter : none
;
; Returns : nothing
;
;
led_update
                pshb
                psha
                pshx

                clra
                inc  tasksw_en              ; keinen erzwungenen Taskswitch durchführen
                ldab led_buf                ; LED Buffer lesen
                lslb                        ; MSB ins Carryflag schieben (Change Bit)
                rola                        ; Bit in A übernehmen
                lsrb                        ; B nach rechts schieben, MSB = 0 setzen
                stab led_buf                ; Puffer speichern
                dec  tasksw_en              ; Taskswitches per Interrupt wieder zulassen
                tsta
                beq  ldu_end                ; Change Bit nicht gesetzt -> Ende

                pshb                        ; Wert aus LED_BUF sichern
                eorb led_dbuf               ; Unterschied zu aktuellem Status durch XOR bestimmen
                ldaa #3
ldu_loop
                lsrb                        ; 'On' Bit ins Carryflag
                bcc  ldu_nochg              ; Bit nicht geändert, Blink Bit testen
                bsr  ldu_chg                ; Wenn es sich geändert hat, die Änderung ans Display senden
                bra  ldu_lsr                ; Änderung des Blink Bit muß nicht geprüft werden
ldu_nochg
                lsrb                        ; 'On' Bit hat sich nicht geändert, Blink Bit testen
                bcc  ldu_dec                ; Blink Bit hat sich auch nicht geändert, weiter mit nächster Farbe
                bsr  ldu_chg                ; Blink Bit hat sich geändert (Übergang ON -> Blink)
                bra  ldu_dec                ; Weitermachen mit nächster Farbe
ldu_lsr
                lsrb                        ; 'ON' Bit hat sich geändert, Blink Bit Änderung nicht beachten
ldu_dec
                deca                        ; Zu nächster Farbe
                bne  ldu_loop               ; 0=Exit

                pulb                        ; Wert vom LED Buffer holen
                andb #$7F                   ; Change Bit ausblenden
                stab led_dbuf               ; Neuen Status der Display LEDs speichern
ldu_end
                pulx
                pula
                pulb
                rts
;-------
ldu_chg
                pshb
                psha
                tab                         ; Zähler (Farbe) nach B

                tsx
                ldaa 4,x                    ; LED Buffer holen

                cmpb #3                     ; 3= gelbe LED
                beq  ldu_yel
                cmpb #2                     ; 2= grüne LED
                beq  ldu_grn
ldu_red
                ldab #RED_LED               ; Kommando für rote LED nach B
                anda #%110000               ; Status Bits für rote LED isolieren
                lsra
                lsra
                lsra
                lsra                        ; und nach rechts schieben
                bra  ldu_set
ldu_yel
                ldab #YEL_LED               ; Status Bits für gelbe LED isolieren
                anda #%11
                bra  ldu_set
ldu_grn
                ldab #GRN_LED               ; Status Bits für  LED isolieren
                anda #%1100
                lsra
                lsra
ldu_set
                lsra                        ; 'ON' Bit gesetzt?
                bcc  ldu_send               ; Nein? Dann LED deaktivieren
                orab #$04                   ; Andernfalls ON Bit setzen
                lsra                        ; Blink Bit gesetzt?
                bcc  ldu_send               ; Nein, dann LED nur einschalten
                andb #%11111011             ; ON Bit löschen
                orab #$08                   ; Blink Bit setzen
ldu_send
                ldaa #'p'
                jsr  putchar                ; LED Kommando senden

                pula
                pulb
                rts
;
;********************
; A R R O W   S E T
;********************
;
; Parameter : B - Nummer    (0-7)
;             A - Reset/Set/Blink
;                 0 = Reset,
;                 1 = Set
;                 2 = Blink
;                 3 = Invert (off->on->off, blink->off->blink, on->off->on)
;
; Returns : nothing
;
arrow_set
                pshx
                psha
                pshb

                jsr  raise                  ; Nummer in Bit Position konvertieren (2^B)
                pshb
                tsx

                cmpa #3                     ; Modus testen
                beq  aws_invert_chk
                cmpa #2
                beq  aws_blnk_chk
                cmpa #1
                beq  aws_on_chk
aws_off_chk
                ldaa arrow_buf
                tab
                anda 0,x                    ; ON Bit isolieren
                beq  aws_end                ; Arrow ist schon aus -> Ende
aws_off
                com  0,x                    ; Maske zum ausblenden erzeugen
                andb 0,x                    ; On Bit löschen
                stab arrow_buf              ; Status speichern
                ldab #A_OFF                 ; Kommando für 'aus' holen
                bra  aws_send
aws_on_chk
                ldaa arrow_buf
                tab
                anda 0,x                    ; Arrow schon aktiviert?
                beq  aws_on                 ; Nein -> aktivieren
                ldaa arrow_buf+1
                tab
                anda 0,x                    ; blinkt er?
                beq  aws_end                ; Nein, dann Ende
                com  0,x                    ; Ansonsten
                andb 0,x                    ; Blink Bit löschen
                stab arrow_buf+1            ; Status speichern
                ldab arrow_buf
                com  0,x
aws_on
                orab 0,x                    ; ON Bit setzen
                stab arrow_buf
                ldab arrow_buf+1
                com  0,x
                andb 0,x
                stab arrow_buf+1            ; Blink Bit löschen
                ldab #A_ON                  ; Kommando für an holen
                bra  aws_send
aws_blnk_chk
                ldaa arrow_buf+1
                tab
                anda 0,x                    ; Blink Bit isolieren
                beq  aws_blink              ; Wenn nicht gesetzt -> aktivieren
                ldaa arrow_buf
                tab
                anda 0,x                    ; aktiviert?
                bne  aws_end                ; Ja, dann Ende
                ldab arrow_buf+1            ; Blink Status holen
aws_blink
                orab 0,x                    ; Blink Bit setzen
                stab arrow_buf+1            ; Status speichern
                ldab arrow_buf
                orab 0,x                    ; On Bit setzen
                stab arrow_buf              ; Status speichern
                ldab #A_BLINK               ; Blink Kommando laden
                bra  aws_send
aws_invert_chk
                ldaa arrow_buf
                tab
                anda 0,x                    ; Arrow schon an?
                bne  aws_off                ; Ja -> deaktivieren
                ldaa arrow_buf+1
                tab
                anda 0,x                    ; blinken?
                bne  aws_blink              ; Ja, dann blinken
                ldab arrow_buf
                bra  aws_on                 ; Ansonsten normal einschalten
aws_send
                ldaa cpos
                psha
                pshb
                ldaa #'p'
                ldab 1,x
                jsr  lcd_cpos               ; Cursor setzen
                pulb
                addb #ARROW
                ldaa #'p'
                jsr  putchar                ; Arrow setzen
                pulb
                jsr  lcd_cpos
aws_end
                ins

                pulb
                pula
                pulx
                rts


