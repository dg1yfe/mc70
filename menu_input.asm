;*******************************
; M   S T A R T   I N P U T
;
; Frequenzeingabe über ZIffernfeld starten
;
;
m_start_input
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
                clra
                jsr  lcd_clr          ; Display löschen
m_print
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
                ldaa #F_IN            ; Frequenzeingabe beginnt
  		        staa m_state
                addb #$30             ; aus Taste/Nummer ASCII Char erzeugen
                tba
                ldab cpos             ; Position holen
                ldx  #f_in_buf
                abx
                tab
                stab 0,x              ; Zeichen in Frequenzeingabe Puffer sichern
                ldaa #'c'
                jsr  putchar
                jmp  m_end            ; Zurück
;**********************************
; M   F   I N
;
; Frequenzeingabe, Eingabe entgegennehmen
;
m_f_in
                cmpb #KC_NON_NUMERIC       ; Zahl?
                bcc  m_non_numeric         ; Wenn nicht, dann entsprechende Funktionen ausführen
                ldaa cpos                  ; sonst nachsehen
                cmpa #08 		           ; ob noch Platz im Display
		        bne  m_print		       ; Wenn ja, Zeichen ausgeben und in Frequenzeingabepuffer speichern
                jmp  m_end

;**********************************
; M   N O N   N U M E R I C
;
; Nicht numerische Taste während Frequenzeingabe auswerten
;
m_non_numeric

                ldx  #mnn_tab              ; Basisadresse der Tabelle holen
                subb #10
                aslb                       ; Index berechnen
                abx
                ldx  0,x                   ; Funktionsadresse aus Tabelle lesen
                jmp  0,x                   ; Funktion aufrufen
mnn_tab
                .dw m_backspace            ; *  - Backspace
                .dw m_none                 ; D1
                .dw m_none                 ; D2
                .dw m_none                 ; D3
                .dw m_clr_displ            ; D4 - Clear
                .dw m_none                 ; D5
                .dw m_none                 ; D6
                .dw m_set_shift            ; D7
                .dw m_none                 ; D8
                .dw m_set_freq             ; #  - Enter
;
;**********************************
; M   B A C K S P A C E
;
; eingegebenes Zeichen löschen
;
m_backspace
                jsr  m_reset_timer
                jsr  lcd_backspace    ; zuletzt eingegebenes Zeichen auf dem Display
                ldab cpos
                ldx  #f_in_buf        ; und im Frequenzeingabepuffer löschen
                abx
                clr  0,x              ; String im Frequenzeingabe-Puffer terminieren
		        ldaa #F_IN            ; Mindestens 1 freier Platz im Display vorhanden, State anpassen
		        staa m_state
                jmp  m_end            ; Zurück

;**********************************
; M   C L R   D I S P L
;
; Display und Eingabe löschen
;
m_clr_displ
                jsr  m_reset_timer
                clra
                jsr  lcd_clr
                clr  f_in_buf              ; Erstes Zeichen im Eingabebuffer auf 0 (Buffer "leer")
                jmp  m_end
;*******************************
;
; M   S E T   F R E Q
;
; eingegebene Frequenz setzen
;
m_set_freq
                clra
                ldab cpos
                addd #f_in_buf
                xgdx
                clr  0,x              ; Eingabe mit 0 terminieren
m_set_freq_x
                pshx                  ; 32 Bit Platz schaffen auf Stack
                pshx                  ; für Ergebnis der Frequenzberechnung

                tsx                   ; Zeiger auf Zwischenspeicher (Stack) nach X
                ldd  #f_in_buf        ; Zeiger auf Eingabestring holen
                jsr  atoi    	      ; Frequenz berechnen

                tsx                   ; Zeiger auf Frequenz DWord nach X
                jsr  frq_update       ; Control Task mitteilen, dass neue Frequenz gesetzt wurde
                clra
                jsr  lcd_clr          ; LCD löschen
                ldab #IDLE
                stab m_state          ; nächster State ist wieder IDLE

                PRINTF(m_ok)          ; "OK" ausgeben - PLL ist eingerastet
                WAIT(200)             ; 200ms warten
m_frq_prnt
                clrb
                jsr  lcd_cpos         ; cursor auf pos 0 setzen

                ldx  #frequency       ; Adresse von Frequenz Word holen
                jsr  freq_print       ; Frequenz ausgeben
                jsr  freq_offset_print; Offset anzeigen
                jsr  lcd_fill         ; Display mit Leerzeichen füllen (schneller als löschen und dann schreiben)

                clr  m_timer_en       ; Menü Timer disabled - Aktuelles Display = neues Display
                pshb
                psha
                clr  pll_timer        ; PLL Timer auf 0
                pula
                pulb
msf_end
                pulx
                pulx                  ; eingegebene Frequenz vom Stack löschen
                jmp  m_end

