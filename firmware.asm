;****************************************************************************
;
;    MC70 - Firmware for the Motorola MC micro trunking radio
;           to use it as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2013  Felix Erckenbrecht, DG1YFE
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
;#define DEBUG
#define RELEASE
#INCLUDE "macros.asm"           ; include macros & definitions
#INCLUDE "regmem.asm"           ; Portadresses & Random Access Memory
#include "audio_tabs.asm"
;
;**************************
; S T A R T   O F   R O M
;**************************
#ifdef EVA5
                .ORG $2000
#endif
#ifdef EVA9
                .ORG $C000
#endif
rom
;********************************
; S T A R T   O F   S Y S T E M
;********************************
               .ORG $C000                 ; start at $C000, lowest address accessible in EVA9 without HW mod
                                          ; (EPROM A14 & A15 are tied to VCC)
reset
               lds  #STACK1               ; initialize stackpointer 1
               jsr  io_init               ; initialize I/O (Ports, I2C, etc...)
#ifdef TESTUNIT
               jsr  tests                 ; call code test routines (if compiled for test)
               bra  $                     ; loop here
#endif
;               jsr  chk_debug             ; Debugmodus ?
#ifdef EVA5
               jsr  chk_isu               ; In System Update? ?
#endif
               clrb                       ; do not try to store frequency to EEPROM before power-off
               jsr  pwr_sw_chk            ; check power switch - put CPU to standby if radio is switched off

;************************************
;************************************
Start
               jsr  sci_init              ; serielle Schnittstelle aktivieren
               jsr  init_SIO              ; SIO Interrupt konfigurieren
               jsr  init_OCI              ; Timer Interrupt starten
               jsr  ui_init               ; 2. Task initialisieren (2. Stack)
                                          ; ab hier k�nnen I/O Funktionen verwendet werden
#ifdef EVA9
               jsr  io_init_second        ; Initialize shift register, activate external EEPROM
#endif
               ldd  #FSTEP                ; Kanalraster holen
               jsr  pll_init              ; init PLL

               ldab #1
               stab tasksw_en             ; Taskswitch verbieten

               cli
#ifdef EVA5
               oim  #SQBIT_C, sql_mode
#endif
#ifdef EVA9
               oim  #SQBIT, sql_mode      ; Squelch Input auf jeden Fall pr�fen und neu setzen
#endif

#ifdef SIM
	ldaa #2
	staa cfg_head
	ldd  #0
	jsr  tone_start
sim_loop
	bra  sim_loop
#endif
               jsr  lcd_h_reset           ; LCD Hardware Reset - gibts bei EVA9 nicht
               clr  bus_busy              ; Watchodog Reset durch Timer Interrupt zulassen

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

               clr  tasksw_en              ; Taskswitch sp�testens jede Millisekunde

               ldab #GRN_LED+LED_ON
               jsr  led_set                ; Gr�ne LED aktivieren

               WAIT(200)
               jsr  s_timer_init

;
;
;***************
start_over
                jsr  receive                ; Empf�nger aktivieren

                ldab #1
                jsr  pll_led                ; check pll state and enforce LED update

                ldaa #~SR_RXAUDIO           ; disable RX Audio
                ldab #SR_AUDIOPA
                jsr  send2shift_reg         ; enable Audio PA

loop
                ldab cfg_defch_save         ; Frequenz etc. speichern wenn Ger�t ausgeschaltet wird
                andb #BIT_DEFCH_SAVE
                jsr  pwr_sw_chk             ; Ein/Ausschalter abfragen & bedienen
;*** TRX check
                jsr  ptt_get_status         ; PTT Status abfragen
                asla                        ; H�chstes Bit ins Carryflag schieben
                bcc  trc_end                ; War es gesetzt fand eine Status�nderung statt
                bne  trc_tx                 ; Ist es <>0 wird jetzt gesendet
; RX
                jsr  receive                ; Empf�nger aktivieren
                bra  trc_end
; TX
trc_tx
                jsr  transmit               ; Sender aktivieren
trc_end
;****
                jsr  squelch                ; Squelch bedienen
ml_sql_end
                swi
                clra
                jsr  pll_led                ; show pll lock state on red LED
                jsr  frq_check              ; �berpr�fen ob Frequenz ge�ndert werden soll
                jsr  wd_reset
                jsr  s_timer_update
                jmp  loop


;*******************


;*************************************************************************
; INCLUDES
#ifdef TESTUNIT
#INCLUDE       "tests.asm"
#endif
#INCLUDE       "ui.asm"                    ; User Interface (2nd Task)
#INCLUDE       "menu.asm"                  ; User Interface / Menus
#INCLUDE       "subs.asm"                  ; miscellaneous subroutines
#INCLUDE       "timer.asm"                 ; Time/Timer related subroutines
#INCLUDE       "pll_freq.asm"              ; PLL & Frequency related Subroutines
#INCLUDE       "display.asm"               ; LC Display related Subroutines
#INCLUDE       "mem.asm"                   ; Memory related Subroutines
#INCLUDE       "math.asm"                  ; Math related subroutines (Division, Multiplication, Exponentiation)
#INCLUDE       "eeprom.asm"                ; I2C EEPROM related routines
#INCLUDE       "io.asm"                    ; everything related to I/O
#INCLUDE       "audio.asm"                 ; audio related subroutines (NCO, DAC, etc)
#INCLUDE       "int.asm"                   ; Interrupt Service Routines
;#INCLUDE       "debug.asm"                 ; Debugmodul
#ifdef EVA5
#INCLUDE       "isu.asm"                   ; In System Update Modul
#endif
               .end
