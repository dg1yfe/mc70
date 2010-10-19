;***************************
; U I   I N I T
;***************************
ui_init

                clr  tasksw               ; Taskswitchzähler auf 0
                ldab #1
                stab tasksw_en            ; Taskswitches per Interrupt verbieten

                ldx  #notask              ; UI Task noch nicht starten
;                ldd  #ui
                stx  start_task           ; immer wieder 'no task' aufrufen

                ldx  #STACK2-7            ; Stackpointer 2 setzen

                ldd  #notask              ; UI Task noch nicht starten
                std  6,x                  ; Return Addresse für SWI Int setzen
                std  4,x                  ; X
                clra
                std  2,x                  ; AB
                staa 1,x                  ; Condition Codes - alle Flags gelöscht
                stx  stackbuf             ; Stackpointer 2 sichern

                ldx  #0
                stx  ui_frequency
                stx  ui_frequency+2          ; Bisher keine Frequenzeingabe
                ldx  #-1
                stx  ui_txshift
                stx  ui_txshift+2

                oim  #$20,sql_mode         ; Squelch aktiviert

                rts
;***************************
; U I   S T A R T
;***************************
ui_start
                ldx  #ui                  ; Zeiger auf UI Task holen
                stx  start_task           ; Zeiger setzen
;                swi                       ; Task starten
                rts
;***************************
; U I
;***************************
;
; User Interface
; 2. Task für die Kommunikation mit dem Benutzer
; Alleine dieser Task bedient das (laaaaaangsame) Display
; Die Kommunikation mit dem Control-Task, der die meisten zeitkritischen
; Dinge steuert findet über verschiedene Flags und Variablen (Speicherzellen)
; statt
;
;
ui
                jsr  lcd_s_reset           ; LCD Software Reset + Init
                tsta
                beq  ui_cont_w_lcd         ; Loopback detected -> no display (and no initialisation)
                jmp  no_intro              ; -> start immediatly
ui_cont_w_lcd
                ldab msg_mode
                tba
                andb #%11000000
                cmpb #%10000000
                bne  ui_long_msg
                jmp  ui_short_msg
ui_long_msg
                PRINTF(soft_str)
                jsr  lcd_fill
                clrb
                jsr  lcd_cpos
                WAIT(80)
                PRINTF(ver_str)
                jsr  lcd_fill
                clrb
                jsr  lcd_cpos
                WAIT(120)
                ldab #'['
                ldaa #'c'
                jsr  putchar
                ldaa #'p'
                psha
                ldab #seg15left
                jsr  putchar
                pula
                psha
                ldab #(seg15lu + seg15u + seg15lm)
                jsr  putchar
                pula
                psha
                ldab #seg15right
                jsr  putchar
                pula
                psha
                ldab #seg15rm
                jsr  putchar
                pula
                ldab #'c'
                jsr  store_dbuf         ; 'c' als Stellvertreter im Buffer speichern

                PRINTF(year_str)

                jsr  lcd_fill
                clrb
                jsr  lcd_cpos
                WAIT(250)
                PRINTF(dg1yfe_str)
                jsr  lcd_fill
                clrb
                jsr  lcd_cpos
                ldaa msg_mode
                oraa #%10000000
                anda #%10111111
                staa msg_mode           ; kurze Meldung ausgeben
                WAIT(450)
ui_short_msg
                PRINTF(licensed_str)
                jsr  lcd_fill
                clrb
                jsr  lcd_cpos
                WAIT(500)
                PRINTF(to_str)
                jsr  lcd_fill
                clrb
                jsr  lcd_cpos
                WAIT(200)
                PRINTF(call)
                jsr  lcd_fill
                clrb
                jsr  lcd_cpos
                WAIT(600)

no_intro
                jsr  menu_init
                WAIT(200)

                jsr  sci_trans_cmd          ; Eingabe prüfen und ggf. in Menü Puffer legen
                jsr  sci_rx_m               ; Auf Tastendruck testen und ggf. lesen
                tsta                        ; Taste gedrückt?
                bne  ui_frq_prnt            ; Nein? Dann auf in die UI Schleife
                cmpb #3                     ; UP / D1 ?
                bne  ui_frq_prnt            ; Nein, dann auf in die UI Schleife
                
hash_print
                ldab #8
                pshb
                ldx  #char_convert-23
hash_p_loop1
                clrb
hash_p_loop2
                pshb
                pshx
                ldab 23,x
                ldaa #'x'
                jsr  putchar                ; Hash ausgeben
                pulx
                inx
                pulb
                incb
                tba
                anda #3
                bne  hash_p_loop2          ; je 4 Hex Zeichen ausgeben
                WAIT(8000)                 ; 8 Sekunden warten
                clra
                jsr  lcd_clr
                pulb
                decb
                pshb
                bne  hash_p_loop1
                pulb

                ldab #3                   ; Name ausgeben
                pshb                      ; 3 Durchgänge, 2 mit 8 Zeichen, einer mit 4 Zeichen
                ldab #4
                ldx  #name
name_p_loop2
                pshb
                clrb
                jsr  lcd_cpos
                pulb
                addb #4
name_p_loop1
                pshb
                ldab 0,x
                inx
                pshx
                pshb
                ldaa #'c'
                jsr  putchar
                pula
                pulx
                pulb
                decb
                bne  name_p_loop1         ; Loop für Zeichenausgabe (8 oder 4)
                jsr  lcd_fill             ; sicherstellen dass Display vollständig neu geschrieben wird
                WAIT(8000)
                cmpa #$20
                beq  name_p_exit
                pula
                ldab #4
                cmpa #2                    ; im 3. Durchgang nur 4 Zeichen ausgeben (8+8+4)
                bne  name_p_dec2
                clrb
name_p_dec2
                deca
                psha
                bne  name_p_loop2
name_p_exit
                jsr  lcd_fill
                clrb
                jsr  lcd_cpos
                ins



ui_frq_prnt
                ldx  #frequency
                jsr  freq_print             ; Frequenz anzeigen

                jsr  freq_offset_print      ; Frequenz anzeigen

ui_loop                                     ; komplette Display Kommunikation
                jsr  menu                   ; Menü für Frequenzeingabe etc.
                jsr  sci_trans_cmd          ; Eingabe prüfen und ggf. in Menü Puffer legen
                jsr  pll_led                ; PLL Lock Status auf rote LED ausgeben
                jsr  led_update             ; LED Puffer lesen und ggf LEDs neu setzen
                swi

                ldx  tick_hms
                cpx  #3000                  ; schon 2 MInuten eingeschaltet?
                bcs  ui_loop                ; Noch nicht -> loop
                ldab msg_mode               ; Wird lange Meldung ausgegeben?
                bpl  ui_loop                ; Ja -> loop
                andb #%01111111             ; Nach 2 Minuten Einschaltzeit lange Meldung ausgeben
                stab msg_mode
                bra  ui_loop

;*******************************************
year_str
                .db "] 2010",0
dg1yfe_str
                .db "DG1YFE",0
soft_str
                .db "MC2 E9",0
licensed_str    .db "LICENSED",0
to_str          .db "TO",0
ver_str
                .db "1.0.6",0
rom_init_str
                .db "ROM INIT",0
slot_str
                .db " SLOTS",0


