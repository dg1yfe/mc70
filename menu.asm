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
;*****************************
; M E N U
;*****************************
;
; Die komplette Menüsteuerung der Software
;
; menu_init - Initialisiert State & Menu Timer ( nix | nix )
; menu - komplette Menu-Steuerung, User Interface
;
;
;
;
;
; Tastencodes nach "Key-Convert" Tabelle ( 0 - 9 = Numerische Tasten)
;
#DEFINE KC_NON_NUMERIC 10

#DEFINE KC_D1 11
#DEFINE KC_D2 12
#DEFINE KC_D3 13
#DEFINE KC_D4 14
#DEFINE KC_D5 15
#DEFINE KC_D6 16
#DEFINE KC_D7 17
#DEFINE KC_D8 18
#DEFINE KC_RAUTE 19
#DEFINE KC_STERN 10
;
#DEFINE KC_CLEAR KC_D4
;
#DEFINE HD2_ENTER 8
#DEFINE HD2_EXIT  5
;
#DEFINE HD2_UP KC_D1
#DEFINE HD2_DN KC_D2
;
#DEFINE HD3_ENTER KC_RAUTE
#DEFINE HD3_EXIT  KC_STERN
;
; Menu
#DEFINE IDLE  	     0
#DEFINE F_IN 	     1
#DEFINE MEM_SELECT   2
#DEFINE MEM_STORE    3
#DEFINE MEM_RECALL_LOAD 4
#DEFINE TXSHIFT_SW   5
#DEFINE MENU_SELECT  6
#DEFINE DEFCH_SELECT  7
#DEFINE M_VERSION    8
#ifdef EVA9
#DEFINE POWER_SELECT  9
#endif
#DEFINE CTCSS_SEL_RX 10
#DEFINE CTCSS_SEL_TX 11
#DEFINE DTMF_IN      12
;#DEFINE MEM_SEL_DIGIT 5
;
;
;*****************************
; I N I T _ M E N U
;*****************************
menu_init
                ldaa #IDLE
                staa m_state         ; begin in IDLE state
                clr  m_timer_en      ; disable menu timer

                clr  m_svar1
                clr  m_svar2

                clr  io_menubuf_r
                clr  io_menubuf_w    ; Zeiger von Eingabepuffer auf 0

                clr  mem_bank
#ifdef EVA5
                oim  #SQM_CARRIER,sql_mode    ; start with carrier squelch
#endif
#ifdef EVA9
                oim  #SQBIT,sql_mode           ; Squelch aktiviert
#endif
                ldab #2
                ldaa #1
                jsr  arrow_set

#ifdef EVA9
                aim  #~BIT_PWRMODE,pwr_mode    ; Power Hi
                ldab #3
                ldaa #1
                jsr  arrow_set
#endif
                rts
;
;*****************************
; M E N U
;*****************************
;
; "Menü" Subroutine
;
; Steuert die komplette Bedienung des Gerätes
; Frequenzeingabe, Speicherkanalwahl, etc.
;
; Parameter : none
;
; Ergebnis : none
;
; changed Regs : A,B,X
;
;
;************************
; Stack depth on entry: 2
;
menu
                jsr  sci_rx_m
                tsta
                bpl  m_keypressed
                jmp  m_end
m_keypressed
                pshb                             ; save key
		        ldab m_state                     ; Status holen
                aslb
                ldx  #m_state_tab                ; Tabellenbasisadresse holen
                abx
                pulb                             ; Tastenwert wiederholen
                cpx  #m_state_tab_end
                bcc  m_break                     ; sicher gehen dass nur existierende States aufgerufen werden
                ldx  0,x                         ; Adresseintrag aus Tabelle lesen
                jmp  0,x                         ; Zu Funktion verzweigen
m_break
                jmp  m_end

m_state_tab
               .dw m_top             ; Top Menu
               .dw m_f_in            ; Frequenzeingabe
               .dw m_mem_select      ; Memory Slot auswählen
               .dw m_store
               .dw m_recall_load
               .dw m_txshift
               .dw m_menu_select
               .dw m_defch_select
               .dw m_end_restore
#ifdef EVA9
               .dw m_power_select
#endif
#ifdef EVA5
               .dw m_none            ; dummy
#endif
               .dw m_none            ; CTCSS SEL RX
               .dw m_ctcss_submenu   ; CTCSS SEL TX
               .dw m_dtmf_input
m_state_tab_end

;*************
; M   N O N E
;
; Dont do anything
;
m_none
                jmp  m_end            ; Nix zu tun dann nix machen


;***********
; M   E N D
;***********
m_end
                ldab m_timer_en   ; timer disabled ?
                beq  m_return     ; Dann nichts tun...

                ldx  m_timer      ; menu timer holen
                bne  m_return     ; timer nicht abgelaufen, dann return
m_end_restore
                clr  m_timer_en   ; timer disable
                jsr  restore_dbuf ; Displayinhalt wiederherstellen
                ldab #IDLE        ; Zurück zum Idle State
                stab m_state      ; State speichern
                clr  m_svar1      ; clear menu state variables
                clr  m_svar2
m_return
                rts


;**************************************
;
m_reset_timer                         ; Eingabe Timeout zurücksetzen
                pshb
                ldab #MENUTIMEOUT>>8
                sei
                stab m_timer
                ldab #MENUTIMEOUT%256
                stab m_timer+1
                cli
                ldab #1
                stab m_timer_en       ; timer aktivieren
                pulb
                rts
;
;**************************************

m_ok           .db "OK",0
m_no_lock_str  .db "NO LOCK ",0
m_out_str      .db "out of",0
m_range_str    .db "Range ",0
m_writing      .db "writing",0
m_stored       .db "stored",0
m_failed       .db "failed",0
m_delete       .db "deleting",0
m_offset       .db "TXSHIFT",0
m_sq_on_str    .db "SQ ON",0
m_sq_off_str   .db "SQ OFF",0
m_off_str      .db "OFF",0
m_ctcss_hz_str .db "%s HZ",0

key_convert
               .db  00
               .db  KC_D1 ;D1
               .db  KC_D2 ;D2
               .db  KC_D3 ;D3
               .db  KC_D4 ;D4
               .db  KC_D5 ;D5
               .db  KC_D6 ;D6
               .db  KC_D7 ;D7
               .db  KC_D8 ;D8
               .db  03 ; 3
               .db  06 ; 6
               .db  09 ; 9
               .db  19 ; #
               .db  02 ; 2
               .db  05 ; 5
               .db  08 ; 8
               .db  00 ; 0
               .db  01 ; 1
               .db  04 ; 4
               .db  07 ; 7
               .db  10 ; *

#INCLUDE        "menu_top.asm"
#INCLUDE        "menu_mem.asm"
#INCLUDE        "menu_input.asm"
#INCLUDE        "menu_sub.asm"
;#INCLUDE        "menu_config.asm"
