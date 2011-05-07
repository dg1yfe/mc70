;****************************************************************************
;
;    MC 70   v1.6   - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2010  Felix Erckenbrecht, DG1YFE
;
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
                .ORG $C000                 ;
reset
                lds  #STACK1               ; Stackpointer 1 setzen
#ifdef SIM
	ldaa #2
	staa cfg_head
        jsr  m_menu
sim_menu_lp
	jsr  menu
	ldab #0
	ldaa #0
	bra  sim_menu_lp
#endif
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
                jsr  lcd_h_reset           ; LCD Hardware Reset
		jsr  lcd_s_reset           ; LCD Software Reset + Init

                jsr  freq_init             ; Frequenzeinstellungen initialisieren
                psha

                jsr  ui_start               ; UI Task starten

                clr  tasksw_en              ; Taskswitch spätestens jede Millisekunde

                ldab #GRN_LED+LED_ON
                jsr  led_set                ; Grüne LED aktivieren

                ldab #2
                stab cfg_head
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
                clrb                        ; Frequenz etc. speichern wenn Gerät ausgeschaltet wird
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
