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
;
; Small Submenus
;
;
;
;
;
;*******************************
; M   P O W E R
;
; set high or low power via menu

; Power Umschaltung
;
; ---------
; ONLY EVA9
; ---------
;
#ifdef EVA9
;
m_power
mpws_power_cycle
                clra
                ldab pwr_mode
                andb #%00001000        ; 0 = hi power
                bne  mpw_tohi          ; Power Hi -> Power Lo
                bra  mpw_tolo
mpw_tohi
                inca
mpw_tolo
mpw_end
                ldab #3
                jsr  arrow_set
                eim  #%00001000,pwr_mode ; toggle tx power mode
                ldab m_state
                cmpb #POWER_SELECT
                beq  mps_print
                jmp  m_end
;***************
m_power_submenu
                ldaa #POWER_SELECT
                staa m_state
                jsr  m_reset_timer     ; Menü-Timer Reset (Timeout für Eingabe setzen)
mps_print
                clrb
                jsr  lcd_cpos
                PRINTF(m_power_str)
                ldaa pwr_mode
                anda #%00001000
                beq  mps_hi            ; Power Hi -> Power Lo
                PRINTF(m_power_lo_str)
                jmp  m_end
mps_hi
                PRINTF(m_power_hi_str)
mps_end
                jmp  m_end
;****************
m_power_select
                jsr  m_reset_timer     ; Menü-Timer Reset (Timeout für Eingabe setzen)
                ldaa cfg_head
                cmpa #3
                beq  mpws_hd3
                cmpa #2
                beq  mpws_hd2
mpws_hd2
                cmpb #HD2_ENTER
                beq  mpws_exit        ;
                cmpb #HD2_EXIT
                beq  mpws_exit        ;
                bra  mpws_common
mpws_hd3
                cmpb #HD3_ENTER
                beq  mpws_exit        ;
                cmpb #HD3_EXIT
                beq  mpws_exit        ;
mpws_common
                cmpb #HD2_UP
                beq  mpws_power_cycle   ;
                cmpb #HD2_DN
                beq  mpws_power_cycle   ;
                cmpb #KC_D4
                beq  mpws_power_cycle   ;
                jmp  m_end
mpws_exit
                jmp  m_end_restore
m_power_hi_str
                .db "HI",0
m_power_lo_str
                .db "LO",0
m_power_str
                .db "POWER ",0
#endif
;**************************************
;
;
m_defch_submenu
                jsr  m_reset_timer             ; Menü-Timer Reset (Timeout für Eingabe setzen)
                clrb
                jsr  lcd_cpos
                ldaa #DEFCH_SELECT             ; go to "default channel select" state
                staa m_state
                ldab cfg_defch_save
                andb #BIT_DEFCH_SAVE           ; Isolate Bit
                beq  mdcm_manual               ; Print current state (auto or manual)
                PRINTF(m_defch_str_auto)
                ldab #2                        ; start at index 2 (auto)
                bra  mdcm_end
mdcm_manual
                PRINTF(m_defch_str_man)
                ldab #1                        ; start at index 1 (manual)
mdcm_end
                stab m_svar1
                jsr  lcd_fill
                jmp  m_end

m_defch_str_store
                .db "STORE",0
m_defch_str_man
                .db "MANUAL",0
m_defch_str_auto
                .db "AUTO",0

mdcs_strtab
                .dw m_defch_str_store
                .dw m_defch_str_man
                .dw m_defch_str_auto
m_defch_select
                jsr  m_reset_timer     ; Menü-Timer Reset (Timeout für Eingabe setzen)
                ldaa cfg_head          ; different keys for different control heads
                cmpa #3
                beq  mdcs_hd3
                cmpa #2
                beq  mdcs_hd2
mdcs_hd2
                cmpb #HD2_ENTER
                beq  mdcs_enter       ;
                cmpb #HD2_EXIT
                beq  mdcs_exit        ;
                bra  mdcs_common
mdcs_hd3
                cmpb #HD3_ENTER
                beq  mdcs_enter       ;
                cmpb #HD3_EXIT
                beq  mdcs_exit        ;
mdcs_common
                cmpb #HD2_UP
                beq  mdcs_up          ;
                cmpb #HD2_DN
                beq  mdcs_dn          ;
                jmp  m_end
mdcs_exit
                jmp  m_end_restore     ; Cancel & exit Menu
mdcs_up
                ldab m_svar1           ; get current index
                incb                   ; advance by 1
                cmpb #3
                bne  mdcs_print        ; stay within 0-2
                clrb
mdcs_print
                stab m_svar1           ; store new index
                clrb
                jsr  lcd_cpos
                ldab m_svar1           ; print new state by using index
                lslb
                ldx  #mdcs_strtab
                abx
                ldx  0,x               ; get pointer to string from table
                jsr  printf            ; print string
                jsr  lcd_fill          ; clear rest of display
                jmp  m_end
