;****************************************************************************
;
;    MC 70    v1.0.4a - Firmware for Motorola MC micro trunking radio
;                       to use it as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2007  Felix Erckenbrecht, DG1YFE
;
;
;****************************************************************************
;***************************
; U I   I N I T
;***************************
ui_init
                pshb
                psha
                pshx

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

                pulx
                pula
                pulb
                rts
;***************************
; U I   S T A R T
;***************************
ui_start
                pshx
                ldx  #ui                  ; Zeiger auf UI Task holen
                stx  start_task           ; Zeiger setzen
;                swi                       ; Task starten
                pulx
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
                bra  no_intro

                PRINTF(dg1yfe_str)
                jsr  lcd_fill
                clrb
                jsr  lcd_cpos
;                WAIT(250)

                PRINTF(mc70_str)
                jsr  lcd_fill
                clrb
                jsr  lcd_cpos
                WAIT(150)
                PRINTF(ver_str)
                jsr  lcd_fill
                clrb
                jsr  lcd_cpos
                WAIT(150)
no_intro
                ldx  #frequency
;                jsr  freq_print             ; Frequenz anzeigen
                WAIT(150)
                clra
                jsr  lcd_clr
                ldx  #42
                pshx
                clrb
                pshb
                pshb
                tsx
                pshx
                ldx  #test_str
                jsr  printf
                ins
bla
                bra  bla

                jsr  freq_offset_print      ; Frequenz anzeigen

                ldab #1
                jsr  pll_led                ; PLL Lock Status auf rote LED ausgeben

                jsr  menu_init
ui_loop                                     ; komplette Display Kommunikation
                jsr  menu                   ; Menü für Frequenzeingabe etc.
                jsr  sci_trans_cmd          ; Eingabe prüfen und ggf. in Menü Puffer legen
                clrb
                jsr  pll_led                ; PLL Lock Status auf rote LED ausgeben
                jsr  led_update             ; LED Puffer lesen und ggf LEDs neu setzen

                swi
                jmp  ui_loop



;*******************************************
test_str
                .db "X 42Z",0
                .db "X%3iZ",0
dg1yfe_str
                .db "DG1YFE",0
mc70_str
                .db "MC 70",0
ver_str
                .db "1_0_6",0
rom_init_str
                .db "ROM INIT",0
ram_err_str
                .db "RAM ERR",0            ; $11
slot_str
                .db " SLOTS",0


