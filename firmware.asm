;****************************************************************************
;
;    MC 70    v1.0.1 - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2007  Felix Erckenbrecht, DG1YFE
;
;    This program is free software; you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation; either version 2 of the License, or
;    any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program; if not, write to the Free Software
;    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;
;
;****************************************************************************
;
               .MODULE FIRMWARE
;
#INCLUDE "macros.asm"           ; include macros & definitions
#INCLUDE "regmem.asm"           ; Portadresses & Random Access Memory
;
;**************************
; S T A R T   O F   R O M
;**************************
                .ORG $2000
rom
;********************************
; S T A R T   O F   S Y S T E M
;********************************
                .ORG $C000                 ; OS in letzten Flash Sektor legen
reset
                lds  #$1FFF                ; Stackpointer 1 setzen
                jsr  io_init               ; I/O initialisieren (Ports, I2C, etc...)
;                jsr  chk_debug             ; Debugmodus ?
                jsr  chk_isu               ; In System Update? ?

                ldab #1                    ; Frequenz etc noch NICHT speichern
                jsr  pwr_sw_chk            ; Power switch checken - wenn Gerät ausgeschaltet ist,
                                           ; nicht weitermachen

;************************************
;************************************
Start
                jsr  sci_init              ; serielle Schnittstelle aktivieren
                jsr  init_SIO              ; SIO Interrupt konfigurieren
                jsr  init_OCI              ; Timer Interrupt starten
                jsr  ui_init               ; 2. Task initialisieren (2. Stack)

                ldd  #FSTEP                ; Kanalraster holen
                jsr  pll_init              ; PLL mit Kanalraster initialisieren

                cli
;                jsr  lcd_reset
                jsr  lcd_h_reset           ; LCD Hardware Reset
                jsr  lcd_s_reset           ; LCD Software Reset + Init

                clr  irq_wd_reset          ; Watchodog Reset durch Timer Interrupt zulassen

                ldab #$80
                stab pll_locked_flag       ; Den Status der PLL auf jeden Fall anzeigen

                jsr  freq_init             ; Frequenzeinstellungen initialisieren
                tsta
                beq  start_over

                ldaa #'p'
                ldab #YEL_LED+BLINK
                jsr  putchar
                PRINTF(rom_init_str)
                WAIT(1000)
;
;***************
;                jsr  mem_init              ; Speicher initialisieren
start_over
                clr  pll_timer
                ldab #1                     ; Squelch startet in "Carrier Detect" Mode
                stab sql_flag               ;

                ldx  #0
                stx  roundcount             ; Rundenzähler initialisieren

                jsr  ui_start               ; UI Task starten

                clr  tasksw_en              ; Taskswitch spätestens jede Millisekunde

                ldab #%10010000             ; Audio enable
                ldaa #%11111111             ;
                jsr  send2shift_reg

                jsr  receive                ; Empfänger aktivieren
                ldab #GRN_LED+ON
                jsr  led_set                ; Grüne LED aktivieren

loop
                clrb                        ; Frequenz etc. speichern wenn Gerät ausgeschaltet wird
                jsr  pwr_sw_chk             ; Ein/Ausschalter abfragen & bedienen
                jsr  trx_check              ; PTT abfragen und Sende/Empfangsstatus ändern
                jsr  squelch                ; Squelch bedienen

                sei                         ; Rundenzähler erhöhen
                ldx  roundcount
                inx
                beq  skip_count
                stx  roundcount
skip_count
                cli
                swi
                jsr  frq_check              ; Überprüfen ob Frequenz geändert werden soll
                jmp  loop

;*******************
;*******************
trx_check
                pshb
                psha
                pshx

                jsr  ptt_get_status         ; PTT Status abfragen
                asla                        ; Höchstes Bit ins Carryflag schieben
                bcc  trc_end                ; War es gesetzt fand eine Statusänderung statt
                bne  trc_tx                 ; Ist es <>0 wird jetzt gesendet
; RX
                jsr  receive                ; Empfänger aktivieren
                bra  trc_end
; TX
trc_tx
                jsr  transmit               ; Sender aktivieren
trc_end
                pulx
                pula
                pulb
                rts
;*******************
;*******************


;*************************************************************************
; INCLUDES
#INCLUDE       "ui.asm"                    ; User Interface (2. Task)
#INCLUDE       "menu.asm"                  ; Menü Steuerung
#INCLUDE       "subs.asm"                  ; general Subroutine File
#INCLUDE       "pll_freq.asm"              ; PLL & Frequency related Subroutines
#INCLUDE       "display.asm"               ; LC Display related Subroutines
#INCLUDE       "mem.asm"                   ; Memory related Subroutines
#INCLUDE       "math.asm"                  ; Divide, Multiply, Exp Table
#INCLUDE       "eeprom.asm"                ; EEPROM Zugriffsroutinen
#INCLUDE       "io.asm"                    ; all I/O
#INCLUDE       "int.asm"                   ; Interrupt Service Routines
#INCLUDE       "debug.asm"                 ; Debugmodul
#INCLUDE       "isu.asm"                   ; In System Update Modul
               .end