mdcs_dn
                ldab m_svar1           ; get current index
                decb                   ; decrease by 1
                bpl  mdcs_print
                ldab #2                ; stay within 0-2
                bra  mdcs_print
;*********
mdcs_enter
                ldab m_svar1           ; get selected state
                beq  mdcs_store        ; decide what to do, if 0, then store current channel settings now
                decb                   ; if 1, set config to manual store
                bne  mdcs_auto_on      ; else set config to automatic store
mdcs_eep
                ldaa cfg_defch_save    ; get config byte
                anda #~BIT_DEFCH_SAVE  ; discard current state (in A)
                aba                    ; add new state (already in B)
                staa cfg_defch_save    ; store new state to RAM
                tab
                ldx  #$01fd            ; and also to EEPROM at address 0x1fd
                pshx
                jsr  eep_write
                pulx
                tsta                   ; check write status
                bne  mdcs_fail         ; if write failed, print Failed & errorcode
                clrb
                jsr  lcd_cpos
                ldx  #m_ok             ; print ok
                jsr  printf
                jsr  lcd_fill
                WAIT(200)
                jmp  m_end_restore     ; restore display content
;**************
mdcs_auto_on
                ldab #BIT_DEFCH_SAVE   ; enable auto store
                bra  mdcs_eep
;**************************************
; Store current frequency and shift to EEPROM as power-up default
;
mdcs_store
                jsr  store_current
                tsta                     ; Schreiben erfolgreich?
                bne  mdcs_fail

                clrb
                jsr  lcd_cpos            ; goto pos 0
                PRINTF(m_ok)             ; print 'OK'
                jsr  lcd_fill
                clrb
                jsr  lcd_cpos            ; goto pos 0
                PRINTF(m_stored)         ; print 'STORED'
                jsr  lcd_fill
                WAIT(1000)               ; 1sek warten
                jmp  m_end_restore
mdcs_fail
                psha                     ; Fehlerstatus sichern
                clra
                jsr  lcd_clr             ; Display löschen
                PRINTF(m_failed)         ; 'FAILED' ausgeben
                WAIT(500)                ; 500 ms warten
                pulb
                ldaa #'x'
                jsr  putchar             ; Fehlercode ausgeben
                WAIT(1000)               ; 1s warten
                jmp  m_end_restore

;**************************************
;
;
m_version_submenu
                jsr  m_reset_timer             ; Menü-Timer Reset (Timeout für Eingabe setzen)
                clrb
                jsr  lcd_cpos
                ldaa #M_VERSION             ;
                staa m_state
                PRINTF(ver_str)
                jsr  lcd_fill
                jmp  m_end
;**************************************
;
;
m_ctcss_tx_submenu
               ldab #CTCSS_SEL_TX
               stab m_state              ; set menu state to CTCSS SEL TX
               ldab #-1                  ; no key was pressed
               bra  m_ctcss_submenu      ; continue in menu to show current frequency

m_ctcss_rx_submenu                       ; TODO: Implement CTCSS decoder
               ldab #CTCSS_SEL_RX        ; set menu state to CTCSS SEL TX
               stab m_state
               ldab #-1                  ; no key was pressed

m_ctcss_submenu
               jsr  m_reset_timer
               clra
               tstb
               bmi  mcts_print
               cmpb #KC_D1             ; up
               beq  mcts_up
               cmpb #KC_D2             ; down
               beq  mcts_down
               cmpb #HD3_ENTER
               beq  mcts_enter
               cmpb #HD3_EXIT
               bne  mcts_end
               jmp  m_end_restore        ; exit menu & restore display state

mcts_up                                  ; index up
               ldab ctcss_index          ; get index
               cmpb #CTCSS_INDEX_MAX-1   ; stay within limits
               bcc  mcts_clr_index       ; eventually wrap around
               inc  ctcss_index          ; increase index
               bra  mcts_print
mcts_down                                ; index down
               ldab ctcss_index
               bne  mcts_dec_index       ; stay within limits
               ldab #CTCSS_INDEX_MAX     ; eventually wrap around
mcts_dec_index
               decb
               stab ctcss_index
               bra  mcts_print
mcts_clr_index
               clr ctcss_index
mcts_print
               clrb
               jsr  lcd_cpos           ; set cursor to pos 0
               ldab ctcss_index        ; get CTCSS index
               cmpb #CTCSS_INDEX_MAX   ; check if value is within limits
               bcs  mcts_show_freq
               clrb                    ; set to 0 if not
mcts_show_freq
               lslb                    ; double index because to address 2 Byte table entries
               ldx  #ctcss_tab         ; get pointer to CTCSS frequency table
               abx                     ; add index
               ldd  0,x                ; get tone entry
               bne  mcts_freq_nonzero
               PRINTF(m_off_str)       ; print "off"
               jsr  lcd_fill
               bra  mcts_end
