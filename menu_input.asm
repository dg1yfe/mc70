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
                ldaa #F_IN            ; Frequenzeingabe beginnt
  		        staa m_state
m_print
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
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
                cmpb #KC_NON_NUMERIC       ; input was non-numeric digit?
                bcc  m_non_numeric         ; then do something about it
                ldaa cpos                  ; otherwise check
                cmpa #08 		   ; for space in the display
                bne  m_print		   ; if there is space, print digit
                jmp  m_end                 ; and that's all for now

;**********************************
; M   N O N   N U M E R I C
;
; Nicht numerische Taste während Frequenzeingabe auswerten
;
m_non_numeric

                ldx  #mnn_tab              ; Table base address
                subb #10
                aslb                       ; calculate index for words
                abx
                ldx  0,x                   ; get function pointer from table
                jmp  0,x                   ; call function
mnn_tab
                .dw m_backspace            ; *  - Backspace
                .dw m_none                 ; D1
                .dw m_none                 ; D2
                .dw m_none                 ; D3
                .dw m_end_restore          ; D4 - Clear
                .dw m_none                 ; D5
                .dw m_none                 ; D6
                .dw m_set_shift            ; D7 - set tx shift
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
; parse input in order to set a new frequency
;
m_set_freq
                clra
                ldab cpos             ; get cursor position
                addd #f_in_buf        ; add input buffer base address
                xgdx                  ; transfer to X
                clr  0,x              ; terminate input string with 0
m_set_freq_x
                pshx                  ; make room on stack for 32 Bit value
                pshx                  ; we're going to store the new frequecy here

                tsx                   ; get a pointer to this temporary space
                ldd  #f_in_buf        ; get pointer to string
                jsr  atol_new         ; perform string to long conversion

                ldx  #f_in_buf
                jsr  strlen           ; calc strlen
                tstb                  ; check input length
                bne  msf_mul          ; continue if > 0
                pulx
                pulx                  ; else abort
                jmp  m_end_restore
msf_mul
                clr  m_timer
                clra
                lslb
                lslb                  ; *4 to index 32 bit values
                addd #exp10_9         ; add index from pointer to "10^9"
                                      ; D points to constant: 10^(9-strlen())
                tsx                   ; get pointer to frequency word
                jsr  multiply32p      ; Multiply to obtain value between below 999999000
                ldd  #const_500M      ; compare frequency with 500 MHz
                jsr  cmp32p
                bcs  msf_below_500M   ; if it is below 500 MHz -> use it
                                      ; if it is above 500 MHz, treat it as value between 50 and 99 MHz
                                      ; this enables convenient 5-digit frequency input for 4 m radios
                ldd  #10              ; divide frequency (which is still on top of the stack) by 10
                jsr  divide32
msf_below_500M
                tsx                   ; put pointer to frequency in X
                jsr  frq_update       ; signal presence of new frequency to control task

msf_check_lock
                ldab #PLLLOCKTIMEOUT
                stab ui_timer         ; wait max. 30 ms for unlock and lock combined
                ldx  #LOCKPORT
                ldaa #LOCKBIT
                clrb
                jsr  wait_flag_uit    ; wait for pll to change to unlocked state using timeout

                tab
                jsr  wait_flag_uit    ; wait for transition to locked state (using timeout)

                clrb
                jsr  lcd_cpos
                oim  #BIT_PLL_UPDATE_NOW,pll_update_flag   ; request state update NOW
                swi                   ; switch to control task for update

                clra
                jsr  lcd_clr          ; clear LCD
                ldab pll_locked_flag
                andb #BIT_PLL_STATE   ; check PLL state
                bne  msf_locked
                PRINTF(m_no_lock_str) ; print "NO LOCK"
                WAIT(200)             ; wait for (additional) 200ms
                bra  msf_wait
msf_locked
                PRINTF(m_ok)          ; print "OK"
msf_wait
                WAIT(200)             ; wait for 200ms
m_frq_prnt
                clrb
                jsr  lcd_cpos         ; set cursor to pos 0

                ldx  #frequency       ; get currently set frequency (might have been rounded)
                jsr  freq_print       ; print it
                jsr  lcd_fill         ; fill remaining chars with spaces
                jsr  freq_offset_print; show indicator for TX shift

                ldab #IDLE
                stab m_state          ; continue in IDLE
                aim  #~(BIT_MTIMER_EN),m_timer_en ; clear menu timer, old display content is invalid, do not restore
msf_end
                pulx
                pulx                  ; remove frequency word from stack
                jmp  m_end

const_500M
                .dw  (500000000>>16)
                .dw  (500000000%65536)
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
