;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#ELSE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; MC POCSAG
;
;*****************************
; I N T E R N A L   R A M
;*****************************
int_ram         .ORG   $0040               ; Start of CPU internal RAM
led_buf         .db    0                   ; Bit 0 (1) - rot
                                           ; Bit 1 (2) - blink
                                           ; Bit 2 (4) - gelb
                                           ; Bit 3 (8) - blink
                                           ; Bit 4 (16)- grün
                                           ; Bit 5 (32)- blink

arrow_buf       .dw    0                   ; Bit  0 - Arrow 0
                                           ; Bit  1 - Arrow 1
                                           ; ...
                                           ; Bit  8 - Arrow 0 blink
                                           ; ...
                                           ; Bit 14 - Arrow 6 blink

dbuf            .db    0,0,0,0,0,0,0,0     ; Main Display Buffer
cpos            .db    0                   ; Cursorposition

dbuf2           .db    0,0,0,0,0,0,0,0,0   ; Display Buffer2 + Byte für CPOS

freq_dbuf       .db    0,0,0,0,0,0,0,0,0
f_in_buf        .db    0,0,0,0,0,0,0,0,0
f_base          .dw                        ; unterste Frequenz
                .dw
f_step          .dw                        ; Schrittweite in Hz

Port2_DDR_buf   .db    $FF
Port5_DDR_buf   .db    $FF
Port6_DDR_buf   .db    $FF
SR_data_buf     .db    $FF
                                                     ; 0 - R468/Q405 - TX/RX Switch (1=TX) (PIN 4 )
                                                     ; 1 - STBY&9,6V                       (PIN 5 )
                                                     ; 2 - LCD Reset,                      (PIN 6 )
                                                     ; 3 - Clock Shift,                    (PIN 7 )
                                                     ; 4 - Audio PA enable (1=enable)      (PIN 14)
                                                     ; 5 - Mic enable                      (PIN 13)
                                                     ; 6 - /TX Power enable                (PIN 12)
                                                     ; 7 - Rx Audio enable (1=enable)      (PIN 11)


tick_ms         .dw    $ffff                         ; 1ms Increment
tick_hms        .dw    $ffff                         ; 100ms Increment
gp_timer        .db    $00                           ; General Purpose Timer, 1ms Decrement
next_hms        .dw    $0000
lcd_timer       .dw    $0000                         ; 1ms

faktor1
dividend
dividendh       .dw    $ffff

faktor2
dividendl       .dw    $ffff
divisor         .dw

irq_wd_reset    .db    $00
irq_wd_flag     .db    $00

frequency       .dw
                .dw

offset          .dw
                .dw

vco             .dw
                .dw

channel         .dw                                   ; aktuell in der PLL gesetzter Kanal
                .dw

rxtx_state      .db    $00                            ; 0=RX
debounce        .db    $00

pll_locked_flag .db                                   ; Bit 0 - PLL not locked
pll_timer       .db    $00
uld_count       .db

m_state		.db
m_menu          .db                                   ; Speicher für Untermenu
m_timer         .dw                                   ; 100ms
m_timer_en      .db    $00

mem_tr_src      .dw                                   ; Puffer für Quelladresse bei Speichertransfers
mem_tr_des      .dw                                   ; Puffer für Zieladresse bei Speichertransfers

eep_size        .dw                                   ; Speicher für EEPROM Größe

sql_flag        .db
sql_timer       .db

roundcount      .dw
rc_last_sec     .dw
rc_timer        .db

;*****************************
; E X T E R N A L   R A M
;*****************************
ext_ram         .ORG $0200                            ; externes RAM wird ab 0x0140 vom uC angesprochen, durch die
                                                      ; Beschaltung wird der RAM IC aber erst ab 0x0200 aktiviert




;*********
; EEPROM
;*********
;
; fest:
; Config Daten      50 Byte
; CRC/Config         2 Byte
; variabel:
; (256Byte EEPROM)
; Kanalspeicher    204 Byte - 102 Kanäle/51 Duplexkanäle
;                  --------
;                  256 Byte
;
; $0000
;
;
; Size - ep_slots = Basisadresse für Kanalspeicher
;
; ep_fbase = unterste speicherbare Frequenz
; ep_fstep = auflösbare Unterteilung -> fmax = ep_fbase + 65535*ep_fstep
;
;
; eep_fl1,eep_fl2
;
;
;
;

