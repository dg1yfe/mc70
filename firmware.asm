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
;
               .MODULE FIRMWARE
;
#INCLUDE "macros.asm"           ; include macros & definitions
#INCLUDE "regmem.asm"           ; Portadresses & Random Access Memory
#include "audio_tabs.asm"
;
;**************************
; S T A R T   O F   R O M
;**************************
                .ORG $2000
rom
;********************************
; S T A R T   O F   S Y S T E M
;********************************
                .ORG $C000                 ;
reset
                lds  #STACK1               ; Stackpointer 1 setzen
                jsr  io_init               ; I/O initialisieren (Ports, I2C, etc...)
;                jsr  chk_debug             ; Debugmodus ?
;                jsr  chk_isu               ; In System Update? ?
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
                                           ; ab hier können I/O Funktionen verwendet werden

                ldd  #FSTEP                ; Kanalraster holen
                jsr  pll_init              ; PLL mit Kanalraster initialisieren

                ldab #1
                stab tasksw_en             ; Taskswitch verbieten

                cli
#ifdef SIM
	ldaa #2
	staa cfg_head
	ldd  #0
	jsr  tone_start
sim_loop
	bra  sim_loop
#endif
                jsr  lcd_h_reset           ; LCD Hardware Reset

                jsr  freq_init             ; Frequenzeinstellungen initialisieren
                psha

                ldab #3
                stab cfg_head
                ldd  #$01FD                 ; get config Byte
                jsr  eep_rand_read
                andb #2                     ; isolate Bit 1
                ldaa cfg_defch_save         ; get config value
                anda #%11111101             ; exclude Bit 1
                aba                         ; add Bit 1 from Reg B
                staa cfg_defch_save         ; store new config value

                jsr  ui_start               ; UI Task starten

                clr  tasksw_en              ; Taskswitch spätestens jede Millisekunde

                ldab #GRN_LED+LED_ON
                jsr  led_set                ; Grüne LED aktivieren


                WAIT(500)
                jsr  s_timer_init
;
;

;***************
start_over
                jsr  receive                ; Empfänger aktivieren
                ldab #1                     ; in 300 ms
                stab pll_timer              ; den PLL Status prüfen

                ldaa #~SR_RXAUDIO           ; disable RX Audio
                ldab #SR_AUDIOPA
                jsr  send2shift_reg         ; enable Audio PA

loop
                ldab cfg_defch_save         ; Frequenz etc. speichern wenn Gerät ausgeschaltet wird
                andb #2
                jsr  pwr_sw_chk             ; Ein/Ausschalter abfragen & bedienen
;                jsr  trx_check              ; PTT abfragen und Sende/Empfangsstatus ändern
;*** TRX check
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
;****
                jsr  squelch                ; Squelch bedienen
ml_sql_end
                swi
                jsr  frq_check              ; Überprüfen ob Frequenz geändert werden soll
                jsr  wd_reset
                jsr  s_timer_update
                jmp  loop


;*******************


;*************************************************************************
; INCLUDES
#INCLUDE       "ui.asm"                    ; User Interface (2. Task)
#INCLUDE       "menu.asm"                  ; Menü Steuerung
#INCLUDE       "subs.asm"                  ; general Subroutine File
#INCLUDE       "timer.asm"                 ; Time/Timer related subroutines
#INCLUDE       "pll_freq.asm"              ; PLL & Frequency related Subroutines
#INCLUDE       "display.asm"               ; LC Display related Subroutines
#INCLUDE       "mem.asm"                   ; Memory related Subroutines
#INCLUDE       "math.asm"                  ; Divide, Multiply, Exp Table
#INCLUDE       "eeprom.asm"                ; EEPROM Zugriffsroutinen
#INCLUDE       "io.asm"                    ; all I/O
#INCLUDE       "audio.asm"                 ; Audio related subroutines (NCO, DAC, etc)
#INCLUDE       "int.asm"                   ; Interrupt Service Routines
;#INCLUDE       "debug.asm"                 ; Debugmodul
#INCLUDE       "isu.asm"                   ; In System Update Modul
               .end
