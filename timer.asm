;****************************************************************************
;
;    MC 70    v2.0.0 - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2008  Felix Erckenbrecht, DG1YFE
;
;
;****************************************************************************
;
; wait_ms - Wartet 0-65535 ms ( X - Wartezeit in ms | nix )
;
;*****************************************
; Initialisierung der Software Timer
;
;
s_timer_init
                pshb
                psha
                pshx
                ldab tick_ms+1
                stab s_tick_ms
                ldab #100
                stab next_hms
                ldx  #OCI1_MS
                stx  oci_vec           ; ab jetzt LCD Timer nicht mehr im Int bedienen
                pulx
                pula
                pulb
                rts
;*****************************************
; Software-timer
; Aktualisierung im Kernel Thread alle 2ms
;
;
s_timer_update
                pshb
                psha
                pshx
                ldab s_tick_ms
                ldaa tick_ms+1
                sba                            ; Ticks seit letztem update - delta ticks
                beq  upt_end                   ; no change, dont do anything
                psha
                adda s_tick_ms
                staa s_tick_ms

                ldab lcd_timer                 ; lcd_timer holen
                beq  upt_no_lcd_dec            ; falls lcd_timer schon =0, kein decrement mehr
                tsx
                ldaa 0,x                       ; get number of ms to subtract
upt_lcdt_loop
                decb                           ; decrement LCD timer by 1 ms
                beq  upt_store_lcdt            ; exit if timer reaches 0
                deca
                bne  upt_lcdt_loop
upt_store_lcdt
                stab lcd_timer                 ; und speichern
upt_no_lcd_dec
upt_ui_timer
                ldab ui_timer                  ; lcd_timer holen
                beq  upt_no_uit_dec            ; falls lcd_timer schon =0, kein decrement mehr
                tsx
                ldaa 0,x                       ; get number of ms to subtract
upt_uit_loop
                decb                           ; decrement LCD timer by 1 ms
                beq  upt_store_uit             ; exit if timer reaches 0
                deca
                bne  upt_uit_loop
upt_store_uit
                stab ui_timer                  ; und speichern
upt_no_uit_dec
upt_sql_timer
; Squelch Timer
                ldab sql_timer                 ; sql timer holen
                beq  upt_no_sqlt_dec           ; falls auf 0, nicht mehr runterzaehlen
                tsx
                ldaa 0,x
upt_sqlt_loop
                decb                           ; ansonsten timer--
                beq  upt_store_sqlt
                deca
                bne  upt_sqlt_loop
upt_store_sqlt
                stab sql_timer                 ; und speichern
upt_no_sqlt_dec
                pulb
                ldaa next_hms
                sba
                bmi  upt_tcont
                staa next_hms
upt_end
                pulx
                pula
                pulb
                rts
;*****************************
upt_tcont
                adda #100
                staa next_hms
                ldx  tick_hms
                inx
                stx  tick_hms

;  100 MS Timer (menu, pll)
upt_hms_timer
                ldx  m_timer          ;+4  4; m_timer = 0 ?
                beq  upt_pll_timer    ;+3  7; Dann kein decrement
                dex                   ;+1  8; m_timer --
                stx  m_timer          ;+4 12; und sichern
upt_pll_timer
                ldab pll_timer        ;+3 15
                beq  upt_tone_timer   ;+3 18
                decb                  ;+1 19
                stab pll_timer        ;+3 22
upt_tone_timer
                ldab tone_timer
                beq  upt_end
                dec  tone_timer
                bne  upt_end
;***********
; TONE STOP
;***********
                jsr  tone_stop
                aim  #$FE, ui_ptt_req				; TODO: rename to tone_ptt_req / use bitfields

                bra  upt_end


;************************
; W A I T _ M S
;************************
wait_ms         ; X : Time to wait in ms
                ; changed Regs: X

                pshb
                psha

                xgdx                  ; Wartezeit nach D
                addd tick_ms          ; aktuellen Tickzähler addieren
                xgdx                  ; wieder nach X
                bcc  wms_loop2        ; Kein Überlauf bei der Addition? Dann Sprung
wms_loop1
                cpx  tick_ms          ; Es gab einen Überlauf - Dann müssen wir warten
                swi
                bcs  wms_loop1        ; bis tick_ms auch überläuft
wms_loop2
                cpx  tick_ms          ; und dann noch solange bis tick_ms
                swi
                bcc  wms_loop2        ; größer ist als unsere Wartezeit

                pula
                pulb
                rts