#ENDIF

;*******************************************
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#ELSE
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; MCPOCSAG
;
;***************
                jsr  mem_init              ; Speicher initialisieren

                cmpa #$11
                bne  ram_ok                ; nur auf defektes RAM testen

                WLCDR($3B)                 ; Rote LED blinken
                PRINTF(ram_err_str)        ; ERROR ausgeben
ram_err_loop
                bra  ram_err_loop          ; Endlosschleife

ram_ok
                jsr  init_freq             ; grundlegende Frequenzeinstellungen
;                clr  ep_slots
;                clr  ep_slots+1            ; kein Kanalspeicher im EEPROM

                jsr  menu_init
                clr  pll_timer
                ldab #1
                stab sql_flag

                ldaa #'p'
                ldab #$36
                jsr  putchar
;                WLCDR($36)                  ; grüne LED an
                PRINTF(dg1yfe)
                WAIT(500)
                clra
                jsr  lcd_clr
                PRINTF(ver1)
                WAIT(1000)
                clra
                jsr  lcd_clr
                PRINTF(ver2)
                WAIT(1000)
                clra
                jsr  lcd_clr

                ldaa #'p'
                ldab #$31
                jsr  putchar
;                WLCDR($31)
;
                ldx  frequency+2
                pshx
                ldx  frequency
                pshx
                ldaa #'l'
                ldab #3
                jsr  putchar
                pulx
                pulx                        ; Frequenz ausgeben


                ldab #%01000000             ; PA disable
                ldaa #%11011111             ; Mic disable
                jsr  send2shift_reg

                WAIT(10)                    ; 10ms warten

                ldab #%00000000             ;
                ldaa #%11111110             ; TX/RX Switch auf RX
                jsr  send2shift_reg

                clrb
                jsr  vco_switch             ; RX VCO aktivieren

                ldx  #frequency
                jsr  set_rx_freq            ; RX Frequenz setzen

                clr  rxtx_state             ; Status auf RX setzen

                ldab #%00010000             ; Audio enable
                ldaa #%11111111             ;
                jsr  send2shift_reg


; Main Loop
loop
                jsr  pwr_sw_chk             ; Ein/Ausschalter abfragen & bedienen
                jsr  pll_led                ; PLL Lock Status auf rote LED ausgeben
                jsr  ptt_stuff              ; PTT abfragen
                jsr  squelch                ; Squelch bedienen
                jsr  menu                   ; Menü für Frequenzeingabe etc.

                sei
                ldx  roundcount
                inx
                stx  roundcount
                cli

                jmp  loop


;*******************
ptt_stuff
                pshb
                psha
                pshx

                jsr  ptt_chk                ; PTT abfragen
                cmpb rxtx_state             ; Statusänderung prüfen
                bne  pts_change             ;
                clr  debounce               ; Es hat sich nix geändert, "debounce" auf 0
                jmp  pts_end                ; und zum Ende springen

pts_change
                inc  debounce               ; Debounce Counter erhöhen
                tstb                        ; PTT gedrückt?
                bne  pts_ptt                ; Ja? Dann bei pts_ptt weitermachen
; NO PTT
pts_noptt
                ldab debounce
                cmpb #40                    ; PTT muß für mindestens 40 Durchgänge gelöst sein
                bcc  pts_rx
                jmp  pts_end                ; wenn nicht -> zum Ende springen
; RX
pts_rx

                ldab #%01000000             ; PA disable
                ldaa #%11011111             ; Mic disable
                jsr  send2shift_reg

                ldab #10
                stab gp_timer               ; 10ms warten
pts_rx_wait
                ldab gp_timer
                bne  pts_rx_wait            ; Timer schon bei 0 angekommen?

                ldab #%00000000             ;
                ldaa #%11111110             ; TX/RX Switch auf RX
                jsr  send2shift_reg

                clrb
                jsr  vco_switch             ; RX VCO aktivieren

                ldx  #frequency
                jsr  set_rx_freq            ; RX Frequenz setzen

                clr  rxtx_state             ; Status auf RX setzen

                ldab #%00010000             ; Audio enable
                ldaa #%11111111             ;
                jsr  send2shift_reg

