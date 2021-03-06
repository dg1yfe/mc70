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
;
#DEFINE DIGIT_POS  m_svar1
#DEFINE DIGIT_MODE m_svar2
;
#DEFINE DM_FREQ  0
#DEFINE DM_SHIFT 1
;
;
#ifdef EVA5
#DEFINE M_MENU_ENTRIES 6
#endif
#ifdef EVA9
#DEFINE M_MENU_ENTRIES 7
#endif

m_menu_str	
        .db "MENU    ",0
		.dw m_recall_submenu

		.db "RECALL  ",0
		.dw m_recall_submenu

		.db "STORE   ",0
		.dw m_store_submenu

		.db "TX CTCSS",0
		.dw m_ctcss_tx_submenu

		.db "DTMF    ",0
		.dw m_dtmf_submenu

#ifdef EVA9
		.db "POWER   ",0
		.dw m_power_submenu
#endif
		.db "VERSION ",0
		.dw m_version_submenu

		.db "DEF CH  ",0
        .dw m_defch_submenu
;		.dw m_frq_store

                .db 0
;*****************************
; M E N U   I D L E
;*****************************
;
; Menu / IDLE Subroutines
;
; Main Menu / Top Level
;
; Parameter : none
;
; Ergebnis : none
;
; changed Regs : A,B,X
;
;
;************************
; Stack depth on entry: 1
;
;*******************************
; M   T O P
;
m_top
                aslb                  ; Index f�r Tabelle erzeugen
                ldaa cfg_head
                cmpa #3
                beq  mto_h3
                cmpa #2
                beq  mto_h2
                ldx  #m_top_h3        ; default TODO: include HD2b, HD Mic
                bra  mto_tabjmp
mto_h2
                ldx  #m_top_h2
                bra  mto_tabjmp
mto_h3
                ldaa rxtx_state
                beq  mto_h3_rx
                ldx  #m_top_h3_tx
                bra  mto_tabjmp
mto_h3_rx
                ldx  #m_top_h3        ; Basisadresse holen
mto_tabjmp
                abx                   ; Index addieren
                ldx  0,x              ; Tabelleneintrag holen
                lsrb                  ; undo left-shift
                jmp  0,x              ; Funktion aufrufen

; Control Head 3
;     ---------------------------  1   2   3
;     !                         !
; D1  !                         !  4   5   6
;     !                         !
; D2  !                         !  7   8   9
;     ---------------------------
;     D3  (D4)  D5  (D6)  D7  (D8) *   0   #
;
m_top_h3_tx
m_top_tab_tx
;               Funktion                Taste
                .dw m_dtmf_direct     ; 0
                .dw m_dtmf_direct     ; 1
                .dw m_dtmf_direct     ; 2
                .dw m_dtmf_direct     ; 3
                .dw m_dtmf_direct     ; 4
                .dw m_dtmf_direct     ; 5
                .dw m_dtmf_direct     ; 6
                .dw m_dtmf_direct     ; 7
                .dw m_dtmf_direct     ; 8
                .dw m_dtmf_direct     ; 9
                .dw m_dtmf_direct     ; *
                .dw m_frq_up          ; D1 - Kanal+
                .dw m_frq_down        ; D2 - Kanal-
                .dw m_dtmf_direct     ; D3 - Squelch ein/aus
                .dw m_dtmf_direct     ; D4 - Test
                .dw m_tone            ; D5 - 1750 Hz Ton
                .dw m_none            ; D6 -
                .dw m_dtmf_direct     ; D7 - TX Shift �ndern
                .dw m_dtmf_direct     ; D8 - Recall vfo frequency from memory
                .dw m_dtmf_direct     ; #
m_top_h3
m_top_tab
;               Funktion                Taste
                .dw m_start_input     ; 0
                .dw m_start_input     ; 1
                .dw m_start_input     ; 2
                .dw m_start_input     ; 3
                .dw m_start_input     ; 4
                .dw m_start_input     ; 5
                .dw m_start_input     ; 6
                .dw m_start_input     ; 7
                .dw m_start_input     ; 8
                .dw m_start_input     ; 9
                .dw m_none            ; *
                .dw m_frq_up          ; D1 - Kanal+
                .dw m_frq_down        ; D2 - Kanal-
                .dw m_sql_switch      ; D3 - Squelch ein/aus
#ifdef EVA5
                .dw m_none
#endif
#ifdef EVA9
                .dw m_power           ; D4 - TX Power Toggle
