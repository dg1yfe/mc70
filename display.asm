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
;******************************
; L C D   S U B R O U T I N E N
;******************************
;
; lcd_h_reset   - Hardware Reset des LCD ( nix | nix )
; lcd_s_reset   - LCD Warmstart, Reset Kommando an LCD Controller senden ( nix | nix )
; lcd_backspace - Zeichen links vom Cursor löschen
; lcd_clr       - Löscht Inhalt des Displays und des Buffers
; save_dbuf     - Sichert Displaybuffer ( X - Zieladresse | nix )
; restore_dbuf  - Stellt Displaybuffer wiederher ( X - Quelladresse | nix )
;
;
;
;
;***********************
; L C D _ H _ R E S E T
;***********************
;
lcd_reset
                pshb
                psha
                pshx
                jsr  lcd_h_reset       ; Hardware Reset durchführen

                ldx  #pc_char_out
                stx  char_vector

                ldx  #pc_ext_send2
                stx  plain_vector

                ldd  #2000             ; 2 sek auf Display warten
                std  lcd_timer

lcr_empty_buf
                jsr  sci_rx
                tsta
                bne  lcs_empty_buf

lcr_wait_res
                ldd  lcd_timer
                beq  lcr_no_lcd         ; Falls 2 Sekunden vergangen, abbrechen
                jsr  sci_rx
                tsta
                beq  lcr_wait_res
                cmpb #$7E               ; Reset Poll Char?
                bne  lcs_wait_res       ; Nein, dann nochmal

                sei
                ldab io_inbuf_w
                stab io_inbuf_r
                cli

                ldab #$7E
                jsr  sci_tx

                sei
                ldab io_inbuf_w
                stab io_inbuf_r
                cli

                ldaa #1
;               jsr  lcd_clr            ; LEDs, LCD und Display Buffer löschen

                clr  cpos               ; Reset CPOS (Cursor auf Pos. 0 setzen)
                ldx  #dbuf
                ldd  #$2020
                std  0,x
                std  2,x
                std  4,x
                std  6,x                ; clear Display Buffer (fill with "Space")

                pulx
                pula
                pulb
                rts
lcr_no_lcd

;***********************
; L C D _ H _ R E S E T
;***********************
;
; Hardware Reset des LCD
; (Initialisierung / Software Reset zusätzlich nötig)
;
lcd_h_reset
                pshb
                psha

                ldaa  #%11111111
                ldab  #%100
                jsr   send2shift_reg ; LCD Reset Leitung auf High (=Reset)

                ldaa  #%11111011
                ldab  #0
                jsr   send2shift_reg ; und wieder low

                pula
                pulb
                rts

;***********************
; L C D _ S _ R E S E T
;***********************
;
; LCD Warmstart - Reset Kommando an LCD Controller senden
;
lcd_s_reset
                pshb
                psha
                pshx

                ldd  #0
                std  lcd_timer

                ldx  #pc_char_out
                stx  char_vector

                ldx  #pc_ext_send2
                stx  plain_vector

lcs_empty_buf
                jsr  sci_rx
                tsta
                bne  lcs_empty_buf

lcs_wait_res
               jsr  sci_read
               cmpb #$7E               ; Reset Poll Char?
               bne  lcs_wait_res       ; Nein, dann nochmal

               sei
               ldab io_inbuf_w
               stab io_inbuf_r
               cli

               ldab #$7E
               jsr  sci_tx
;               WAIT(50)

               sei
               ldab io_inbuf_w
               stab io_inbuf_r
               cli

               ldaa #1
;               jsr  lcd_clr            ; LEDs, LCD und Display Buffer löschen

               clr  cpos               ; Reset CPOS (Cursor auf Pos. 0 setzen)
               ldx  #dbuf
               ldd  #$2020
               std  0,x
               std  2,x
               std  4,x
               std  6,x                ; clear Display Buffer (fill with "Space")


               pulx
               pula
               pulb
               rts

;*******************
; L C D _ C L R
;*******************
;
; Löscht Inhalt des Displays und des Buffers
;
;
; Parameter    : A - 1 = LEDs löschen, 0 = nur Display
;
; Ergebnis     : none
;
; changed Regs : none
;
lcd_clr
               pshb
               psha
               pshx

               psha

               ldab #$78
               ldaa #'p'
               jsr  putchar

               clr  cpos              ; Reset CPOS (Cursor auf Pos. 0 setzen)

               ldx  #dbuf
               ldd  #$2020
               std  0,x
               std  2,x
               std  4,x
               std  6,x               ; clear Display Buffer (fill with "Space")
               clr  arrow_buf

               pula                   ; Wenn A<>0, LEDs auch löschen
               tsta
               beq  lcc_end
               clr  led_dbuf          ; LED Display Puffer löschen
               ldab #$7A              ; LED clear Kommando senden
               ldaa #'p'
               jsr  putchar