;                WLCDR($31)                  ; gelbe LED aus
                jmp  pts_end                 ; Display Ausgabe suxx - zu langsam, deshalb erstmal umgehen

                WCPOS(0)
                ldx  frequency+2
                pshx
                ldx  frequency
                pshx
                ldaa #'l'
                ldab #3
                jsr  putchar
                pulx
                pulx

                bra  pts_end
;***************
; PTT
pts_ptt
                ldab debounce
                cmpb #40                    ; PTT muß für mindestens 40 Durchgänge gedrückt sein
                bcs  pts_end                ; wenn nicht -> zum Ende springen

                ldab #1
                jsr  vco_switch             ; TX VCO aktivieren, TX/RX Switch freigeben

                ldx  #frequency
                jsr  set_tx_freq            ; Frequenz setzen

                ldab #%00000001
                ldaa #%11111111             ; TX/RX Switch auf TX
                jsr  send2shift_reg

                ldab #10
                stab gp_timer               ; 10ms warten
pts_tx_wait
                ldab gp_timer
                bne  pts_tx_wait            ; Timer schon bei 0 angekommen?

                ldab #%00100000             ; Mic enable
                ldaa #%10111111             ; Driver enable
                jsr  send2shift_reg
                ldab #1
                stab rxtx_state             ; Status setzen
                ldab #%00000000             ;
                ldaa #%11101111             ; Audio disable
                jsr  send2shift_reg
;                WLCDR($35)                  ; gelbe LED an

                bra  pts_end                 ; Display Ausgabe suxx - zu langsam, deshalb erstmal umgehen

                WCPOS(0)
                ldx  vco+2
                pshx
                ldx  vco
                pshx
                ldaa #'l'
                ldab #3
                jsr  putchar
                pulx
                pulx

pts_end
                pulx
                pula
                pulb

                rts

;*******************************************
qrg
                .db "QRG?",0
dg1yfe
                .db "DG1YFE",0
ver1
                .db "McPOCSAG",0
ver2
                .db "0.3.0",0              ; McPocsag Version vom
ram_err_str
                .db "RAM ERR",0            ; $11
;*******************************************
#ENDIF







#IFNDEF POCSAG
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; MC MICRO
;
;
;*****************************
; M E N U
;*****************************
;
; "Menü" Subroutine
;
; Parameter : none
;
; Ergebnis : none
;
; changed Regs : none
;
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
;                jsr  sci_tx_w         ; Zeichen bestätigen
;                LCDTIME(LCDDELAY)     ; Timeout Timer reset
                clra
                addd #key_convert     ; index key convert table
                xgdx
                ldaa 0,x              ; Key übersetzen
		ldab m_state          ; Status holen
                aslb
                
                cmpb #m_state_tab_end-m_state_tab
                bcc  m_break                     ; sicher gehen dass nur existierende States aufgerufen werden

                ldx  #m_state_tab
                abx
                jmp  0,x
m_break
                jmp  m_end

m_state_tab
                .dw m_idle
                .dw m_f_in
                .dw m_d_full
m_state_tab_end
;*******************************
;
;m_j_set_ofs
;                jmp  m_set_ofs

;*******************************
; M   I D L E
;
;
m_idle
                cmpb #10              ; Zahl?
                bcc  m_idle_men1
                jmp  m_start_input    ; Start der Eingabe
m_idle_men1
                cmpb #KC_D1
                bne  m_idle_men2
;                jmp  m_show_menu
                jmp  m_frq_up         ; Kanal+
m_idle_men2
                cmpb #KC_D2
                bne  m_idle_men3
                jmp  m_frq_down       ; Kanal-
m_idle_men3
                cmpb #KC_D3           ; 3. Taste am Display
                bne  m_idle_end
;                jmp  m_f_offset
m_idle_end
                jmp  m_end            ; keine Ziffer, dann nix machen

;*******************************
; M   S T A R T   I N P U T
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
                xgdx
                clra
                ldab cpos
                addd #f_in_buf
                xgdx
                stab 0,x              ; Zeichen in Frequenzeingabe Puffer sichern
                PUTCHAR
                jmp  m_end            ; Zurück
