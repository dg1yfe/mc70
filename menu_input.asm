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
                cmpb #KC_NONE_NUMERIC      ; Zahl?
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

                pshx                  ; 32 Bit Platz schaffen auf Stack
                pshx                  ; für Ergebnis der Frequenzberechnung

                tsx                   ; Zeiger auf Zwischenspeicher (Stack) nach X
                ldd  #f_in_buf        ; Zeiger auf Eingabestring holen
                jsr  frq_calc_freq    ; Frequenz berechnen

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
; Parameter: A - Erstes Digit (Bit 0-2),
;                Letztes Digit (Bit 3-5),
;                Mode (Bit 6-7) :  0 - Dezimal
;                                  1 - Alphanumerisch
;                                  2 - Alphabet
;
; Ergebnis : X - Zeiger auf 0-terminierten String (f_in_buffer)
;            A - Status :  0 - OK
;                          1 - Abbruch
;
; changed Regs : A,X
;
; 3 - first pos
; 2 - last pos
; 1 - lower limit
; 0 - upper limit
m_digit_editor
                pshb

                tab
                anda #7
                psha                  ; save first digit pos

                lsra
                lsra
                lsra
                tba
                anda #7
                psha                  ; save last digit pos

                lsrb
                lsrb
                lsrb
                tstb
                beq  mde_numeric
                cmpb #1
                beq  mde_alphanum
                ldab #'a'
                pshb
                ldab #'z'
                pshb
                bra  mde_chkspace
mde_numeric
                ldab #'0'
                pshb
                ldab #'9'
                pshb
                bra  mde_chkspace
mde_alphanum
                ldab #'0'
                pshb
                ldab #'z'
                pshb
mde_chkspace
                tsx
                ldab 3,x              ; get first pos
                ldx  #dbuf            ; use as index for display buffer
                abx
                ldab 0,x              ; get char at digit
                andb #~CHR_BLINK      ; ignore blink bit
                tba
                cmpa #$20             ; check if current position contains space
                beq  mde_convspace
                ldaa #1
                jsr  lcd_chr_mode     ; let digit blink


                ins
                ins
                pulb
                rts


;****************
; M   D I G I T
;
m_digit
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
                cmpb #HD2_ENTER
                beq  mdi_enter
                cmpb #HD2_EXIT
                beq  mdi_exit
                cmpb #KC_D1
                beq  mdi_up
                cmpb #KC_D2
                beq  mdi_down
                cmpb #KC_D6
                beq  mdi_next
                jmp  m_end
mdi_up
                ldab DIGIT_POS        ; get current digit position
                ldx  #dbuf            ; use as index for display buffer
                abx
                ldab 0,x              ; get char at digit
                andb #~CHR_BLINK      ; ignore blink bit
                tba
                anda #$30
                cmpa #$30             ; check is current position contains number
                bne  mdi_checknum
                incb                  ; increment
                cmpb #'9'+1           ; wrap around at 9
                bne  mdu_store
                ldab #'0'
                bra  mdu_store
mdi_down
                ldab DIGIT_POS        ; get current digit position
                ldx  #dbuf            ; use as index for display buffer
                abx
                ldab 0,x              ; get char at digit
                andb #~CHR_BLINK      ; ignore blink bit
                decb                  ; decrement
                cmpb #'0'             ; wrap around at 0
                bcc  mdu_store
                ldab #'9'
mdu_store
                tba                   ; save digit in A
                ldab DIGIT_POS
                jsr  lcd_cpos         ; move cursor to digit position
                tab
                orab #$80             ; set blink bit
                ldaa #'c'
                jsr  putchar          ; print char
                jmp  m_end
;----------------
mdi_next
                ldab DIGIT_POS
                clra
                jsr  lcd_chr_mode
                decb
                ldaa DIGIT_MODE       ; check mode
                cmpa #DM_FREQ         ; behaviour depends on mode
                beq  mdn_mode_freq    ;
                tstb
                bne  mdn_shift        ; in shift mode
                ldab #2               ; chars 1-2 are editable
                bra  mdn_shift
mdn_mode_freq
                tstb                  ; in frequency mode,
                bpl  mdn_shift        ; chars 0-3 are editable
                ldab #3
mdn_shift
                stab DIGIT_POS
                inca
                jsr  lcd_chr_mode

                jmp  m_end
;----------------
mdi_exit
                ldx  #0
                stx  m_timer
                jmp  m_end

;----------------
mdi_enter
                ldab DIGIT_MODE
                cmpb #DM_FREQ
                beq  mdi_mode_freq
                ldd  dbuf+1
                std  f_in_buf
                ldd  dbuf+3
                std  f_in_buf+2
                ldab #4
                stab cpos
                jmp  m_set_shift
mdi_mode_freq
                ldd  dbuf
                std  f_in_buf
                ldd  dbuf+2
                std  f_in_buf+2
                ldd  dbuf+4
                std  f_in_buf+4
                ldab #6
                stab cpos
                jmp  m_set_freq
