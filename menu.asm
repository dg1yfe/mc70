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
; Menu
#DEFINE IDLE  	     0
#DEFINE F_IN 	     1
#DEFINE D_FULL 	     2
#DEFINE MEM_SEL_SLOT 3
#DEFINE MEM_STORE    4
#DEFINE TXSHIFT_SW   5
;
;
;*****************************
; I N I T _ M E N U
;*****************************
menu_init
                pshb
                psha
                ldaa #IDLE
                staa m_state         ; begin in IDLE state
                clr  m_timer_en      ; disable menu timer

                clr  io_menubuf_r
                clr  io_menubuf_w    ; Zeiger von Eingabepuffer auf 0

                clr  mem_bank

                ldab #$40
                stab sql_mode               ; Squelch mode
                ldab #2
                ldaa #1
                jsr  arrow_set

                pula
                pulb
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
; changed Regs : none
;
;
;************************
;
menu
                pshb
                psha
                pshx

                jsr  sci_rx_m
                tsta
                beq  m_keypressed
                jmp  m_end
m_keypressed
                ldx  #key_convert                ; index key convert table
                abx
                ldaa 0,x                         ; Key übersetzen
                psha                             ; Wert speichern

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
                .dw m_idle            ; IDLE
                .dw m_f_in            ; Frequenzeingabe
                .dw m_d_full          ; Display voll
                .dw m_sel_slot        ; Memory Slot auswählen
                .dw m_store
                .dw m_txshift
m_state_tab_end
;*******************************
; M   I D L E
;
m_idle
                cmpb #$10             ; Zahl?
                bcs  m_start_input    ; Start der Eingabe
                subb #$10
                aslb                  ; Index für Tabelle erzeugen
                ldx  #m_idle_tab      ; Basisadresse holen
                abx                   ; Index addieren
                ldx  0,x              ; Tabelleneintrag holen

                jmp  0,x              ; Funktion aufrufen

m_idle_tab
;               Funktion                Taste
                .dw m_none            ; *
                .dw m_frq_up          ; D1 - Kanal+
                .dw m_frq_down        ; D2 - Kanal-
                .dw m_sql_switch      ; D3 - Squelch ein/aus
                .dw m_prnt_rc         ; D4 - Control Task Schleifendurchläuft per sek. ausgeben
;                .dw m_prnt_tc         ; D4 - Taskswitches/s anzeigen
                .dw m_tone            ; D5 - 1750 Hz Ton
                .dw m_test            ; D6 -
                .dw m_txshift         ; D7 - TX Shift ändern
                .dw m_sel_mbank       ; D8 - Speicherbank wählen
                .dw m_frq_store       ; #
;                .dw m_sel_mbank       ; #
m_none
                jmp  m_end            ; Nix zu tun dann nix machen

;*******************************
; M   S T A R T   I N P U T
;
; Frequenzeingabe über ZIffernfeld starten
;
;
m_start_input
                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
                clra
                jsr  lcd_clr          ; Display löschen
m_print
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
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
                jmp  m_end            ; Zurück
;
;**********************************
; M   B A C K S P A C E
;
; eingegebenes Zeichen löschen
;
m_backspace
                jsr  m_reset_timer
                jsr  lcd_backspace    ; zuletzt eingegebenes Zeichen auf dem Display
                ldab cpos
                ldx  #f_in_buf        ; und im Frequenzeingabepuffer löschen
                abx
                clr  0,x              ; String im Frequenzeingabe-Puffer terminieren
                jmp  m_end            ; Zurück

;**********************************
; M   D   F U L L
;
; Display voll, Zifferneingabe ignorieren
;
m_d_full                                   ; Display voll, Zifferneingabe ignorieren
                jsr  m_reset_timer
                cmpb #10                   ; keine Zahl?
                bcc  m_non_numeric         ; dann irgendwas machen
                jmp  m_end                 ; ansonsten ignorieren
;**********************************
; M   F   I N
;
; Frequenzeingabe, Eingabe entgegennehmen
;
m_f_in
                cmpb #$10                  ; Zahl?
                bcc  m_non_numeric         ; Wenn nicht, dann entsprechende Funktionen ausführen
                ldaa cpos                  ; sonst nachsehen
                cmpa #08 		   ; ob noch Platz im Display
		bne  m_print		   ; Wenn ja, Zeichen ausgeben und in Frequenzeingabepuffer speichern
		ldaa #D_FULL		   ; Display voll, state anpassen
		staa m_state
                jmp  m_end