#endif
;                .dw m_test            ; D4 - Test
;                .dw m_prnt_tc         ; D4 - Taskswitches/s anzeigen
                .dw m_tone            ; D5 - 1750 Hz Ton
                .dw m_none            ; D6 -
                .dw m_txshift         ; D7 - TX Shift �ndern
                .dw m_recall          ; D8 - Recall vfo frequency from memory
                .dw m_menu            ; #
;                .dw m_sel_mbank       ; #
; Control Head 2
;     ---------------------------
;     !                         !
; D1  !                         !    5
;     !                         !
; D2  !                         !    8
;     ---------------------------
;     D3   D4   D5   D6   D7   D8
;
m_top_h2
;               Funktion                Taste
                .dw m_prnt_tc         ; - (0)
                .dw m_test2           ; - (1)
                .dw m_test            ; - (2)
                .dw m_test            ; - (3)
                .dw m_test            ; - (4)
                .dw m_test            ; upper / right side (5)
                .dw m_test            ; - (6)
                .dw m_test            ; - (7)
                .dw m_menu            ; lower / right side (8)
                .dw m_test            ; - (9)
                .dw m_tone_stop       ; - (*)
                .dw m_frq_up          ; D1 - Kanal+
                .dw m_frq_down        ; D2 - Kanal-
                .dw m_sql_switch      ; D3 - Squelch ein/aus
#ifdef EVA5
                .dw m_none
#endif
#ifdef EVA9
                .dw m_power           ; D4 - TX Power Toggle
#endif
;                .dw m_test            ; D4 - Taskswitches/s anzeigen
                .dw m_test3           ; D5 - 1750 Hz Ton
                .dw m_digit           ; D6 - Select Digit
                .dw m_txshift         ; D7 - TX Shift �ndern
                .dw m_recall          ; D8 - Recall vfo frequency from memory
                .dw m_none            ; -

;*******************************
; M   F R Q   U P
;
; Frequenz einen Kanal nach oben
;
m_frq_up
                ldx  frequency+2
                pshx
                ldx  frequency
                pshx
                ldx  #0
                ldd  #FSTEP
                jsr  add32
                tsx
                jsr  frq_update
                jmp  m_frq_prnt

mfu_end
                jmp  m_end
;*******************************
; M   F R Q   D O W N
;
; Frequenz einen Kanal nach unten
;
m_frq_down
                ldx  frequency+2
                pshx
                ldx  frequency
                pshx
                ldd  #FSTEP
                ldx  #0
                jsr  sub32
                tsx
                jsr  frq_update
                jmp  m_frq_prnt
mfd_end
                jmp  m_end
;*******************************
; M   S Q L   S W I T C H
;
; Squelchumschaltung Carrier/RSSI/Aus
;
; Carrierlevel wird am Demod IC eingestellt,
; RSSI-Level auf der RSSI Platine
; Carriersquelch l�sst niedrigere Schwelle zu als RSSI Squelch
;
m_sql_switch
                ldab sql_mode
#ifdef EVA5
                tba
                anda #SQM_RSSI
                bne  mss_none          ; RSSI -> none
                andb #SQM_CARRIER
                bne  mss_rssi          ; carrier -> RSSI
mss_carrier                            ; Carrier Squelch Pin auswerten
                andb #~SQM_BOTH
                orab #SQM_CARRIER
                stab sql_mode
                ldaa #1
                ldab #2
                jsr  arrow_set
                bra  mss_end
mss_rssi                               ; RSSI Pin auswerten
                andb #~SQM_BOTH
                orab #SQM_RSSI
                stab sql_mode
                ldaa #2
                ldab #2
                jsr  arrow_set
                bra  mss_end
mss_none                               ; Raussperre deaktivieren
                andb #~SQM_BOTH
                stab sql_mode
                ldaa #0
                ldab #2
                jsr  arrow_set
#endif
#ifdef EVA9
                andb #SQBIT
                bne  mss_none          ; RSSI -> none
mss_carrier                            ; Carrier Squelch Pin auswerten
                ldaa #1
                ldab #2
                jsr  arrow_set
                bra  mss_end
mss_none                               ; Raussperre deaktivieren
                ldaa #0
                ldab #2
                jsr  arrow_set
#endif
mss_end
#ifdef EVA9
                eim  #SQBIT, sql_mode
#endif
                jmp  m_end

;**************************************
; M   T O N E
;
; 1750 Hz Ton ausgeben
;
m_tone

                oim  #1,ui_ptt_req     ; PTT dr�cken
                ldab tone_timer
                bne  mtn_reset_timer
                ldd  #1750
                jsr  tone_start_sig
