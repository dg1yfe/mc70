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
;***************************
; U I   I N I T
;***************************
ui_init
                pshb
                psha
                pshx

                clr  tasksw               ; Taskswitchz�hler auf 0
                ldab #1
                stab tasksw_en            ; Taskswitches per Interrupt verbieten

                ldx  #notask              ; UI Task noch nicht starten
;                ldd  #ui
                stx  start_task           ; immer wieder 'no task' aufrufen

                ldx  #STACK2-7            ; Stackpointer 2 setzen

                ldd  #notask              ; UI Task noch nicht starten
                std  6,x                  ; Return Addresse f�r SWI Int setzen
                std  4,x                  ; X
                clra
                std  2,x                  ; AB
                staa 1,x                  ; Condition Codes - alle Flags gel�scht
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
; 2. Task f�r die Kommunikation mit dem Benutzer
; Alleine dieser Task bedient das (laaaaaangsame) Display
; Die Kommunikation mit dem Control-Task, der die meisten zeitkritischen
; Dinge steuert findet �ber verschiedene Flags und Variablen (Speicherzellen)
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
                jsr  freq_print             ; Frequenz anzeigen
                WAIT(150)
                clra
;                jsr  lcd_clr

                jsr  freq_offset_print      ; Frequenz anzeigen

                ldab #1
                jsr  pll_led                ; PLL Lock Status auf rote LED ausgeben

                jsr  menu_init
ui_loop                                     ; komplette Display Kommunikation
                jsr  menu                   ; Men� f�r Frequenzeingabe etc.
#define UI_UPD_LOOP jsr  sci_trans_cmd          ; Eingabe pr�fen und ggf. in Men� Puffer legen
#defcont \ clra   
                                            ; PLL Lock Status auf rote LED ausgeben
#defcont \ jsr  pll_led
#defcont \ jsr  led_update                  ; LED Puffer lesen und ggf LEDs neu setzen

                UI_UPD_LOOP

                swi
                jmp  ui_loop


;*******************************************
test_str
;                .db "x30 Z",0
                .db "X%+04iZ",0
dg1yfe_str
                .db "DG1YFE",0
mc70_str
                .db "MC 70",0
ver_str
                .db "11 01",0
rom_init_str
                .db "ROM INIT",0
ram_err_str
                .db "RAM ERR",0            ; $11
slot_str
                .db " SLOTS",0