;
;**********************************
; M   B A C K S P A C E
;
; eingegebenes Zeichen löschen
;
m_backspace
                jsr  m_reset_timer
                jsr  lcd_backspace
                clra
                ldab cpos
                addd #f_in_buf
                xgdx
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
                cmpb #10                   ; Zahl?
                bcc  m_non_numeric         ; dann irgendwas machen
                ldaa cpos                  ; sonst nachsehen
                cmpa #08 		   ; ob noch Platz im Display
		bne  m_print		   ;
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
                psha
                clra
                jsr  lcd_clr
                pula
                clr  f_in_buf              ; Erstes Zeichen im Eingabebuffer auf 0 (Buffer "leer")
                jmp  m_end

;**********************************
;
; M   N O N   N U M E R I C
;
; Nicht numerische Eingabe entgegennehmen
;
m_non_numeric
                cmpb #KC_CLEAR             ; 'C'
                beq  m_clr_displ
                cmpb #KC_STERN             ; '*'
                beq  m_backspace
                cmpb #KC_RAUTE             ; '#'
                beq  m_set_freq
                jmp  m_end

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
                jsr  set_freq         ; Frequenz setzen

                clra
                jsr  lcd_clr          ; LCD löschen
                ldab #IDLE
                stab m_state          ; nächster State ist wieder IDLE

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
;                jsr  set_freq
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
                WCPOS(0)              ; Cursor auf 0 setzen
                ldx  frequency+2      ; Frequenz Lo Word holen
                ldd  frequency        ; Frequenz Hi Word holen

                pshx                  ; Lo Word auf Stack
                xgdx
                pshx                  ; Hi Word auf Stack

                ldaa #'l'             ; unsigned Longint ausgeben
                ldab #3               ; die letzten 3 Stellen abscheiden
                jsr  putchar
                pulx
                pulx

                clr  m_timer_en       ; Menü Timer disabled - Aktuelles Display = neues Display
                pshb
                psha
;                WLCDR($36)            ; grüne LED an
                clr  pll_timer        ; PLL Timer auf 0
                pula
                pulb
msf_end
                pulx
                pulx                  ; eingegebene Frequenz vom Stack löschen
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
;*******************************
; M   S H O W   M E N U
;
; Konfigurationsmenü anzeigen
;
m_show_menu
                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern
                clra
                jsr  lcd_clr          ; Display löschen
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
                ldaa #SHOW            ; Frequenzeingabe beginnt
		staa m_state

                jmp  m_end
;*******************************
; M   F R Q   U P
;
; Frequenz einen Kanal nach oben
;
m_frq_up
                ldab rxtx_state
                bne  mfu_end
                ldx  frequency+2
                pshx
                ldx  frequency
                pshx
                ldx  #0
                ldd  #FSTEP
                jsr  add32
                tsx
                jsr  set_freq
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
                bne  mfd_end
                ldx  #FSTEP
                pshx
                ldx  #0
                pshx
                ldd  frequency+2
                ldx  frequency
                jsr  sub32
                tsx
                jsr  set_freq
                jmp  m_frq_prnt

mfd_end
                jmp  m_end
;*******************************
; M   S E T   O F S   S T A R T
;
; Offset setzen
;
m_set_ofs_start
                jsr  m_reset_timer    ; Menü-Timer Reset (Timeout für Eingabe setzen)
                ldx  #dbuf2
                jsr  save_dbuf        ; Display sichern
                clra
                jsr  lcd_clr
                ldd  f_step+2
                ldx  f_step
                bpl  mso_positive
                jsr  sig_inv32        ; Vorzeichen invertieren
                xgdx
                oraa #$80             ; MSB setzen, als Vorzeichenbit
                xgdx
                pshb
                psha
                pshx
                ldab #'+'             ; positives Offset
                ldaa #'c'
                jsr  putchar
                bra  mso_print
mso_positive
                pshb
                psha
                pshx
                ldab #'-'            ; negatives Offset
                ldaa #'c'
                jsr  putchar
mso_print
                pula
                anda #$7F
                psha
                ldaa #'l'
                ldab #3
                jsr  putchar         ; aktuelles Offset anzeigen
                pulx
                pulx
                ldab #OFS_IN
                stab m_state         ; nächster Zustand : OFS_IN