;**********************************
; M   C L R   D I S P L
;
; Display und Eingabe löschen
;
m_clr_displ
                jsr  m_reset_timer
                clra
                jsr  lcd_clr
                clr  f_in_buf              ; Erstes Zeichen im Eingabebuffer auf 0 (Buffer "leer")
                jmp  m_end

;**********************************
; M   N O N   N U M E R I C
;
; Nicht numerische Taste während Frequenzeingabe auswerten
;
m_non_numeric

                ldx  #mnn_tab              ; Basisadresse der Tabelle holen
                subb #$10
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
                pshx                  ; für Ergebnis der Frequenzberechnung

                tsx                   ; Zeiger auf Zwischenspeicher (Stack) nach X
                ldd  #f_in_buf        ; Zeiger auf Eingabestring holen
                jsr  frq_calc_freq    ; Frequenz berechnen

                tsx                   ; Zeiger auf Frequenz DWord nach X
                xgdx                  ; Zeiger von X nach D

                ldx  frequency+2      ; aktuell gesetzte Frequenz holen
                pshx
                ldx  frequency
                pshx                  ; und sichern
                xgdx                  ; Frequenzzeiger wieder nach X

                jsr  frq_update       ; Control Task mitteilen, dass neue Frequenz gesetzt wurde
                clra
                jsr  lcd_clr          ; LCD löschen
                ldab #IDLE
                stab m_state          ; nächster State ist wieder IDLE

;                bra  m_lock
                ldab #200             ; Universaltimer auf 200ms setzen
                stab gp_timer         ; solange hat die PLL maximal Zeit um eizurasten
m_wait_lock
                ldab pll_locked_flag  ; Ist die PLL eingerastet?
                andb #$7F             ; 'changed' Bit ausblenden. No Lock -> B=0
                bne  m_lock           ; PLL ist eingerastet -> loop beenden
                ldab gp_timer         ; gp_timer!=0 ?
                bne  m_wait_lock      ; dann loop

m_no_lock
                PRINTF(m_no_lock_str) ; Fehlermeldung ausgeben
                WAIT(500)             ; 500ms warten
                tsx
                jsr  frq_update       ; Control Task mitteilen, dass neue Frequenz gesetzt wurde - alte Frequenz wiederholen
                pulx
                pulx
                clra
                jsr  lcd_clr
                bra  m_frq_prnt

                ldx  #0
                stx  m_timer          ; Menü Timer auf 0 setzen
                                      ; Displayinhalt am Routinenende wiederherstellen
                bra  msf_end          ; zum Ende springen
m_lock
                pulx
                pulx                  ; alte Frequenz vom Stack löschen
                PRINTF(m_ok)          ; "OK" ausgeben - PLL ist eingerastet
                WAIT(200)             ; 200ms warten
m_frq_prnt
                clrb
                jsr  lcd_cpos         ; cursor auf pos 0 setzen

                ldx  #frequency       ; Adresse von Frequenz Word holen
                jsr  freq_print       ; Frequenz ausgeben
                jsr  freq_offset_print; Offset anzeigen
                jsr  lcd_fill         ; Display mit Leerzeichen füllen (schneller als löschen und dann schreiben)

                clr  m_timer_en       ; Menü Timer disabled - Aktuelles Display = neues Display
                pshb
                psha
                clr  pll_timer        ; PLL Timer auf 0
                pula
                pulb
msf_end
                pulx
                pulx                  ; eingegebene Frequenz vom Stack löschen
                jmp  m_end
;*******************************
; M   F R Q   U P
;
; Frequenz einen Kanal nach oben
;
m_frq_up
                ldab rxtx_state
;                bne  mfu_end
                ldx  frequency+2
                pshx
                ldx  frequency
                pshx
                ldx  #0
                ldd  #FSTEP
                jsr  add32
                tsx
                jsr  frq_update
                jmp  m_frq_prnt

mfu_end
                jmp  m_end
;*******************************
; M   F R Q   D O W N
;
; Frequenz einen Kanal nach unten
;
m_frq_down
                ldab rxtx_state
;                bne  mfd_end
                ldx  frequency+2
                pshx
                ldx  frequency
                pshx
                ldd  #FSTEP
                ldx  #0
                jsr  sub32
                tsx
                jsr  frq_update
                jmp  m_frq_prnt
mfd_end
                jmp  m_end
