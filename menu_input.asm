;*******************************
; M   S T A R T   I N P U T
;
; Frequenzeingabe �ber ZIffernfeld starten
;
;
m_start_input
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
                clra
                jsr  lcd_clr          ; Display l�schen
m_print
                jsr  m_reset_timer    ; Men�-Timer Reset (Timeout f�r Eingabe setzen)
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
                jmp  m_end            ; Zur�ck
;**********************************
; M   F   I N
;
; Frequenzeingabe, Eingabe entgegennehmen
;
m_f_in
                cmpb #KC_NONE_NUMERIC      ; Zahl?
                bcc  m_non_numeric         ; Wenn nicht, dann entsprechende Funktionen ausf�hren
                ldaa cpos                  ; sonst nachsehen
                cmpa #08 		           ; ob noch Platz im Display
		        bne  m_print		       ; Wenn ja, Zeichen ausgeben und in Frequenzeingabepuffer speichern
                jmp  m_end

;**********************************
; M   N O N   N U M E R I C
;
; Nicht numerische Taste w�hrend Frequenzeingabe auswerten
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
; eingegebenes Zeichen l�schen
;
m_backspace
                jsr  m_reset_timer
                jsr  lcd_backspace    ; zuletzt eingegebenes Zeichen auf dem Display
                ldab cpos
                ldx  #f_in_buf        ; und im Frequenzeingabepuffer l�schen
                abx
                clr  0,x              ; String im Frequenzeingabe-Puffer terminieren
		        ldaa #F_IN            ; Mindestens 1 freier Platz im Display vorhanden, State anpassen
		        staa m_state
                jmp  m_end            ; Zur�ck

;**********************************
; M   C L R   D I S P L
;
; Display und Eingabe l�schen
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
                pshx                  ; f�r Ergebnis der Frequenzberechnung

                tsx                   ; Zeiger auf Zwischenspeicher (Stack) nach X
                ldd  #f_in_buf        ; Zeiger auf Eingabestring holen
                jsr  frq_calc_freq    ; Frequenz berechnen

                tsx                   ; Zeiger auf Frequenz DWord nach X
                jsr  frq_update       ; Control Task mitteilen, dass neue Frequenz gesetzt wurde
                clra
                jsr  lcd_clr          ; LCD l�schen
                ldab #IDLE
                stab m_state          ; n�chster State ist wieder IDLE

                PRINTF(m_ok)          ; "OK" ausgeben - PLL ist eingerastet
                WAIT(200)             ; 200ms warten
m_frq_prnt
                clrb
                jsr  lcd_cpos         ; cursor auf pos 0 setzen

                ldx  #frequency       ; Adresse von Frequenz Word holen
                jsr  freq_print       ; Frequenz ausgeben
                jsr  freq_offset_print; Offset anzeigen
                jsr  lcd_fill         ; Display mit Leerzeichen f�llen (schneller als l�schen und dann schreiben)

                clr  m_timer_en       ; Men� Timer disabled - Aktuelles Display = neues Display
                pshb
                psha
                clr  pll_timer        ; PLL Timer auf 0
                pula
                pulb
msf_end
                pulx
                pulx                  ; eingegebene Frequenz vom Stack l�schen
                jmp  m_end