mfo_end
                jmp  m_end

;*******************
;
;
m_f_off_in
                cmpb #10                   ; Zahl?
;                bcc  m_fo_nn               ; dann irgendwas machen
                ldaa cpos                  ; sonst nachsehen
                cmpa #08 		   ; ob noch Platz im Display
;		bne  m_print		   ;
		ldaa #D_FULL		   ; Display voll, state anpassen
		staa m_state
                jmp  m_end


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
;

m_ok            .db "OK",0
m_no_lock_str   .db "NO LOCK ",0
m_bla           .db "bla",0
m_out_str       .db "out of",0
m_range_str     .db "Range ",0
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#ELSE




#IFNDEF POCSAG
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; MC MICRO
;
;
;************************************************
; F R E Q U E N C Y
;************************************************

;*************************
; C H   C L R   S L O T S
;*************************
ch_clr_slots
;
; Setzt Speicherkanäle auf Vorgabewert
;
                pshb
                psha
                pshx
                ldx  #CM70>>16         ; HiWord der 1. Frequenz des 70cm Bandes holen
                pshx
                ldx  #CM70%65536       ; LoWord der 1. Frequenz des 70cm Bandes holen
                pshx                   ; auf Stack schieben
                tsx
                xgdx
                tsx                    ; Pointer auf Frequenz DWORD nach D und X
                jsr  frq_sub_offset    ; Offset abziehen
                tsx
                jsr  frq_cv_freq_ch    ; Kanal berechnen
                pulx
                pulx                   ; Stack bereinigen, nur LoWord des Channels interessant (max. 65536 Kanäle)
                ldx  #ep_m_base
ccs_loop
                std  0,x
                inx
                inx
                cpx  #ep_m_base+(EP_CH_SLOTS<<2) ; Endadresse erreicht (102 Kanäle initialisiert) ?
                bne  ccs_loop

                pulx
                pula
                pulb                   ; Register wiederherstellen
                rts
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


#IFNDEF POCSAG
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; MC MICRO
;
;

;*************************
; M E M   I N I T
;*************************
;
; Testet & Initialisiert RAM / EEPROM
;
; Parameter : Keine
;
; Ergebnis : A - Status:   0 = OK
;
;                        $11 = RAM Error
;
;                        $20 = Kein EEPROM Speicher an Adresse 0 vorhanden (I2C Deviceadresse prüfen! )
;
;                        $3x = Fehler beim Lesen des Config Bereichs
;                          1 - Kein ACK nach Device/Pageadresse
;                              (kein EEPROM mit der Adresse vorhanden?)
;                          2 - Kein ACK nach Byteadresse
;                          3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;                        $41 = CRC Fehler im Config Bereich
;
;                        $5x = Lesefehler beim Kopieren
;                          1 - Kein ACK nach Device/Pageadresse
;                              (kein EEPROM mit der Adresse vorhanden?)
;                          2 - Kein ACK nach Byteadresse
;                          3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;                        $60 = Nicht genug Speicher für EP_CH_SLOTS
;                              verfügbare Anzahl von Slots steht in ep_slots
;
;                        $8x = Fehler beim Kopieren der Kanäle ins RAM
;                          1 - Kein ACK nach Device/Pageadresse
;                              (kein EEPROM mit der Adresse vorhanden?)
;                          2 - Kein ACK nach Byteadresse
;                          3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;                        $Ex = Nicht genug Speicher für EP_CH_SLOTS
;                              UND Fehler beim Kopieren der Kanäle ins RAM
;                          1 - Kein ACK nach Device/Pageadresse
;                              (kein EEPROM mit der Adresse vorhanden?)
;                          2 - Kein ACK nach Byteadresse
;                          3 - Kein ACK nach Device/Pageadresse in "eep_current_read"
;
;
;
; changed Regs : A,X
;
; changed Mem  : eep_mirror... , ep_slots
;
;
mem_init
                pshb

                jsr  mem_chk               ; RAM überprüfen

                tsta
                bne  mei_ram_err

                jsr  eep_get_size          ; EEPROM Größe feststellen
                std  eep_size              ; und speichern

                beq  mei_no_ep_err         ; kein EEPROM vorhanden?

                jsr  eep_chk_crc           ; CRC des Config-Bereichs prüfen
                cmpa #8                    ; Lesefehler aufgetreten? (Fehler Code >=8)

                bcc  mei_cfg_rd_err

                tsta                       ; CRC OK (=0)

                bne  mei_cfg_crc_err       ; Nein? CRC Error aufgetreten

                                           ; CRC is ok, also gültige Config vorhanden
                clra                       ; Config für schnelleren Zugriff ins RAM kopieren
                ldab #EP_CONF_MEM          ; 52 Byte Config Daten
                pshb
                psha                       ; Bytecount auf Stack
                clrb                       ; EEPROM Startadresse 0
                ldx  #eep_mirror           ; speichern bei "eep_mirror"
                jsr  eep_seq_read
                pulx                       ; Bytecount vom Stack löschen
                tsta                       ; Fehler beim Lesen aufgetreten?
                bne  mei_cpy_err           ; Dann hier abbrechen
                clra
                ldd  eep_size              ; EEPROM Größe holen
                subd #EP_CONF_MEM          ; Speicher für Config abziehen
                pshb
                psha                       ;
                subd #EP_CH_SLOTS<1        ; genug Platz für Kanalspeicher? (2Byte pro Slot)
                pulx
                bcs  mei_ins_mem_err
                clra                       ; Ja? Dann Kanäle kopieren
                ldx  #EP_CH_SLOTS<1        ; (2Byte pro Slot)