mtn_reset_timer
                ldab #6
                stab tone_timer        ; 0,6 sek Ton ausgeben

                jmp  m_end

;**************************************
; M   T X   S H I F T
;
; Anzeige der aktuellen TX Shift
;
m_txshift
                ldaa m_timer_en       ; Falls TX Shift noch angezeigt wird, Displayinhalt NICHT speichern
                bmi  mts_nosave       ;

                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
mts_nosave
                ldaa m_state
                cmpa #TXSHIFT_SW      ; Wurde Taste zum ersten Mal gedr�ckt?
                beq  mts_switch       ; Nein, dann n�chste Shift ausw�hlen
                                      ; Andernfalls aktuelle Shift ausgeben
                ldab #TXSHIFT_SW
                stab m_state

                jsr  m_reset_timer    ; Men�-Timer Reset (Timeout f�r Eingabe setzen)

                clrb
                jsr  lcd_cpos
                PRINTF(m_offset)
                jsr  lcd_fill
                WAIT(100)
                ldx  offset+2
                pshx
                ldx  offset
                pshx
mts_print
                clrb
                jsr  lcd_cpos
                tsx
                ldaa 0,x
                oraa 1,x
                oraa 2,x
                oraa 3,x
                beq  mts_disabled        ; zero shift means, shift is disabled

                jsr  sig_inv32s         ; invert longint
                                        ; (for historical reasons, inverted shift is saved & used)
                ldaa #$45               ; print sign, maximum 5 digits
                ldab #3                 ; truncate 3 digits at the end
                jsr  decout
mts_print_end
                pulx
                pulx
                jsr  lcd_fill
                jsr  freq_offset_print
                jmp  m_end
mts_disabled
                PRINTF(m_off_str)
                bra  mts_print_end
;*********************
; M T S   S W I T C H
;
; Aktivieren/Deaktivieren der Ablage, Vorzeichenwahl (+/-)
;
;
mts_switch
                jsr  m_reset_timer    ; Men�-Timer Reset (Timeout f�r Eingabe setzen)
                ldaa cfg_head
                cmpa #3
                beq  mts_hd3
                cmpa #2
                beq  mts_hd2
                bra  mts_hd3
mts_hd1
;******* HD 2
mts_hd2
                cmpb #5
                beq  mts_chg_sign
                cmpb #KC_D7           ; 'A'?
                beq  mts_toggle
                cmpb #KC_D6           ; Digit Editor
                beq  mts_jdigit
                cmpb #8
                bne  mts_to_idle      ; Bei allen anderen Tasten zu IDLE zur�ckkehren
                ldx  #0
                stx  m_timer
                jmp  m_end
mts_jdigit
                jmp  mts_digit
;******* HD 3
mts_hd3
                cmpb #KC_STERN
                beq  mts_chg_sign
                cmpb #KC_D7           ; 'A'?
                beq  mts_toggle
                cmpb #KC_RAUTE
                bne  mts_to_idle      ; Bei allen anderen Tasten zu IDLE zur�ckkehren
                ldx  #0
                stx  m_timer
                jmp  m_end
;******* COMMON
mts_to_idle
                pshb
                jsr  restore_dbuf     ; Displayinhalt wiederherstellen
                pulb
                jmp  m_top            ; Mit Frequenzeingabe weitermachen
mts_toggle
                jsr  m_reset_timer    ; Men�-Timer Reset (Timeout f�r Eingabe setzen)
                ldx  offset
                bne  mts_to_zero
                ldx  offset+2
                bne  mts_to_zero
                ldx  txshift+2
                stx  ui_txshift+2
                pshx
                ldx  txshift
                stx  ui_txshift
                pshx
                swi
                jmp  mts_print
mts_to_zero
                ldx  #0
                stx  ui_txshift+2
                stx  ui_txshift
                swi
                pshx
                pshx
                jmp  mts_print
mts_chg_sign
                ldx  #offset
                jsr  sig_inv32s       ; Vorzeichen umkehren
                ldd  offset+2
                std  txshift+2
                std  ui_txshift+2
                pshb
                psha
                ldd  offset
                std  txshift
                std  ui_txshift
                pshb
                psha                  ; Offset auf Stack speichern
                swi
                jmp  mts_print
mts_end
                jmp  m_end

