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
#DEFINE M_MENU_ENTRIES 4
#else
#DEFINE M_MENU_ENTRIES 5
#endif

m_menu_str	.db "MENU    ",0
		.dw m_recall_submenu

		.db "RECALL  ",0
		.dw m_recall_submenu

		.db "STORE   ",0
		.dw m_store_submenu

		.db "TX CTCSS",0
		.dw m_none

		.db "RX CTCSS",0
		.dw m_none

		.db "DTMF",0
		.dw m_none
#ifdef EVA9
		.db "POWER   ",0
		.dw m_power_submenu
#endif
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
                aslb                  ; Index für Tabelle erzeugen
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
                ldx  #m_top_h3        ; Basisadresse holen
                bra  mto_tabjmp
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
;                .dw m_none            ; D4 - none
                .dw m_test            ; D4 - Test
;                .dw m_prnt_tc         ; D4 - Taskswitches/s anzeigen
                .dw m_tone            ; D5 - 1750 Hz Ton
                .dw m_none            ; D6 -
                .dw m_txshift         ; D7 - TX Shift ändern
                .dw m_recall          ; D8 - Recall vfo frequency from memory
                .dw m_frq_store       ; #
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
                .dw m_none            ; - (0)
                .dw m_test            ; - (1)
                .dw m_none            ; - (2)
                .dw m_none            ; - (3)
                .dw m_none            ; - (4)
                .dw m_none            ; upper / right side (5)
                .dw m_none            ; - (6)
                .dw m_none            ; - (7)
                .dw m_menu            ; lower / right side (8)
                .dw m_none            ; - (9)
                .dw m_none            ; - (*)
                .dw m_frq_up          ; D1 - Kanal+
                .dw m_frq_down        ; D2 - Kanal-
                .dw m_sql_switch      ; D3 - Squelch ein/aus
                .dw m_prnt_tc         ; D4 - Taskswitches/s anzeigen
                .dw m_tone            ; D5 - 1750 Hz Ton
                .dw m_digit           ; D6 - Select Digit
                .dw m_txshift         ; D7 - TX Shift ändern
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
; Carriersquelch lässt niedrigere Schwelle zu als RSSI Squelch
;
m_sql_switch
                ldab sql_mode
                cmpb #SQM_RSSI
                beq  mss_none          ; RSSI -> none
                cmpb #SQM_CARRIER
                beq  mss_rssi          ; carrier -> RSSI
mss_carrier                            ; Carrier Squelch Pin auswerten
                ldab #SQM_CARRIER
                stab sql_mode
                ldaa #1
                ldab #2
                jsr  arrow_set
                bra  mss_end
mss_rssi                               ; RSSI Pin auswerten
                ldab #SQM_RSSI
                stab sql_mode
                ldaa #2
                ldab #2
                jsr  arrow_set
                bra  mss_end
mss_none                               ; Raussperre deaktivieren
                ldab #SQM_OFF
                stab sql_mode
                ldaa #0
                ldab #2
                jsr  arrow_set
mss_end
                jmp  m_end

;**************************************
; M   T O N E
;
; 1750 Hz Ton ausgeben
;
m_tone
                ldab #1
                stab ui_ptt_req        ; PTT drücken
                ldab tone_timer
                bne  mtn_reset_timer
                jsr  tone_start
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
                bne  mts_nosave       ;

                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
mts_nosave
                ldaa m_state
                cmpa #TXSHIFT_SW      ; Wurde Taste zum ersten Mal gedrückt?
                beq  mts_switch       ; Nein, dann nächste Shift auswählen
                                      ; Andernfalls aktuelle Shift ausgeben
                ldab #TXSHIFT_SW
                stab m_state

                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)

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
                ldaa #$45
                ldab #3
                jsr  decout
                pulx
                pulx
                jsr  lcd_fill
                jsr  freq_offset_print
                jmp  m_end
