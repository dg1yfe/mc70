#define MEM_SLOT_MAX 25
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
                jmp  m_end_restore
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
                jmp  m_end_restore

;
;
;
; Neues Vorgehen für Speicherwahl:
; Eingestellten Kanal speichern:
; HD2/HD3:
; - "Enter" für Menu
; - "Mem Button" für "Store" oder per Up/Down "Store" auswählen
; - Per Up/Down oder "Button"/Taste Mem Channel auswählen
; - Enter speichert
;
; Kanal laden:
; - "Mem Button" (oder Menu & per up/down "Recall" auswählen
; - "Mem Button" wählt Bank, Ziffer wird hinzugefügt
;   alternativ: Weiterschalten per up/down
; - Anzeige: Frequenz (wenn vorhanden Name und Frequenz im Wechsel) und Mem Channel (Pos 7/8)
; - Enter übernimmt Kanal
;
;
;**************************************
; M   R E C A L L
;
; Speicherbank für Frequenzspeicherplätze wählen
;
m_recall
                ldab m_timer_en       ;
                bne  mre_nosave       ;
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
m_recall_submenu
                clrb
                jsr  lcd_cpos         ; Cursor Position 0
                PRINTF(m_recall_str)  ;
                WAIT(100)
                ldab #MEM_SELECT
                stab m_state
mre_nosave
                ldx  #m_recall_load
                stx  m_svar1
mre_show_slot
                clrb
                jsr  lcd_cpos
                ldx  #f_in_buf
                ldab mem_bank         ; ausgewählte Bank & Slot holen
                jsr  eep_rd_ch_freq
                ldx  #FBASE_MEM_RECALL%65536
                pshx
                ldx  #FBASE_MEM_RECALL>>16
                pshx
                ldx  #f_in_buf
                jsr  sub32s
                clra
                ldab #3
                jsr  decout
                ldab #' '
                ldaa #'c'
                jsr  putchar
                ldab #6
                jsr  lcd_cpos
                ldab mem_bank
                ldaa #'d'             ;
                jsr  putchar
                pulx
                pulx
                jmp  m_end
m_recall_str
                .db "M RECALL",0
;**************************************
; M   S T O R E
;
; Speicherbank für Frequenzspeicherplätze wählen
;
m_store
                ldab m_timer_en       ;
                bne  mre_nosave       ;
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
m_store_submenu
                clrb
                jsr  lcd_cpos         ; Cursor Position 0
                PRINTF(m_store_str)   ;
                WAIT(100)
                ldab #MEM_SELECT
                stab m_state
mst_nosave
                ldx  #m_store_write
                stx  m_svar1
                jmp  mre_show_slot
m_store_str
                .db "M STORE ",0
;**************************************
; M   M E M   S E L E C T
;
; Frequenzspeicherplatz aus EEPROM lesen
;
m_mem_select
                jsr  m_reset_timer     ; Menü-Timer Reset (Timeout für Eingabe setzen)
                ldaa cfg_head
                cmpa #3
                beq  msl_hd3
                cmpa #2
                beq  msl_hd2
msl_hd3
                cmpb #KC_D8
                beq  msl_nxt_bank      ; Bei D6 nächste Speicherbank wählen
                cmpb #KC_RAUTE
                beq  msl_execute       ; # = Eingestellte Frequenz und Offset speichern
                cmpb #KC_D1
                beq  msl_up
                cmpb #KC_D2
                beq  msl_down
                cmpb #KC_NON_NUMERIC
                bcs  msl2_add_slot     ; numerische Eingabe? Dann Kanal holen
                cmpb #KC_STERN
                beq  msl_escape
                jmp  m_end
msl_escape
                jmp  m_end_restore
;**************************************
msl2_add_slot
                pshb
                clrb
                ldaa mem_bank
                cmpa #10
                bcs  msl_add_slot
                ldab #10
                cmpa #20
                bcs  msl_add_slot
                ldab #20
                tsx
                ldaa 0,x
                cmpa #5
                bcs  msl_add_slot
                pulb
                jmp  m_end             ; ignore key if it would lead to memory slot >24
msl_add_slot
                pula
                aba
                staa mem_bank
                jmp  mre_show_slot     ; print frequency and slot number
;**************************************
msl_hd2
                cmpb #HD2_ENTER
                beq  msl_execute       ; Enter -> recall or store

                cmpb #KC_D8
                beq  msl_nxt_bank      ; "Mem" -> next bank

                cmpb #KC_D1
                beq  msl_up            ; Up = Cycle Slots

                cmpb #KC_D2
                beq  msl_down          ; Down = Cycle slots

                cmpb #HD2_EXIT
                beq  msl_escape        ; Exit -> Escape to main menu

                jmp  m_end
;**************************************
; M   S E L   S L O T   H D 2
;
; Frequenzspeicherplatz aus EEPROM lesen
;
msl_up
                ldab mem_bank          ; Bank holen (0 oder 1)
                incb
                cmpb #MEM_SLOT_MAX     ; Bank 2?
                bcs  ml_store
                clrb
ml_store
                stab mem_bank
                jmp  mre_show_slot
;***************
msl_down
                ldab mem_bank          ; Bank holen (0 oder 1)
                bne  mld_nowrap
                ldab #MEM_SLOT_MAX
mld_nowrap
                decb
                bra  ml_store
;***************
msl_execute
                ldx  m_svar1
                clr  m_svar1
                clr  m_svar2
                jmp  0,x
;***************
msl_nxt_bank
                ldab mem_bank          ; aktuelle Kanal-Speicherbank holen
                cmpb #MEM_SLOT_MAX-10
                bcs  mnb_add10         ; add 10 if result is <=25
                cmpb #20
                bcs  mnb_saturate      ; saturate at 25 if result would be <30
                subb #20
                bra  mnb_cont          ; wrap around if result is >= 30
mnb_saturate
                ldab #MEM_SLOT_MAX-11
mnb_add10
                addb #10
mnb_cont
                stab mem_bank          ; Bank speichern
                jmp  mre_show_slot     ; und anzeigen lassen
;***************
;
; M   R E C A L L   L O A D
;
; load previously selected frequency & offset from EEPROM
;
m_recall_load
                ldab mem_bank          ; Speicherplatz holen
                cmpb #MEM_SLOT_MAX
                bcc  msl_err           ; Invalid slot number (>25)
msl_read_eep
                pshx
                pshx                   ; DWord für Frequenz auf Stack reservieren
                tsx
                jsr  read_eep_ch       ; Kanal aus EEPROM holen
                jsr  frq_update        ; Frequenz setzen
                ldab #IDLE
                stab m_state           ; nächster State ist wieder IDLE
                jmp  m_frq_prnt        ; print set frequency
;***************
;
;
msl_err
                clrb
                jsr  lcd_cpos
                PRINTF(msl_err_str)
                jmp  m_end_restore     ; restore state & display content
msl_err_str
       .db "Err Slot",0
;**************************************
; M   S T O R E
;
; store frequency & offset to previously selected slot in EEPROM
;
m_store_write
                clrb
                jsr  lcd_cpos
                ldab mem_bank
                cmpb #25
                bcc  msl_err
                jsr  store_eep_ch      ; Kanal speichern
                tsta
                beq  mst_end           ; Falls Fehler aufgetreten
                PRINTF(m_failed)       ; "Failed" ausgeben
                jsr  lcd_fill
                WAIT(500)
                bra  mst_return
mst_end
                PRINTF(m_stored)       ; "STORED" ausgeben
                jsr  lcd_fill
                WAIT(100)
mst_return
                jmp  m_end_restore
;
m_memch_str
                .db "MEM CH",0
m_slot_str_hd2
                .db "SLOT %x",0

;*******************************
; E E P   R D   C H   F R E Q
;*******************************
;
; Frequenz für Slot aus EEPROM holen
;
; Parameter : B - zu lesender Speicherslot
;             X - Zeiger auf Speicher f�r Frequenz
;
; Ergebnis : A - 0 = OK
;
; Changed Regs : A
;
;
eep_rd_ch_freq
                pshb
                pshx

                des
                des                         ; 2 Byte Stackspeicher reservieren

                ldaa #10                    ;
                mul                         ; 10 Bytes pro Slot
                ldx  #$0100                 ; Basisadresse $0100
                abx                         ; Slot-Adresse im EEPROM berechnen (D)
                xgdx                        ; Von X nach D

                tsx                         ; Zieladresse = Stackspeicher
                pshx                        ; Zieladresse auf Stack speichern
                ldx  #2                     ; 2 Bytes lesen
                jsr  eep_seq_read
                pulx                        ; Adresse von Stack l�schen
                tsta
                bne  egcf_end               ; Fehler zur�ckgeben
                tsx
                ldd  0,x                    ; Kanal holen
                lsrd
                lsrd
                lsrd                        ; Nur obere 13 Bit ber�cksichtigen

                ldx  #1250                  ; Frequenz berechnen
                jsr  multiply               ; 16 Bit Multiply

                pshb
                psha
                pshx                        ; 32 Bit Ergebnis sichern

                ldd  #FBASE%65536       ; Basisfrequenz (unterste einstellbare Frequenz) holen
                ldx  #FBASE>>16
                jsr  add32                  ; Basisadresse addieren

                tsx
                ldx  2+4,x                   ; Zieladresse f�r Frequenz holen
                pula
                pulb
                std  0,x                    ; HiWord speichern
                pula
                pulb
                std  2,x                    ; LoWord speichern
                clra
egcf_end
                ins
                ins                         ; Stackspeicher freigeben

                pulx
                pulb
                rts
;*******************************
; E E P   R D   C H   N A M E
;*******************************
;
; Namen für Slot aus EEPROM holen
;
; Parameter : B - zu lesender Speicherslot
;             X - Zeiger auf Speicher für Namen
;
; Ergebnis : A - 0 = OK
;
; Changed Regs : A
;
;
eep_rd_ch_name
                pshb
                pshx
        
                ldaa #10                    ;
                mul                         ; 10 Bytes pro Slot
                addb #03                    ; 3 Byte Offset
                ldx  #$0100                 ; Basisadresse $0100
                abx                         ; Slot-Adresse im EEPROM berechnen (D)
                xgdx                        ; Von X nach D

                ldx  #6                     ; 6 Bytes lesen
                jsr  eep_seq_read
                pulx
                pulb
                rts