;*******************************
; M   S Q L   S W I T C H
;
; Squelchumschaltung Carrier/RSSI/Aus
;
; Carrierlevel wird am Demod IC eingestellt,
; RSSI-Level auf der RSSI Platine
; Carriersquelch lässt niedrigere Schwelle zu als RSSI Squelch
;
m_sql_switch
                ldab sql_mode
                bmi  mss_none          ; RSSI -> None
                lslb
                bmi  mss_rssi          ; Carrier -> RSSI
mss_carrier                            ; Carrier Squelch Pin auswerten
                ldab #$40
                stab sql_mode
                ldaa #1
                ldab #2
                jsr  arrow_set
                bra  mss_end
mss_rssi                               ; RSSI Pin auswerten
                ldab #$80
                stab sql_mode
                ldaa #2
                ldab #2
                jsr  arrow_set
                bra  mss_end
mss_none                               ; Raussperre deaktivieren
                ldab #$20
                stab sql_mode
                ldaa #0
                ldab #2
                jsr  arrow_set
mss_end
                jmp  m_end
;**************************************
; M   P R N T   R C
;
; Anzahl der Hauptschleifendurchläufe in der letzten Sekunde anzeigen
;
m_prnt_rc
                ldab m_timer_en       ; Falls Roundcount noch angezeigt wird, Displayinhalt NICHT speichern
                bne  mpr_nosave       ; Sondern Zahl erneut ausgeben

                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
mpr_nosave
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
                clrb
                jsr  lcd_cpos         ; Cursor Home
                ldx  rc_last_sec      ; Rundenzähler holen

                clrb
                pshx
                pshb
                pshb
                ldaa #'l'
                jsr  putchar
                pulx
                pulx

                jsr  lcd_fill         ; restliches Display mit Leerzeichen füllen
                jmp  m_end
;**************************************
; M   T E S T
;
;
m_test
                jmp  m_end


;**************************************
; M   P R N T   T C
;
; Anzahl der Taskswitches in der letzten Sekunde anzeigen
;
m_prnt_tc
                ldab m_timer_en       ; Falls Roundcount noch angezeigt wird, Displayinhalt NICHT speichern
                bne  mtc_nosave       ; Sondern Zahl erneut ausgeben

                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
mtc_nosave
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
                clrb
                jsr  lcd_cpos         ; Cursor Home
                ldx  ts_last_s        ; Rundenzähler holen
                clrb
                pshx
                pshb
                pshb
                ldaa #'l'
                jsr  putchar
                pulx
                pulx
                jsr  lcd_fill         ; restliches Display mit Leerzeichen füllen
                jmp  m_end

;**************************************
; M   F R Q   S T O R E
;
; Eingestellte Frequenz und TX Shift im EEPROM speichern
;
m_frq_store
                ldab m_timer_en
                bne  mfs_nosave
                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern

mfs_nosave
                jsr  store_current
                tsta                     ; Schreiben erfolgreich?
                bne  mfs_fail

                clrb
                jsr  lcd_cpos            ; Display löschen
                PRINTF(m_stored)         ; 'STORED' ausgeben
                jsr  lcd_fill
                WAIT(1000)               ; 1sek warten
                ldx  #dbuf2
                jsr  restore_dbuf        ; Displayinhalt wiederherstellen
                jmp  m_end               ;
mfs_fail
                psha                     ; Fehlerstatus sichern
                clra
                jsr  lcd_clr             ; Display löschen
                PRINTF(m_failed)         ; 'FAILED' ausgeben
                WAIT(500)                ; 500 ms warten
                pulb
                ldaa #'x'
                jsr  putchar             ; Fehlercode ausgeben
                WAIT(1000)               ; 1s warten
                ldx  #dbuf2
                jsr  restore_dbuf        ; Displayinhalt wiederherstellen
                jmp  m_end               ;

;**************************************
; M   T X   S H I F T
;
; Anzeige der aktuellen TX Shift
;
m_txshift
                ldaa m_timer_en       ; Falls Roundcount noch angezeigt wird, Displayinhalt NICHT speichern
                bne  mts_nosave       ; Sondern Zahl erneut ausgeben

                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
mts_nosave
                ldaa m_state
                cmpa #TXSHIFT_SW      ; Wurde Taste zum ersten Mal gedrückt?
                beq  mts_switch       ; Nein, dann nächste Shift auswählen
                                      ; Andernfalls aktuelle Shift ausgeben
                ldab #TXSHIFT_SW
                stab m_state

                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)

                clrb
                jsr  lcd_cpos
                PRINTF(m_offset)
                jsr  lcd_fill
                WAIT(100)
                ldx  offset+2
                pshx
                ldx  offset
                pshx