;*******************
; M T S   D I G I T
;
; TX Shift per Digit Eingabe setzen
;
; Stack depth on entry: 1
;
mts_digit
                ldaa #(1<<4)+2        ; digits 1 & 2 editable
                clrb                  ; decimal mode
                jsr  m_digit_editor   ; call digit editor
                tsta                  ; test for Abort condition
                bne  mts_abort
                bra  msh_set_str      ; set shift
mts_abort
                clr  m_timer+1
                clr  m_timer
                jmp  m_end
;**************************************
; M   S E T   S H I F T
;
; TX Shift per Direkteingabe setzen
;
m_set_shift
                ldab cpos
                inc
                ldx  #f_in_buf
                abx
                clr  0,x              ; terminate input string
msh_set_str
                pshx                  ; 32 Bit temporary storage
                pshx                  ; for tx shift frequency calculation
                tsx                   ; pointer to temp. storagt to X
                ldd  #f_in_buf        ; get pointer to input string
                jsr  atol_new         ; calculate numeric value from string
                ldx  #f_in_buf
                jsr  strlen           ; calc strlen
                cmpb #3               ; check if 3 digits were entered
                beq  msh_khz          ; in this case take input as 3-digit kHz value (e.g. 600 as 600 kHz)
                clra
                cmpb #5
                bne  msh_to_khz       ; inputs of 5 digits are also kHz
                ldab #4               ; ensure 5 digit entry is interpreted as 10000 kHz and not 1000.0 kHz
msh_to_khz
                lslb
                lslb                  ; *4 to index 32 bit table values
                addd #exp10_7         ; add index from pointer to "10^7" -> 4 digits should be kHz value
                bra  msh_mult         ; transform all other inputs without leading zeros to 4-digit values
msh_khz
                ldd  #exp10_3         ; multiply by 10^3 -> 3 digits should be 100-999 kHz
msh_mult
                tsx                   ; get pointer to frequency word
                jsr  multiply32p      ; Multiply to obtain value in MHz
                ldd  0,x
                std  txshift
                std  ui_txshift
                ldd  2,x
                std  txshift+2
                std  ui_txshift+2
                swi
                ldab #IDLE
                stab m_state
                ldd  #8
                std  m_timer          ; wait 800 ms before reverting to RX frequency
                jmp  mts_print

;**************************************
; M   P R N T   R C
;
; Anzahl der Hauptschleifendurchl�ufe in der letzten Sekunde anzeigen
;
m_prnt_rc
                ldab m_timer_en       ; Falls Roundcount noch angezeigt wird, Displayinhalt NICHT speichern
                bmi  mpr_nosave       ; Sondern Zahl erneut ausgeben

                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
mpr_nosave
                jsr  m_reset_timer    ; Men�-Timer Reset (Timeout f�r Eingabe setzen)
                clrb
                jsr  lcd_cpos         ; Cursor Home
;                ldx  rc_last_sec      ; Rundenz�hler holen

                clrb
                pshx
                pshb
                pshb
                ldaa #'l'
                jsr  putchar
                pulx
                pulx

                jsr  lcd_fill         ; restliches Display mit Leerzeichen f�llen
                jmp  m_end
;**************************************
; M   T E S T
;
;
m_test
               ldd  #800
               jsr  atone_start
               WAIT(40)
               jsr  atone_stop

               jmp  m_end

m_test3
;                ldx  #5500*4
                ldab Port6_DDR_buf
                orab #$10
                stab Port6_DDR_buf
                stab Port6_DDR
                ldab Port6_Data
                eorb #$10
                stab Port6_Data
;                ldab #'1'
;                jsr  dtmf_key2freq
;                jsr  dtone_start

                jmp  m_end

m_tone_stop
                jsr  tone_stop_sig
                jmp  m_end

m_test2
                jmp  m_end

;**************************************
; M   P R N T   T C
;
; Anzahl der Taskswitches in der letzten Sekunde anzeigen
;
m_prnt_tc
                ldab m_timer_en       ; Falls Roundcount noch angezeigt wird, Displayinhalt NICHT speichern
                bmi  mtc_nosave       ; Sondern Zahl erneut ausgeben

                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
mtc_nosave
                jsr  m_reset_timer    ; Men�-Timer Reset (Timeout f�r Eingabe setzen)
                clrb
                jsr  lcd_cpos         ; Cursor Home
                clra
                ldab sql_timer        ; Rundenz�hler holen
                pshb
                psha
                psha
                psha
                ldaa #'l'
                clrb
                jsr  putchar
                pulx
                pulx
                jsr  lcd_fill         ; restliches Display mit Leerzeichen f�llen
                jmp  m_end