;*******************************
;
; M   D I G I T   E D I T O R
;
; Editiert einen Bereich im Display
;
; Parameter: A - Niedrigstes/Erstes Digit  (Bit 0-3)
;                Höchstes/Letztes Digit (Bit 4-7)
;            B - Mode :  0 - Dezimal
;                        1 - Alphanumerisch
;                        2 - Alphabet
;
; Ergebnis : X - Zeiger auf 0-terminierten String (f_in_buffer)
;            A - Status :  0 - OK
;                          1 - Abbruch
;
; changed Regs : A,B,X
;
; required Stack Space : 7+Subroutines
;
; Stack depth on entry : 4
;
; 4 - first pos
; 3 - last pos
; 2 - lower limit
; 1 - upper limit
; 0 - current pos
#define MDE_FIRST_POS 4
#define MDE_LAST_POS  3
#define MDE_LOWER_LIM 2
#define MDE_UPPER_LIM 1
#define MDE_CUR_POS   0
;
m_digit_editor
                pshb

                tab
                lsrb
                lsrb
                lsrb
                lsrb
                pshb                       ; save last digit pos / front

                tsx
                ldab 1,x                   ; get mode back

                anda #$0f
                staa 1,x                   ; save first digit pos / back

                tstb                       ; test mode (decimal/alphanum/alphabet)
                beq  mde_numeric
                cmpb #1
                beq  mde_alphanum
                ldab #'a'
                pshb
                ldab #'z'
                pshb
                bra  mde_chkspace
mde_alphanum
                ldab #'0'
                pshb
                ldab #'z'
                pshb
                bra  mde_chkspace
mde_numeric
                ldab #'0'
                pshb
                ldab #'9'
                pshb
mde_chkspace
                tsx
                ldab MDE_FIRST_POS-1,x  ; get first pos
                pshb                    ; store as current position
;                andb #~CHR_BLINK       ; ignore blink bit
                ldaa #1
                jsr  lcd_chr_mode       ; let digit blink
mde_loop
                jsr  m_reset_timer      ; Eingabe Timeout zurücksetzen
mde_key_loop
                UI_UPD_LOOP             ; run UI update loop (transfer new keys to menu buffer, update LEDs, etc.)
                jsr  sci_rx_m           ; check for keypress

                ldx  m_timer            ; check m_timer
                beq  mde_exit

                tsta
                bmi  mde_key_loop

                ldaa cfg_head
                cmpa #3
                beq  mde_hd3sel

                cmpb #HD2_ENTER
                beq  mde_enter
                cmpb #HD2_EXIT
                beq  mde_exit
                bra  mde_sel
mde_hd3sel
                cmpb #HD3_ENTER
                beq  mde_enter
                cmpb #HD3_EXIT
                beq  mde_exit
mde_sel
                cmpb #KC_D1
                beq  mde_up
                cmpb #KC_D2
                beq  mde_down
                cmpb #KC_D6
                beq  mde_next
                cmpb #KC_D3
                beq  mde_next
                bra  mde_loop
;*************
mde_exit
                pulb                  ; get digit position
                clra
                jsr  lcd_chr_mode     ; let digit be solid
                ins
                ins
                ins
                ins                   ; clean stack
                ldaa #1
                rts
;*************
mde_up
                pulb
                pshb
                ldx  #dbuf            ; use as index for display buffer
                abx
                ldaa 0,x              ; get char at digit
                anda #~CHR_BLINK      ; ignore blink bit
                tsx
                cmpa MDE_UPPER_LIM,x  ; compare to upper limit
                bcc  mdu_wrap
                inca                  ; increment
                bra  mdu_store
mdu_wrap
                ldaa MDE_LOWER_LIM,x  ; set lower limit
mdu_store
                jsr  lcd_cpos         ; move cursor to digit position
                tab
                orab #$80             ; set blink bit
                ldaa #'c'
                jsr  putchar          ; print char
                jmp  mde_loop         ; wait for upcoming action
;*************
mde_down
                pulb
                pshb
                ldx  #dbuf                   ; use as index for display buffer
                abx
                ldaa 0,x                     ; get char at digit
                anda #~CHR_BLINK             ; ignore blink bit
                deca
                tsx
                cmpa MDE_LOWER_LIM,x         ; compare to upper limit
                bcs  mdd_wrap
                bra  mdu_store
mdd_wrap
                ldaa MDE_UPPER_LIM,x         ; set upper limit
                bra  mdu_store
;----------------
mde_next
                tsx
                pulb                         ; get current position
                clra
                jsr  lcd_chr_mode            ; set current char to solid
                cmpb MDE_LAST_POS,x          ; check if first pos reached
                beq  mdn_wrap                ; then wrap
                decb
                bra  mdn_cont
mdn_wrap
                ldab MDE_FIRST_POS,x         ; load first position
mdn_cont
                pshb                         ; write new position
                inca
                jsr  lcd_chr_mode            ; let digit blink
                jmp  mde_loop
;----------------
mde_enter
                pulb                         ; get current position
                clra
                jsr  lcd_chr_mode            ; set char to solid
                ins
                ins                          ; delete upper & lower limit from stack
                pulb                         ; sorce pointer - get last pos / highest digit
                clra                         ; dest. pointer
mee_loop
                ldx  #dbuf
                abx                          ; set X to string in dbuf
                pshb
                psha
                ldaa 0,x                     ; get first char from string
                ldx  #f_in_buf
                pulb
                abx
                staa 0,x                     ; save as first char in f_in buf
                incb                         ; increment dest. pointer
                inx
                clr  0,x                     ; set next byte to "Null"
                tba                          ; return dest pointer to A
                pulb                         ; get source pointer back
                tsx
                cmpb 0,x                     ; check if lowest digit is reached
                beq  mee_end                 ; if so - end here
                incb                         ; else increment source pointer
                bra  mee_loop                ; loop
mee_end
                ins                          ; delete first pos from stack
                clra                         ; return success
                ldx  #f_in_buf               ; return pointer to buffer
                rts                          ; return