mts_print
                clrb
                jsr  lcd_cpos
                pulb
                pshb
                tstb
                bpl  mts_pos_shift    ; Vorzeichen prüfen
                pulx
                pula
                pulb
                jsr  sig_inv32        ; Vorzeichen umkehren
                pshb
                psha
                pshx                  ; Offset auf Stack speichern
                ldab #'+'
                bra  mts_print_offset
mts_pos_shift
                ldab #'-'
mts_print_offset
                ldaa #'c'
                jsr  putchar          ; Vorzeichen ausgeben
                ldab #3
                ldaa #'l'
                jsr  putchar          ; aktuelle TX Shift ausgeben
                pulx
                pulx
                jsr  lcd_fill
                jsr  freq_offset_print
                jmp  m_end
;*********************
; M T S   S W I T C H
;
; Aktivieren/Deaktivieren der Ablage, Vorzeichenwahl (+/-)
;
;
mts_switch
                cmpb #KC_STERN
                beq  mts_chg_sign
                cmpb #KC_D7           ; 'A'?
                beq  mts_toggle
                cmpb #KC_RAUTE
                bne  mts_to_idle      ; Bei allen anderen Tasten zu IDLE zurückkehren
                ldx  #0
                stx  m_timer
                jmp  m_end
mts_to_idle
                ldx  #dbuf2
                jsr  restore_dbuf     ; Displayinhalt wiederherstellen
                jmp  m_idle           ; Mit Frequenzeingabe weitermachen
mts_toggle
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
                ldx  offset
                bne  mts_to_zero
                ldx  offset+2
                bne  mts_to_zero
                ldx  txshift+2
                stx  ui_txshift+2
                pshx
                ldx  txshift
                stx  ui_txshift
                pshx
                swi
                bra  mts_print
mts_to_zero
                ldx  #0
                stx  ui_txshift+2
                stx  ui_txshift
                swi
                pshx
                pshx
                bra  mts_print
mts_chg_sign
                ldx  offset
                ldd  offset+2
                jsr  sig_inv32        ; Vorzeichen umkehren
                std  txshift+2
                stx  txshift
                std  ui_txshift+2
                stx  ui_txshift
                swi
                pshb
                psha
                pshx                  ; Offset auf Stack speichern
                jmp  mts_print
mts_end
                jmp  m_end
;**************************************
; M   S E T   S H I F T
;
; TX Shift per Direkteingabe setzen
;
m_set_shift
                ldab cpos
                inc
                ldx  #f_in_buf
                abx
                clr  0,x              ; Eingabe mit 0 terminieren

                pshx                  ; 32 Bit Platz schaffen auf Stack
                pshx                  ; für Ergebnis der Frequenzberechnung

                tsx                   ; Zeiger auf Zwischenspeicher (Stack) nach X
                ldd  #f_in_buf        ; Zeiger auf Eingabestring holen
                jsr  frq_calc_freq    ; Frequenz berechnen
                ldd  #100             ; durch 100 teilen, da erste Ziffer der Eingabe als *10^8 (100 Mio) betrachtet wird
                jsr  divide32
                tsx
                ldd  0,x
                std  txshift
                std  ui_txshift
                ldd  2,x
                std  txshift+2
                std  ui_txshift+2
                swi
                ldab #IDLE
                stab m_state
                ldd  #8
                std  m_timer          ; noch 800ms warten bevor wieder Frequenz angezeigt wird
                jmp  mts_print


;**************************************
; M   T O N E
;
; 1750 Hz Ton ausgeben
;
m_tone
                ldab #1
                stab ui_ptt_req        ; PTT drücken
                ldab #6
                stab tone_timer        ; 0,6 sek Ton ausgeben
                jsr  tone_start

                jmp  m_end
;**************************************
; M   S E L   M B A N K
;
; Speicherbank für Frequenzspeicherplätze wählen
;
m_sel_mbank
                ldab m_timer_en       ;
                bne  msm_nosave       ;
                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
msm_nosave
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
                ldaa #MEM_SEL_SLOT    ; Memory Slot Auswahl beginnt
		staa m_state
msm_show_bank
                clrb
                jsr  lcd_cpos         ; Cursor Position 0
                PRINTF(m_membank_str) ;
                ldab mem_bank         ; ausgewählte Bank holen
                ldaa #'u'             ; Bank1
                jsr  putchar
                jmp  m_end

