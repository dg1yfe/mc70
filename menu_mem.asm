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
        	clrb
                jsr  lcd_cpos         ; Cursor Position 0
                PRINTF(m_recall_str)  ;
		WAIT(100)
		ldab #MEM_RECALL_SELECT
		stab m_state
mre_nosave
		ldab #MEM_RECALL_LOAD
		stab m_svar1
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
		ldab #6
		jsr  lcr_cpos
		ldab mem_bank
		ldaa #'d'             ;
                jsr  putchar

                jmp  m_end
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
                PRINTF(m_memch_str)   ;
                ldab mem_bank         ; ausgewählte Bank & Slot holen
                ldaa #'d'             ;
                jsr  putchar

                jmp  m_end

;**************************************
; M   S E L   S L O T
;
; Frequenzspeicherplatz aus EEPROM lesen
;
m_sel_slot
                jsr  m_reset_timer     ; Menü-Timer Reset (Timeout für Eingabe setzen)
                ldaa cfg_head
                cmpa #3
                beq  msl_hd3
                cmpa #2
                beq  msl_hd2
msl_hd3
                cmpb #KC_NON_NUMERIC
                bcs  msl_sel_slot      ; numerische Eingabe? Dann Kanal holen

                cmpb #KC_D8
                beq  msl_nxt_bank      ; Bei D6 nächste Speicherbank wählen
                cmpb #KC_RAUTE
                beq  msl_store         ; # = Eingestellte Frequenz und Offset speichern


                cmpb #KC_D1
                bne  msl_chk_dn        ; Up = Slot wählen und eingestellte Frequenz und Offset speichern
                jmp  msl2_up
msl_chk_dn
                cmpb #KC_D2
                bne  msl_return        ; Down = Slot wählen und eingestellte Frequenz und Offset speichern

                jmp  msl2_down
msl_return
                jmp  m_end
;**************************************
msl_hd2
                cmpb #HD2_ENTER
                beq  msl_store         ; Enter -> store frequency & offset

                cmpb #KC_D8
                beq  msl_sel_slot      ; "Mem" -> read mem channel

                cmpb #KC_D1
                beq  msl2_up           ; Up = Cycle Slots

                cmpb #KC_D2
                bne  msl_return        ;

                jmp  msl2_down
;***************
msl_sel_slot
                ldaa mem_bank          ; Speicherplatz holen
                cmpa #10
                bcc  mss_lt20
                clra
                bra  mss_add_slot
mss_lt20
                cmpa #20
                bcc  mss_lt26
                ldaa #10
                bra  mss_add_slot
mss_lt26
                ldaa #20
mss_add_slot
                aba                    ; Eingabe addieren (Slotnummer)
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
;***************
msl_nxt_bank
                ldab mem_bank          ; aktuelle Kanal-Speicherbank holen
                cmpb #16
                bcs  mnb_add10         ; add 10 if result is <=25
                cmpb #20
                bcs  mnb_saturate      ; saturate at 25 if result would be <30
                subb #20
                bra  mnb_cont          ; wrap around if result is >= 30
mnb_saturate
                ldab #15
mnb_add10
                addb #10
mnb_cont
                stab mem_bank          ; Bank speichern
                jmp  msm_show_bank     ; und anzeigen lassen
;***************
msl_store
                ldab #MEM_STORE
                stab m_state
                clrb
                jsr  lcd_cpos
                PRINTF(m_memch_str)     ; "SLOT?" ausgeben

                ldaa cfg_head
                cmpa #3
                beq  msls_hd3
                cmpa #2
                bne  msls_hd3
msls_hd2
                ldab mem_bank
                andb #$0f
                ldaa #'u'
                jsr  putchar
msls_hd3
                jmp  m_end

;**************************************
; M   S E L   S L O T   H D 2
;
; Frequenzspeicherplatz aus EEPROM lesen
;
msl2_up
                ldab mem_bank          ; Bank holen (0 oder 1)
                incb
                cmpb #26               ; Bank 2?
                bcs  ml2u_store
                clrb
ml2u_store
                stab mem_bank
msl2_print
                pshb
                ldab #6
                jsr  lcd_cpos
                pulb
                ldaa #'d'
                jsr  putchar
                jmp  m_end
;******
msl2_down
                ldab mem_bank          ; Bank holen (0 oder 1)
                bne  ml2d_nowrap
                ldab #26
ml2d_nowrap
                decb
                bra  ml2u_store

;**************************************
; M   S T O R E
;
; aktuell eingestellte Frequenz und Ablage im EEPROM speichern
;
m_store
                jsr  m_reset_timer     ; Menü-Timer Reset (Timeout für Eingabe setzen)
                ldaa cfg_head
                cmpa #3
                beq  mst_hd3
                cmpa #2
;                beq  m_sel_slot_hd2
                bra  mst_hd3
mst_hd3
                cmpb #$10
                bcs  mst_sel_slot      ; numerische Eingabe? Dann Kanal holen
                cmpb #KC_D4            ; 'C' bricht ab
                beq  mst_end
                jmp  m_end
mst_sel_slot
                pshb                   ; Eingabe (0-9) sichern
                ldaa mem_bank          ; Bank holen (0 oder 1)
                ldab #10
                lsra
                lsra
                lsra
                lsra
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
m_memch_str
                .db "MEM CH",0
m_slot_str_hd2
                .db "SLOT %x",0

;*******************************
; E E P   G E T   C H   F R E Q
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
eep_get_ch_freq
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
; E E P   G E T   C H   N A M E
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
eep_get_ch_name
                pshb
                pshx
	
                ldaa #10                    ;
                mul                         ; 10 Bytes pro Slot
		addb #03		    ; 3 Byte Offset
		ldx  #$0100                 ; Basisadresse $0100
                abx                         ; Slot-Adresse im EEPROM berechnen (D)
                xgdx                        ; Von X nach D

        	ldx  #6                     ; 6 Bytes lesen
                jsr  eep_seq_read
                pulx
                pulb
                rts

