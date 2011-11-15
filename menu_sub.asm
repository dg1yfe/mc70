;****************************************************************************
;
;    MC70 - Firmware for the Motorola MC micro trunking radio
;           to use it as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2011  Felix Erckenbrecht, DG1YFE
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
                ldab pwr_mode
                andb #%00001000
                beq  mpw_lo            ; Power Hi -> Power Lo
mpw_hi
                aim  #%11110111,pwr_mode
                ldaa #1
                ldab #3
                jsr  arrow_set
                bra  mpw_end
mpw_lo                                 ; Power Lo setzen
                oim  #%00001000,pwr_mode
                ldaa #0
                ldab #3
                jsr  arrow_set
mpw_end
                jmp  m_end
;***************
m_power_submenu
                clrb
                jsr  lcd_cpos
                ldaa #POWER_SELECT
                staa m_state

                ldab pwr_mode
                andb #%00001000
                beq  mps_hi            ; Power Hi -> Power Lo
                PRINTF(m_power_lo_str)
                bra  mps_end
mps_hi
                PRINTF(m_power_hi_str)
                PRINTF(m_power_str)
mps_end
                jmp  m_end
m_power_str_hi
                .db "HI",0
m_power_str_lo
                .db "LO"
m_power_str
                .db " POWER",0
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
                beq  mpws_pwr_cycle   ;
                cmpb #HD2_DN
                beq  mpws_pwr_cycle   ;
                cmpb #KC_D4
                beq  mpws_pwr_cycle   ;
                jmp  m_end
mpws_exit
                jmp  m_end_restore
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
                stab m_svar2
                andb #2                        ; Isolate Bit 1
                beq  mdcm_manual               ; Print current state (auto or manual)
                PRINTF(m_defch_str_auto)
                ldab #1                        ; start at index 1 (auto)
                bra  mdcm_end
mdcm_manual
                PRINTF(m_defch_str_man)
                ldab #2                        ; start at index 2 (manual)
mdcm_end
                stab m_svar1
                jsr  lcd_fill
                jmp  m_end

m_defch_str_store
                .db "STORE",0
m_defch_str_auto
                .db "AUTO",0
m_defch_str_man
                .db "MANUAL",0

mdcs_strtab
                .dw m_defch_str_store
                .dw m_defch_str_auto
                .dw m_defch_str_man
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
                decb                   ; if 1, set config to auto store
                beq  mdcs_auto_on
mdcs_auto_off
                clrb                   ; else set config to manual store
                stab m_svar2
mdcs_eep
                ldaa cfg_defch_save    ; get config byte
                anda #%11111101        ; discard current state (in A)
                andb #%00000010        ; isolate new state (in B)
                aba                    ; add new state
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
                WAIT(300)
                jmp  m_end_restore     ; restore display content
;**************
mdcs_auto_on
                ldab #2                ; enable auto store
                stab m_svar2
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
