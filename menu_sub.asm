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