mcts_freq_nonzero
               pshb
               psha
               ldx  #f_in_buf
               jsr  utoa               ; convert ctcss frequency to string
               pula
               pulb
               subd #1000              ; check if CTCSS frequency is < 100.0 Hz
               bcs  mcts_below100
               inx
mcts_below100
               ldab 2,x                ; insert decimal separator
               stab 3,x                ; between 2nd and 3rd digit for frequencies < 100 Hz
               ldab #'.'               ; or between 3rd and 4th for frequencies above
               stab 2,x
               clrb
               stab 4,x                ; terminate string
               ldx  #f_in_buf
               pshx
               ldx  #m_ctcss_hz_str
               jsr  printf             ; print frequency string (e.g. 123_0 Hz)
               pulx
               jsr  lcd_fill
mcts_end
               jmp  m_end
mcts_enter
               ldab m_state
               cmpb #CTCSS_SEL_TX
               bne  mcts_end           ; TODO: Implement CTCSS decoder for RX
               ldab ctcss_index        ; get CTCSS index
               beq  mcts_stop_tone     ; if index = 0, end CTCSS output
               lslb                    ; double index because to address 2 Byte table entries
               ldx  #ctcss_tab         ; get pointer to CTCSS frequency table
               abx                     ; add index
               ldd  0,x                ; get tone entry
               oim  #TX_CTCSS,tx_ctcss_flag ; set flag to activate ctcss on tx
               ldab rxtx_state         ; check current state
               beq  mcts_ok            ; if TRX is in rx, exit here
               jsr  tone_start_pl      ; else start output with selected frequency
mcts_ok
               clrb
               jsr  lcd_cpos
               PRINTF(m_ok)            ; print 'OK'
               jsr  lcd_fill
               WAIT(200)               ; wait 200ms
               jmp  m_end_restore
mcts_stop_tone
               aim  #~TX_CTCSS,tx_ctcss_flag ; delete flag to activate ctcss on tx
               jsr  tone_stop_pl       ; stop tone
               bra  mcts_ok
;**************************************
;
;
m_dtmf_submenu
                clra
                jsr  lcd_clr             ; clear display
                ldaa #DTMF_IN            ; set state DTMF input
  		        staa m_state
                jmp  m_end
m_dtmf_chartab
           .db '*', '0', '0', 'D', 'C', '0', '0', 'A','B','#'

m_dtmf_input
               cmpb #KC_D2
               beq  m_dtmf_enter
               cmpb #KC_D1
               bne  m_dtmf_cont
               jmp  m_end_restore
m_dtmf_cont
               cmpb #10
               bcs  m_dtmf_print
               subb #10
               ldx  #m_dtmf_chartab
               abx
               ldab 0,x
               subb #'0'
               bne  m_dtmf_print
               jmp  m_end
m_dtmf_print
               jmp  m_print

m_dtmf_enter
               ldaa tone_timer
               beq  mdts_start           ; check if tone is still on
               jsr  tone_stop_sig        ; if it is, stop it
               WAIT(40)                  ; wait 40 ms (DTMF minimum pause)
mdts_start
               ldaa cpos                 ; save length of input in A
               clrb
               jsr  lcd_cpos             ; set cursor to pos 0
mdts_loop
               cba                       ; check if we reached end of input
               beq  mdts_end
               pshb
               psha                      ; save index and end
               ldx  #f_in_buf
               abx
               ldab 0,x                  ; get DTMF char from buffer
               cmpb #'A'                 ; correct values for use in "dtmf_key2freq"
               bcc  mdts_sub54
               cmpb #'0'
               bcc  mdts_sub48
               cmpb #'*'
               beq  mdts_star
               ldab #$0f
               bra  mdts_output
mdts_star
               ldab #14+54
mdts_sub54
               subb #6
mdts_sub48
               subb #48
mdts_output
               jsr  dtmf_key2freq        ; calculate DTMF frequencies
               jsr  dtone_start          ; start DTMF tone output
               oim  #BIT_UI_PTT_REQ,ui_ptt_req     ; enable PTT
#IFDEF EVA5
               clrb
               jsr  dac_filter        ; deactivate additional DAC filter
#ENDIF
               ldab #' '
               ldaa #'c'
               jsr  putchar            ; mark char as sent by deleting it
               WAIT(100)               ; wait 100 ms
               jsr  tone_stop_sig      ; stop tone
               WAIT(50)                ; wait 50 ms
               pula
               pulb
               incb
               bra  mdts_loop
mdts_end
               aim  #~BIT_UI_PTT_REQ,ui_ptt_req     ; disable PTT
               jmp  m_end_restore