mei_cpy_ch
                psha                       ; Status sichern
                xgdx
                lsrd                       ; Bytes in Slots umrechnen
                std  ep_slots              ; Anzahl verfügbarere Slots speichern
                lsld                       ; wieder in Bytes umrechnen
                pshb
                psha                       ; Bytecount auf Stack (Anzahl Kanäle)
                ldd  #EP_CONF_MEM          ; Nach Config Bereich liegen die Kanäle
                ldx  #ep_m_base            ; Basisadresse für Kanalspeicher holen
                jsr  eep_seq_read          ; Kanäle von EEPROM ins RAM kopieren
                ins
                ins                        ; Bytecount vom Stack löschen
                tab                        ; Status vom EEPROM Read nach b
                pula                       ; Status wiederholen
                orab                       ; EEPROM Status hinzufügen
                tstb                       ; Fehler beim Lesen aus dem EEPROM aufgetreten?
                bne  mei_ch_cpy_err
mei_end
                pshx                       ; X sichern
                tsx
                oraa 2,x                   ; Fehlercode berechnen
                pulx                       ; X wiederherstellen

                pulb                       ; B wiederherstellen


                rts
mei_ram_err

                oraa #$10
                bra  mei_end
mei_no_ep_err
                oraa #$20
                bra  mei_end
mei_cfg_rd_err
                oraa #$30
                bra  mei_end
mei_cfg_crc_err
                oraa #$40
                bra  mei_end
mei_cpy_err
                oraa #$50
                bra  mei_end
mei_ins_mem_err
                oraa #$60        ; zu Platz im EEPROM
                xgdx             ; dennoch verfügbare Kanäle auslesen
                lsrd             ;
                lsld             ; Auf ganzen 2 Byte Wert abrunden
                xgdx
                bra  mei_cpy_ch
mei_ch_cpy_err
                oraa #$80
                bra  mei_end
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                tsta
                bne  sit_error
                jmp  sit_end
sit_error
                cmpa #$11
                bne  sit_ram_ok

                WLCDR($3B)                 ; Rote LED blinken
                PRINTF(ram_err_str)        ; ERROR ausgeben
sit_ram_err_lp
                bra  sit_ram_err_lp        ; Endlosschleife

sit_ram_ok
                cmpa #$20
                bne  sit_ep_present
                WLCDR($39)                 ; gelbe LED blinken
                PRINTF(no_ep_err_str)      ; Error ausgeben
                WAIT(2000)                 ; 2 Sekunden qarten
                jmp  sit_ini_from_rom      ; aus ROM initialisieren

