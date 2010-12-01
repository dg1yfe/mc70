;
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
;
;*******************************
; M   I D L E
;
m_idle
                aslb                  ; Index f�r Tabelle erzeugen
                ldx  #m_idle_tab      ; Basisadresse holen
                abx                   ; Index addieren
                ldx  0,x              ; Tabelleneintrag holen

                jmp  0,x              ; Funktion aufrufen

m_idle_h3
m_idle_tab
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
;                .dw m_prnt_rc         ; D4 - Control Task Schleifendurchl�uft per sek. ausgeben
                .dw m_prnt_tc         ; D4 - Taskswitches/s anzeigen
                .dw m_tone            ; D5 - 1750 Hz Ton
                .dw m_none            ; D6 -
                .dw m_txshift         ; D7 - TX Shift �ndern
                .dw m_sel_mbank       ; D8 - Speicherbank w�hlen
                .dw m_frq_store       ; #
;                .dw m_sel_mbank       ; #



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
                stab ui_ptt_req        ; PTT dr�cken
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
                pulb
                pshb
                tstb
                bpl  mts_pos_shift    ; Vorzeichen pr�fen
                pulx
                pula
                pulb
                jsr  sig_inv32        ; Vorzeichen umkehren
                pshb
                psha
                pshx                  ; Offset auf Stack speichern
                ldab #'+'
                bra  mts_print_offset
mts_pos_shift
                ldab #'-'
mts_print_offset
                ldaa #'c'
                jsr  putchar          ; Vorzeichen ausgeben
                ldab #3
                ldaa #'l'
                jsr  putchar          ; aktuelle TX Shift ausgeben
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
                cmpb #KC_STERN
                beq  mts_chg_sign
                cmpb #KC_D7           ; 'A'?
                beq  mts_toggle
                cmpb #KC_RAUTE
                bne  mts_to_idle      ; Bei allen anderen Tasten zu IDLE zur�ckkehren
                ldx  #0
                stx  m_timer
                jmp  m_end
mts_to_idle
                pshb
                jsr  restore_dbuf     ; Displayinhalt wiederherstellen
                pulb
                jmp  m_idle           ; Mit Frequenzeingabe weitermachen
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
                bra  mts_print
mts_to_zero
                ldx  #0
                stx  ui_txshift+2
                stx  ui_txshift
                swi
                pshx
                pshx
                bra  mts_print
mts_chg_sign
                ldx  offset
                ldd  offset+2
                jsr  sig_inv32        ; Vorzeichen umkehren
                std  txshift+2
                stx  txshift
                std  ui_txshift+2
                stx  ui_txshift
                swi
                pshb
                psha
                pshx                  ; Offset auf Stack speichern
                jmp  mts_print
mts_end
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
                pshx                  ; 32 Bit Platz schaffen auf Stack
                pshx                  ; f�r Ergebnis der Frequenzberechnung

                tsx                   ; Zeiger auf Zwischenspeicher (Stack) nach X
                ldd  #f_in_buf        ; Zeiger auf Eingabestring holen
                jsr  frq_calc_freq    ; Frequenz berechnen
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
; Anzahl der Hauptschleifendurchl�ufe in der letzten Sekunde anzeigen
;
m_prnt_rc
                ldab m_timer_en       ; Falls Roundcount noch angezeigt wird, Displayinhalt NICHT speichern
                bne  mpr_nosave       ; Sondern Zahl erneut ausgeben

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

