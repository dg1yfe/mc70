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
                subb 0,x                       ; delta ticks abziehen
                bpl  upt_store_lcdt
                clrb                           ; Auch bei Unterlauf nicht kleiner werden als 0
upt_store_lcdt
                stab lcd_timer                 ; und speichern
upt_no_lcd_dec
                ldab ui_timer
                beq  upt_no_ui_dec
                tsx
                subb 0,x
                bpl  upt_store_uit
                clrb
upt_store_uit
                stab ui_timer
upt_no_ui_dec
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
                beq  upt_sql_timer    ;+3 18
                decb                  ;+1 19
                stab pll_timer        ;+3 22
upt_sql_timer
; Squelch Timer
                ldab sql_timer             ; sql timer holen
                beq  upt_tone_timer        ; falls auf 0, nicht mehr runterzaehlen
                decb                       ; ansonsten timer--
                stab sql_timer             ; und speichern

                bra  upt_end

upt_tone_timer
                ldab tone_timer
                beq  upt_end
                dec  tone_timer
                bne  upt_end
;***********
; TONE STOP
                aim  #%11110111, TCSR2     ; OCI2 Int deaktivieren

                oim  #%00001000, TCSR1     ; OCI1 Int aktivieren
                oim  #%01000000, Port6_Data; Pin auf 0 setzen
                aim  #%11011111, Port6_Data; Pin auf 0 setzen
;***********
                clr  ui_ptt_req				; TODO: rename to tone_ptt_req / use bitfields

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

