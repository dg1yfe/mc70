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
#ifdef EVA5
                oim  #SQM_CARRIER,sql_mode ; Squelch aktiviert
#endif
#ifdef EVA9
                oim  #SQBIT,sql_mode ; Squelch aktiviert
#endif
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

                bra  no_intro

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
                WAIT(200)
                PRINTF(dg1yfe_str)
                jsr  lcd_fill
                clrb
                jsr  lcd_cpos
                ldaa msg_mode
                oraa #%10000000
                anda #%10111111
                staa msg_mode           ; kurze Meldung ausgeben
                WAIT(50)
ui_short_msg
no_intro
                ldab #1
                jsr  pll_led                ; PLL Lock Status auf rote LED ausgeben                jsr  menu_init
                jsr  menu_init
                WAIT(100)
ui_frq_prnt
                ldx  #frequency
                jsr  freq_print             ; Frequenz anzeigen

                jsr  freq_offset_print      ; Frequenz anzeigen


ui_loop                                     ; komplette Display Kommunikation
                jsr  menu                   ; Menü für Frequenzeingabe etc.
#define UI_UPD_LOOP jsr  sci_trans_cmd          ; Eingabe prüfen und ggf. in Menü Puffer legen
#defcont \ clra
                                            ; PLL Lock Status auf rote LED ausgeben
#defcont \ jsr  pll_led
#defcont \ jsr  led_update                  ; LED Puffer lesen und ggf LEDs neu setzen

                UI_UPD_LOOP
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
dg1yfe_str
                .db "DG1YFE",0
soft_str
                .db "MC70",0
ver_str
                .db "12 002",0
rom_init_str
                .db "ROM INIT",0
slot_str
                .db " SLOTS",0