sit_ep_present
                cmpa #$31
                bcs  sit_cfg_crc_rd_ok     ; Fehlercode < $31 ? Dann jump

                cmpa #$34
                bcc  sit_cfg_crc_rd_ok     ; Fehlercode >= $34 ? Dann jump

                WLCDR($39)                 ; gelbe LED blinken
                PRINTF(ep_crc_err_str)     ; Fehler ausgeben
                psha
                tab
                ldaa #'x'
                jsr  putchar               ; Fehlercode anhängen
                WAIT(2000)                 ; 2 Sekunden warten
                pula
                jmp  sit_ini_from_rom      ; aus ROM initialisieren

sit_cfg_crc_rd_ok                          ; CRC erfolgreich gelesen
                cmpa #$41
                bne  sit_cfg_crc_ok        ; CFG CRC ok

; EEPROM CRC NICHT OK
; Config aus ROM initialisieren
                WLCDR($39)                 ; gelbe LED blinken
                PRINTF(ep_crc_err_str)     ; Fehlermeldung ausgeben

                psha
                tab
                ldaa #'x'
                jsr  putchar               ; Fehlercode anhängen
                WAIT(2000)                 ; 2 Sekunden warten
                pula

                jmp  sit_ini_from_rom      ; aus ROM initialisieren
sit_cfg_crc_ok
                cmpa #$51
                bcs  sit_cfg_cpy_ok        ; Fehlercode < $51 ? Dann jump
                cmpa #$54
                bcc  sit_cfg_cpy_ok        ; Fehlercode >= $54 ? Dann jump

;                tab
;                andb #$f0
;                cmpb #$50
;                bne  cfg_cpy_ok

                WLCDR($39)                 ; gelbe LED blinken
                PRINTF(cpy_err_str)        ; Fehlermeldung ausgeben
                psha
                tab
                ldaa #'x'
                jsr  putchar               ; Fehlercode anhängen
                WAIT(2000)                 ; 2 Sekunden qarten
                pula
                jmp  sit_ini_from_rom      ; aus ROM initialisieren

sit_cfg_cpy_ok                             ; CFG erfolgreich kopiert
                tab
                andb #$70
                cmpb #$60
                bne  sit_enough_ch_mem     ; ausreichend Speicher für Ch Slots
                cmpa #$60
                bne  sit_less_mem_cpy_err  ; wenig Speicher & Lesefehler aufgetreten

                xgdx                       ; wenig Speicher, aber kein Lesefehler aufgetreten
                lsrd
                xgdx
                stx  ep_slots              ; kopierte Anzahl an Slots speichern
                WLCDR($39)                 ; gelbe LED blinken
                PRINTF(lo_mem_err_str)     ; Fehlermeldung ausgeben
                WAIT(2000)                 ; 2 Sekunden qarten
                jmp  sit_ini_less_mem      ; weniger Kanalsppeicher verfügbar
sit_less_mem_cpy_err
                xgdx
                lsrd
                xgdx
                stx  ep_slots              ; kopierte Anzahl an Slots speichern
                WLCDR($39)                 ; gelbe LED blinken
                PRINTF(cpy_err_str)        ; Fehlermeldung ausgeben
                psha
                tab
                ldaa #'x'
                jsr  putchar               ; Fehlercode anhängen
                WAIT(2000)                 ; 2 Sekunden qarten
                pula
                bra  sit_ini_less_mem      ; weniger Kanalsppeicher verfügbar
sit_enough_ch_mem
                cmpa #$81
                bcs  sit_unknown_err       ; Fehlercode < $81 ? Dann jump
                cmpa #$84
                bcc  sit_unknown_err       ; Fehlercode >= $84 ? Dann jump


;                tab
;                andb #$f0
;                cmpb #$80
;                bne  unknown_err           ; unbekannter Fehler
sit_en_mem_cpy_err
                                           ; Lesefehler beim Kopieren
                xgdx
                lsrd
                xgdx
                stx  ep_slots              ; kopierte Anzahl an Slots speichern
                WLCDR($39)                 ; gelbe LED blinken
                PRINTF(cpy_err_str)        ; Fehlermeldung ausgeben
                psha
                tab
                ldaa #'x'
                jsr  putchar               ; Fehlercode anhängen
                WAIT(2000)                 ; 2 Sekunden qarten
                pula
                bra  sit_ini_less_mem      ; weniger Kanalsppeicher verfügbar