lcc_end
               pulx
               pula
               pulb
               rts


;***************************
; L C D _ B A C K S P A C E
;***************************
lcd_backspace
                pshb
                psha
                pshx

                clra
                ldab cpos           ; Cursorposition holen
;                beq  lcd_no_dec     ; Wenn Cursor auf Pos. 0, nichts mehr abziehen
                decb                ; Sonst Cursorposition -1
;                stab cpos           ; und wieder speichern
lcd_no_dec
                pshb
                jsr  lcd_cpos       ; Cursor auf Position setzen
                ldab #' '
                ldaa #'c'
                jsr  putchar        ; Zeichen löschen (mit Leerzeichen überschreiben)
                pulb
                jsr  lcd_cpos       ; Cursorposition erneut setzen

                pulx
                pula
                pulb
                rts



;*******************
; S A V E _ D B U F
;*******************
;
; Parameter : X - Zieladresse
;
save_dbuf
                pshb
                psha
                pshx

                xgdx                ; Zieladresse nach D
                ldx  #9             ; 9 Byte kopieren ( 1* CPOS, 8*Char )
                pshx                ; -> Bytecount auf Stack
                ldx  #dbuf          ; Quelladresse = Displaybuffer nach X
                jsr  mem_trans      ; Speicherbereich von (X) nach (D) kopieren
                pulx

                pulx
                pula
                pulb
                rts


;*************************
; R E S T O R E _ D B U F
;*************************
;
; Parameter : X - Quelladresse
;
restore_dbuf
                pshb
                psha
                pshx

                clrb
                jsr  lcd_cpos    ; Position 0
restore_loop
                ldab 0,x
                pshx
                ldaa #'c'
                jsr  putchar
                pulx
                inx              ; Adresse erhöhen
                ldab cpos
                cmpb #8
                bcs  restore_loop

                ldab 0,x         ; CPOS holen
                jsr  lcd_cpos

                pulx
                pula
                pulb
                rts

;*****************
; L C D   S E N D
;*****************
;
;  Parameter :
;
lcd_send
                pshb
lcs_retrans
                jsr  sci_tx_w    ; Ansonsten Echo
                jsr  sci_rx
                tsta
                bne  lcs_retrans

lcs_end
                pula
                pulb
                rts

;**********************************
; L C D   T I M E R   R E S E T
;**********************************
;
;  Parameter :
;
lcd_timer_reset
                pshx
                ldx  #LCDDELAY
                stx  lcd_timer
                pulx
                rts
;******************
; L C D   C P O S
;******************
;
;  Parameter : B - Cursorposition (0-7)
;
;  Ergebnis : none
;
;  changed Regs : none
;
lcd_cpos
                pshb
                psha
                pshx

                cmpb #8
                bcc  lcp_end           ; Cursorposition muß sich innerhalb von 0-7 befinden

                cmpb cpos
                beq  lcp_end           ; Wenn Cursor schon auf Position steht, nicht neu setzen

                stab cpos              ; neue Position speichern
                addb #$60              ; Befehl zusammensetzen
                ldaa #'p'
                jsr  putchar           ; und ans Display senden
lcp_end
                pulx                   ; das wars
                pula
                pulb
                rts

;******************
; L C D   F I L L
;******************
;
;  Fills LCD from current Cursorposition until end with Spaces
;  Positions containing Space are ignored to gain Speed with the
;  slow Hitachi Display
;  -> simulates LCD Clear which would be slower in cases with less than
;  4 characters to clear
;
;  Parameter : none
;
;  Ergebnis : none
;
;  changed Regs : none
;
lcd_fill
                pshb
                psha
                pshx
                ldab cpos
                pshb                   ; Cursorposition sichern
lcf_loop
                ldab #' '
                ldaa #'c'
                jsr  putchar           ; Space schreiben
                ldab cpos              ; Cursorposition holen
                cmpb #8
                bcs  lcf_loop          ; wiederholen solange Cursorposition <8 ist
lcf_end
                pulb
                jsr  lcd_cpos          ; Cursor auf alte Position setzen

                pulx                   ; das wars
                pula
                pulb
                rts



;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