;*************
; M   M E N U
;
; Call Submenu
;
m_menu
                ldab m_timer_en       ; Falls Roundcount noch angezeigt wird, Displayinhalt NICHT speichern
                bmi  mmn_nosave       ; Sondern Zahl erneut ausgeben

                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
mmn_nosave
                jsr  m_reset_timer    ; Men�-Timer Reset (Timeout f�r Eingabe setzen)
                clrb
                jsr  lcd_cpos         ; Cursor Home
                ldab #MENU_SELECT
                stab m_state
                clr  m_svar1
                ldx  #m_menu_str
                jsr  printf
                jmp  m_end

;*************
; M   M E N U
;
; Call Submenu
;
m_menu_select
                jsr  m_reset_timer    ; Men�-Timer Reset (Timeout f�r Eingabe setzen)
                ldaa cfg_head
                cmpa #2
                beq  mms_hd2
                cmpa #3
                beq  mms_hd3
                bra  mms_hd3
mms_hd3
                cmpb #HD3_ENTER
                beq  mms_execute
                cmpb #HD3_EXIT
                beq  mms_exit
                ldaa m_svar1
                cmpb #KC_D1
                beq  mms_cycle_up
                cmpb #KC_D2
                beq  mms_cycle_down
                jmp  m_end
mms_hd2
                cmpb #HD2_ENTER
                beq  mms_execute
                cmpb #HD2_EXIT
                beq  mms_exit
                ldaa m_svar1
                cmpb #KC_D1
                beq  mms_cycle_up
                cmpb #KC_D2
                beq  mms_cycle_down
                jmp  m_end
mms_cycle_down
                tsta
                beq  mms_cd_wrap
                deca
                bne  mms_display
mms_cd_wrap
                ldaa #M_MENU_ENTRIES
                bra  mms_display
mms_cycle_up
                inca
                cmpa #M_MENU_ENTRIES+1
                bne  mms_display
                ldaa #1
;***************
mms_display
                staa m_svar1
                clrb
                jsr  lcd_cpos
                ldx  #m_menu_str
mmsd_loop
                tsta
                beq  mms_print
mmsd_loop_str
                inx
                ldab 0,x
                bne  mmsd_loop_str    ; search for end of string
                inx
                inx
                inx                   ; skip function pointer
                deca
                bra  mmsd_loop
mms_print
                jsr  printf           ; print selected menu entry
                jmp  m_end
;***************
mms_execute
                ldx  #m_menu_str
                ldaa m_svar1
mmse_loop_str
                inx
                ldab 0,x
                bne  mmse_loop_str
                tsta
                beq  mmse_jump
                deca
                inx
                inx
                inx
                bra  mmse_loop_str
mmse_jump
                clr  m_svar1
                ldx  1,x              ; get function pointer
                jmp  0,x              ; goto function
;***************
mms_exit
                jmp  m_end_restore
;***************************
; M   D I G I T
;
; select frequency digit to alter using up/down
;
; Stack depth on entry: 2
;
m_digit
                ldab m_timer_en       ; Falls Roundcount noch angezeigt wird, Displayinhalt NICHT speichern
                bmi  mds_nosave       ; Sondern Zahl erneut ausgeben

                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
mds_nosave
                ldaa #(0<<4)+3        ; edit char 0 to char 3
                clrb                  ; edit mode: decimal
                jsr  m_digit_editor
                tsta                  ; test for abort
                bne  mds_end
                jmp  m_set_freq_x     ; set frequency
mds_end
                jmp  m_end_restore

;***************************
; M   D I G I T
;
; select frequency digit to alter using up/down
;
; Stack depth on entry: 2
;
m_dtmf_direct
                cmpb #10
                bcs  m_dtmf_go
                subb #10
                ldx  #m_dtmf_ctab
                abx
                ldab 0,x
m_dtmf_go
                ldaa tone_timer
                beq  mdg_start          ; check if tone is still on
                jsr  tone_stop_sig      ; if it is, stop it
                WAIT(40)                ; wait 40 ms (DTMF minimum pause)
mdg_start
                jsr  dtmf_key2freq      ; calculate DTMF frequencies
                jsr  dtone_start        ; start DTMF tone output

                ldab #4
                stab tone_timer        ; 0,4 sek Ton ausgeben

                jmp  m_end
m_dtmf_ctab
           .db $0e, 0, 0, $0d, $0c, 0, 0,$0a,$0b,$0f
