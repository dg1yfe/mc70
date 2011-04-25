;**************************************
; M   F R Q   S T O R E
;
; Eingestellte Frequenz und TX Shift im EEPROM als default speichern
;
m_frq_store
                ldab m_timer_en
                bne  mfs_nosave
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
                jsr  restore_dbuf        ; Displayinhalt wiederherstellen
                jmp  m_end               ;

;**************************************
; M   S E L   M B A N K
;
; Speicherbank für Frequenzspeicherplätze wählen
;
m_sel_mbank
                ldab m_timer_en       ;
                bne  msm_nosave       ;
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
; M   S E L   S L O T   H D 2
;
; Frequenzspeicherplatz aus EEPROM lesen
;
m_sel_slot_hd2
                jsr  m_reset_timer     ; Menü-Timer Reset (Timeout für Eingabe setzen)
                cmpb #HD2_ENTER
                beq  msl_store         ; # = Eingestellte Frequenz und Offset speichern
                cmpb #HD2_UP
                beq  msl2_up
                cmpb #HD2_DN
                beq  msl2_dn
                jmp  m_end_restore
msl2_up
                ldaa mem_bank          ; Bank holen (0 oder 1)
                tab
                cmpa #$20
                bcs  ml2u_bnk01
                adda #$04
ml2u_bnk01
                clr  mem_bank
                anda #$0f
                inca
                cmpa #$0a              ;
                beq  msl2_print
                incb
                stab mem_bank
msl2_print
                ldab mem_bank
                pshb
                ldab #6
                jsr  lcd_set_cpos
                pulb
                ldaa #'u'
                jsr  putchar
                jmp  m_end
;******
msl2_down
                ldaa mem_bank          ; Bank holen (0 oder 1)
                beq  ml2d_bnk
                deca
ml2d_store
                staa mem_bank
                bra  msl2_print
ml2d_bnk
                cmpa #$20
                bcs  ml2d_bnk01
                ldaa #$25
                bra  ml2d_store
ml2d_bnk01
                anda #$30
                oraa #$09
                bra  ml2d_store

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
m_slot_str      
                .db "SLOT? ",0
m_membank_str
                .db "MEMBNK ",0
m_slot_str_hd2
                .db "SLOT %x",0