;*********************
; M T S   S W I T C H
;
; Aktivieren/Deaktivieren der Ablage, Vorzeichenwahl (+/-)
;
;
mts_switch
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
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
                bne  mts_to_idle      ; Bei allen anderen Tasten zu IDLE zurückkehren
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
                bne  mts_to_idle      ; Bei allen anderen Tasten zu IDLE zurückkehren
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
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
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
                clr  0,x              ; Eingabe mit 0 terminieren
msh_set_str
                pshx                  ; 32 Bit Platz schaffen auf Stack
                pshx                  ; für Ergebnis der Frequenzberechnung
                tsx                   ; Zeiger auf Zwischenspeicher (Stack) nach X
                ldd  #f_in_buf        ; Zeiger auf Eingabestring holen
                jsr  atoi             ; Frequenz berechnen
                ldd  #100             ; durch 100 teilen, da erste Ziffer der Eingabe als *10^8 (100 Mio) betrachtet wird
                jsr  divide32
                ldab cpos
                cmpb #3               ; Eingabe bestand aus 3 Zeichen?
                bne  msh_set_mhz      ; Nein, dann als vierstellige Eingabe in kHz interpretieren
                ldd  #10              ; Sonst als 3 stellige Eingabe in kHz interpretieren
                jsr  divide32
msh_set_mhz
                tsx
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
                std  m_timer          ; noch 800ms warten bevor wieder Frequenz angezeigt wird
                jmp  mts_print

;**************************************
; M   P R N T   R C
;
; Anzahl der Hauptschleifendurchläufe in der letzten Sekunde anzeigen
;
m_prnt_rc
                ldab m_timer_en       ; Falls Roundcount noch angezeigt wird, Displayinhalt NICHT speichern
                bne  mpr_nosave       ; Sondern Zahl erneut ausgeben

                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
mpr_nosave
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
                clrb
                jsr  lcd_cpos         ; Cursor Home
;                ldx  rc_last_sec      ; Rundenzähler holen

                clrb
                pshx
                pshb
                pshb
                ldaa #'l'
                jsr  putchar
                pulx
                pulx

                jsr  lcd_fill         ; restliches Display mit Leerzeichen füllen
                jmp  m_end
;**************************************
; M   T E S T
;
;
m_test
                ldab m_timer_en       ; Falls Roundcount noch angezeigt wird, Displayinhalt NICHT speichern
                bne  mt_nosave        ; Sondern Zahl erneut ausgeben

                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
mt_nosave
                ldab cpos
                pshb
                clrb
                jsr  lcd_cpos         ; Cursor Home

                pulb
                ldaa #'x'
                jsr  putchar

                jsr  lcd_fill         ; restliches Display mit Leerzeichen füllen

                jmp  m_end


;**************************************
; M   P R N T   T C
;
; Anzahl der Taskswitches in der letzten Sekunde anzeigen
;
m_prnt_tc
                ldab m_timer_en       ; Falls Roundcount noch angezeigt wird, Displayinhalt NICHT speichern
                bne  mtc_nosave       ; Sondern Zahl erneut ausgeben

                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
mtc_nosave
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
                clrb
                jsr  lcd_cpos         ; Cursor Home
                clra
                ldab sql_timer        ; Rundenzähler holen
                pshb
                psha
                psha
                psha
                ldaa #'l'
                clrb
                jsr  putchar
                pulx
                pulx
                jsr  lcd_fill         ; restliches Display mit Leerzeichen füllen
                jmp  m_end

;*************
; M   M E N U
;
; Call Submenu
;
m_menu
                ldab m_timer_en       ; Falls Roundcount noch angezeigt wird, Displayinhalt NICHT speichern
                bne  mmn_nosave       ; Sondern Zahl erneut ausgeben

                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
mmn_nosave
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
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
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
                ldaa cfg_head
                cmpa #2
                beq  mms_hd2
                cmpa #3
                beq  mms_hd3
                bra  mms_hd3
mms_hd3
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
                bne  mds_nosave       ; Sondern Zahl erneut ausgeben

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