;**************************************
; M   S E L   S L O T
;
; Frequenzspeicherplatz aus EEPROM lesen
;
m_sel_slot
                jsr  m_reset_timer     ; Menü-Timer Reset (Timeout für Eingabe setzen)
                cmpb #$10
                bcs  msl_sel_slot      ; numerische Eingabe? Dann Kanal holen

                cmpb #KC_D8
                beq  msl_nxt_bank      ; Bei D6 nächste Speicherbank wählen
                cmpb #KC_RAUTE
                beq  msl_store         ; # = Eingestellte Frequenz und Offset speichern
                jmp  m_end
msl_sel_slot
                pshb                   ; Eingabe (0-9) sichern
                ldaa mem_bank         ; Bank holen (0 oder 1)
                ldab #10
                mul                    ; *10 -> 0 oder 10
                pula                   ;
                aba                    ; Eingabe addieren (Slotnummer berechnen)
                tab                    ; nach B
                cmpb #25               ; Kanalnummer >25 ?
                bcs  msl_read_eep
                jmp  m_end
msl_read_eep
                pshx
                pshx                   ; DWord für Frequenz auf Stack reservieren
                tsx
                jsr  read_eep_ch       ; Kanal aus EEPROM holen
                jsr  frq_update        ; Frequenz setzen
                ldab #IDLE
                stab m_state           ; nächster State ist wieder IDLE
                jmp  m_frq_prnt
msl_nxt_bank
                ldab mem_bank          ; aktuelle Kanal-Speicherbank holen
                incb
                cmpb #3
                bcs  msl_show_bank
                clrb
msl_show_bank
                stab mem_bank          ; Bank speichern
                bra  msm_show_bank     ; und anzeigen lassen
msl_store
                ldab #MEM_STORE
                stab m_state
                clrb
                jsr  lcd_cpos
                PRINTF(m_slot_str)     ; "SLOT?" ausgeben
                jmp  m_end
;**************************************
; M   S T O R E
;
; aktuell eingestellte Frequenz und Ablage im EEPROM speichern
;
m_store
                jsr  m_reset_timer     ; Menü-Timer Reset (Timeout für Eingabe setzen)
                cmpb #$10
                bcs  mst_sel_slot      ; numerische Eingabe? Dann Kanal holen
                cmpb #KC_D4            ; 'C' bricht ab
                beq  mst_end
                jmp  m_end
mst_sel_slot
                pshb                   ; Eingabe (0-9) sichern
                ldaa mem_bank          ; Bank holen (0 oder 1)
                ldab #10
                mul                    ; *10 -> 0 oder 10
                pula                   ;
                aba                    ; Eingabe addieren (Slotnummer berechnen)
                tab                    ; nach B
                cmpb #25               ; Kanalnummer >25 ?
                bcc  mst_end
                jsr  store_eep_ch      ; Kanal speichern
                tsta
                beq  mst_end           ; Falls Fehler aufgetreten
                clrb
                jsr  lcd_cpos
                PRINTF(m_failed)       ; "Failed" ausgeben
                WAIT(500)

mst_end
                ldx  #0                ; Timeout Timer auf 0
                stx  m_timer
                jmp  m_end
;
;***********
; M   E N D
;***********
m_end
                ldab m_timer_en   ; timer disabled ?
                beq  m_return     ; Dann nichts tun...

                ldx  m_timer      ; menu timer holen
                bne  m_return     ; timer nicht abgelaufen, dann return
                clr  m_timer_en   ; timer disable
                ldx  #dbuf2
                jsr  restore_dbuf ; Displayinhalt wiederherstellen
                ldab #IDLE        ; Zurück zum Idle State
                stab m_state      ; State speichern
m_return
                pulx
                pula
                pulb
                rts
;**************************************
;
m_reset_timer                         ; Eingabe Timeout zurücksetzen
                pshx
                pshb
                ldx  #MENUTIMEOUT     ; Eingabe Timeout im 100ms
                stx  m_timer
                ldab #1
                stab m_timer_en       ; timer aktivieren
                pulb
                pulx
                rts
;
;**************************************

m_ok            .db "OK",0
m_no_lock_str   .db "NO LOCK ",0
m_out_str       .db "out of",0
m_range_str     .db "Range ",0
m_writing       .db "writing",0
m_stored        .db "stored",0
m_failed        .db "failed",0
m_delete        .db "deleting",0
m_offset        .db "TXSHIFT",0
m_slot_str      .db "SLOT? ",0
m_sq_on_str     .db "SQ ON",0
m_sq_off_str    .db "SQ OFF",0
m_membank_str   .db "MEMBNK ",0
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