sit_unknown_err
                WLCDR($3B)                 ; rote LED blinken
                PRINTF(unknown_err_str)    ; Fehlermeldung ausgeben
                tab
                ldaa #'x'
                jsr  putchar               ; Fehlercode anhängen
                WAIT(5000)                 ; 5 Sekunden qarten
                WLCDR($33)                 ; rote LED aus

;********************
                jmp  ini_from_rom
sit_ini_from_rom
                jsr  init_freq_rom         ; grundlegende Frequenzeinstellungen
                clr  ep_slots
                clr  ep_slots+1            ; kein Kanalspeicher im EEPROM
                bra  sit_end               ; und weitermachen :)
sit_ini_less_mem
                clra
                jsr  lcd_clr
                ldx  ep_slots              ; Anzahl Slots holen
                pshx
                ldx  #0
                pshx
                clrb
                ldaa #'l'
                jsr  putchar               ; und ausgeben
                pulx
                pulx
                PRINTF(slot_str)           ; "SLOTS" anhängen
                WAIT(2000)
                bra  sit_all_ok            ; da Config Bereich ok, Einstellungen aus EEPROM übernehmen
sit_all_ok
                jsr  init_freq_eep         ; Frequenzeinstellungen aus EEPROM holen
sit_end
                rts

;------------------
multiply
               std  faktor1
               stx  faktor2
               clra                 ; B = LoByte Faktor1
               pshx
               ins                  ; ignoriere HiByte Faktor2
               pula                 ; A = LoByte Faktor2
               mul                  ; multiplizieren
               pshb
               psha                 ; Ergebnis speichern
               ldx  #0
               pshx
               ldab faktor1         ; HiByte Faktor1
               ldaa faktor2+1       ; LoByte Faktor2
               mul
               tsx
               addb 2,x
               stab 2,x
               adca #0
               staa 1,x
               ldaa #0              ; clear Register without clearing Carryflag
               rola
               staa 0,x
               ldab faktor1+1       ; LoByte Faktor1
               ldaa faktor2         ; HiByte Faktor2
               mul
               addb 2,x
               stab 2,x
               adca 1,x
               staa 1,x
               ldaa #0              ; clear Register without clearing Carryflag
               adca 0,x
               staa 0,x
               ldab faktor1         ; HiByte Faktor1
               ldaa faktor2         ; HiByte Faktor2
               mul
               addb 1,x
               stab 1,x
               adca 0,x
               staa 0,x
multiply_end
               ldd  2,x             ; Ergebnis LoWord holen
               ldx  0,x             ; Ergebnis HiWord holen
               ins
               ins
               ins
               ins                  ; lokale Variablen löschen
               rts



m_frq_store
                ldab m_timer_en
                bne  mfs_nosave
                ldx  #dbuf2
                jsr  save_dbuf        ; Displayinhalt in dbuf2 sichern

mfs_nosave
                clrb
                jsr  lcd_cpos
                PRINTF(m_writing)
                jsr  lcd_fill         ; Display überschreiben
                pshx                  ; 2 Byte für CRC reservieren
                ldx  offset+2
                pshx
                ldx  offset
                pshx
                ldx  frequency+2
                pshx
                ldx  frequency
                pshx
; Parameter: STACK - Datenadresse im Speicher
;            STACK - Datenadresse im EEPROM (Byte Adresse)
;            STACK - Device&Page Adresse (3 Bit, LSB)
;            STACK - Bytecount
                tsx
                ldd  crc_init            ; CRC über Frequenz und Offset berechnen
                pshb                     ; Initwert auf Stack
                psha
                ldd  #8                  ; Bytecount = 8
                jsr  crc16
                pula
                pulb                     ; CRC holen
                tsx
                std  8,x                 ; CRC hinter Frequenz und Offset speichern
                pshx                     ; Adresse der Daten - Stack
                ldx  #0                  ; EEPROM Start Adresse - 0
                pshx
                ldx  #10                 ; 10 Bytes schreiben
                pshx
                jsr  eep_write_seq       ; EEPROM schreiben
                tsx
                xgdx
                addd #16                 ; Daten vom Stack löscht
                xgdx
                txs
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
                WAIT(500)                ; 500 ms warten
                ldx  #dbuf2
                jsr  restore_dbuf        ; Displayinhalt wiederherstellen
                jmp  m_end               ;

