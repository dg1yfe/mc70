;****************************************************************************
;
;    MC2_E9   v1.0   - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2009  Felix Erckenbrecht, DG1YFE
;
;
;
;****************************************************************************
;*****************
; I S R   I N I T
;*****************
;************************
; I N I T   O C I   I N T
;************************
init_OCI
               clr  bus_busy                ; IRQ Routine darf Watchdog zurücksetzen
               ldd  FRC
               addd #SYSCLK/1000                ; Interrupt every millisecond
               std  OCR1
               ldab #%1000
               stab TCSR1                       ; enable Output Compare Interrupt
               ldd  #0
               std  tick_ms
               std  tick_hms
               addd #100
               std  next_hms
;               ldx  #OCI1_WD_RESET
               ldx  #OCI_LCD
               stx  oci_vec
               rts
;************************
; I N I T   S I O   I N T
;************************
;
; SIO Interrupt initialisieren
;
init_SIO
                clr  io_outbuf_w
                clr  io_outbuf_r                  ; Output Ringbuffer initialisieren

                clr  io_inbuf_w
                clr  io_inbuf_r                   ; Input Ringbuffer initialisieren

;                oim  #%10100,TRCSR1               ; SIO Interrupt aktivieren
                oim  #%00010000,TRCSR1           ; SIO Interrupt aktivieren nur für RX

                rts

;************************************
;
;
;*******
; I S R
;*******
NMI_SR               ; no NMI
                jmp  isu_copy
                rti
;************************************
SWI_SR               ; SWI als Taskswitch
                ldx  stackbuf              ; anderen Stackpointer holen
                sts  stackbuf              ; aktuellen Stackpointer sichern
                inx                        ; TXS subtrahiert 1 vom Wert vor Transfer
                txs                        ; anderen Stackpointer laden
                inc  tasksw                ; Taskswitch Counter erhöhen
                ldx  ts_count
                inx
                stx  ts_count
                rti                        ; Taskswitch durchführen
;************************************
IRQ1_SR              ; no IRQ1
                rti
;************************************
ICI_SR               ; no ICI
                rti
;************************************
OCI_SR
                ldx  oci_vec
                jmp  0,x
oci_sel
                ldab TCSR2                     ; Timer Sontrol / Status Register 2 lesen
                tba
                andb #%00001000                ; Auf EOCI2 testen (Tone Interrupt)
                beq  OCI1_SR                   ; ansonsten beim normalen 1ms Int weitermachen
;
                ldab TCSR2                     ; Timer Sontrol / Status Register 2 lesen
                ldd  OCR2
                addd #TONE_DPHASE              ; ca 3500 mal pro sek Int auslösen
                std  OCR2

                ldab tone_index
                bne  ocf1_f2_tonelo
                oim  #%01100000, Port6_Data    ; TODO: MACRO einfŸhren? (EVA5/EVA9 diff)
                eim  #1,tone_index
                bra  ocf1_test
ocf1_f2_tonelo
                aim  #%10011111, Port6_Data    ; TODO: MACRO einfŸhren? (EVA5/EVA9 diff)
                eim  #1,tone_index
ocf1_test
                ldab TCSR1                     ; Timer Control & Status Reg 1 lesen
                andb #%01000000                ; auf OCF1 (1ms Flag) testen

                bne  OCI1_SR                   ; falls gesetzt, den 1 ms Int ausführen
                rti                            ; ansonsten ist hier Schluß
;************************************
OCI_LCD
                ldx  lcd_timer
                beq  oci_dbg_lcd
                dex
                stx  lcd_timer
oci_dbg_lcd
                jmp  OCI1_MS
;**********************************************************************
;
; OCI1 ISR (1 ms Interrupt)
;
OCI1_WD_RESET
                tst  bus_busy              ; währen I2C Zugriff,
                bne  OCI1_SR               ; keinen Watchdog Reset durchführen
;***********
; Watchdog Toggle
                ldab Port2_DDR_buf               ; Port2 DDR lesen
                eorb #%10                        ; Bit 1 invertieren
                stab Port2_DDR_buf
                stab Port2_DDR                   ; neuen Status setzen
                aim  #%11111101,Port2_Data       ;Data auf 0
;***********
OCI1_SR
OCI1_MS
                ldab TCSR1                 ; Interruptflag zurücksetzen
                ldd  OCR1H
                addd #SYSCLK/1000          ;
                std  OCR1H                 ; in 1ms wieder einen Int ausführen

OCI_MAIN
; General Purpose Timer
                dec  gp_timer              ; Universaltimer-- / HW Task
                dec  ui_timer              ; Universaltimer-- / UI Task
; Basis Tick Counter
                ldx  tick_ms
                inx                        ; 1ms Tick-Counter erhöhen
                stx  tick_ms
;
; ; 100ms Tick Counter						; TODO: AUSLAGERN in mainloop
;                 cpx  next_hms              ; schon 100ms vergangen?
;                 bne  oci_no_hms
; 
;                 xgdx
;                 addd #100                  ; nächsten 100ms Tick Berechnen
;                 std  next_hms              ; und speichern
; 
;                 ldx  tick_hms
;                 inx                        ; 100ms Tick Counter erhöhen
;                 stx  tick_hms
; 
; ;***************
; ; OCI HMS                                   ; Alle 100ms Timer erhöhen
; ;
; ;  100 MS Timer (menu, pll)
; ;
;                 ldx  m_timer               ; m_timer = 0 ?
;                 beq  oci_pll_timer         ; Dann kein decrement
;                 dex                        ; m_timer --
;                 stx  m_timer               ; und sichern
; oci_pll_timer
;                 ldab  pll_timer
;                 beq   oci_tone_timer       ; falls auf 0, nicht mehr runterzaehlen
;                 decb
;                 stab  pll_timer
; oci_tone_timer
;                 ldab tone_timer
;                 beq  oci_hms_timer_end
;                 dec  tone_timer
;                 bne  oci_hms_timer_end
; ;***********
; ; TONE STOP
;                 aim  #%11110111, TCSR2     ; OCI2 Int deaktivieren
; 
;                 oim  #%00001000, TCSR1     ; OCI1 Int aktivieren
;                 oim  #%01000000, Port6_Data; Pin auf 0 setzen
;                 aim  #%11011111, Port6_Data; Pin auf 0 setzen
; ;***********
;                 clr  ui_ptt_req				; TODO: rename to tone_ptt_req / use bitfields
; oci_hms_timer_end
; oci_no_hms
; ; LCD Timeout Timer aktualisieren
;                 ldx  lcd_timer             ; lcd_timer holen
;                 beq  oci_no_lcd_dec        ; falls lcd_timer schon =0, kein decrement mehr
;                 dex                        ; ansonsten lcd_timer--
; oci_store_lcdt
;                 stx  lcd_timer             ; und speichern
; oci_no_lcd_dec
; ; Squelch Timer
;                 ldab sql_timer             ; sql timer holen
;                 beq  oci_no_sql_dec        ; falls auf 0, nicht mehr runterzaehlen
;                 decb                       ; ansonsten timer--
;                 stab sql_timer             ; und speichern
; oci_no_sql_dec
                ldab tasksw_en             ; auf Taskswitch prüfen?
                bne  end_int               ; Nein? Dann Ende

                ldaa last_tasksw           ; Letzten Taskswitch Counter holen
                ldab tasksw                ; Mit aktuellem Zählerstand vergleichen
                stab last_tasksw           ; und merken
                cba                        ; Gabs einen Taskswitch innerhalb der letzten Millisekunde?
                bne  end_int               ; Ja, dann Int beenden
                                           ; ansonsten Taskswitch durchführen
                ldx  stackbuf              ; anderen Stackpointer holen
                sts  stackbuf              ; aktuellen Stackpointer sichern
                inx                        ; X anpassen für Transfer
                txs                        ; anderen Stackpointer laden
                inc  tasksw                ; Taskswitch Counter erhöhen
end_int
                rti

;************************************
;************************************
ocf2
;                ldx  #tone_tab
;                ldab TCSR2                 ; Timer Sontrol / Status Register 2 lesen

                ldab tone_index
                bne  ocf2_tonelo
                oim  #%01100000, Port6_Data
                eim  #1,tone_index
                rts
ocf2_tonelo
                aim  #%10011111, Port6_Data
                eim  #1,tone_index
                rts

;Pin 30 & 31
;    P65 P66
tone_tab

;sin_tab
                .db %00000000
                .db %01000000
;************************************

TOI_SR               ; no TOI
                rti


;************************************
;
; SIO INT Service Routine
;
; Datenbytes von Schnittstelle abholen - falls vorhanden - und in Puffer speichern
; Datenbytes aus Puffer abholen - falls vorhanden - und über Schnittstelle senden
;
SIO_SR
                ldaa TRCSR1                ; Status lesen
                tab
                andb #%01000000
                bne  sio_orfe              ; Overrun / Framing Error
                ldab TRCSR2
                andb #%00010000            ; Auf Parity Error prüfen
                bne  sio_per
                tab
                andb #%10000000
                bne  sio_rdrf              ; Receive Data Register Full
                tab
                andb #%00100000
                bne  sio_tdre              ; Transmit Data Register Empty Int
                rti                        ; Interrupt beenden
;
;******************
;
sio_orfe
sio_per
                ldab RDR                   ; Datenregister lesen -> ORFE oder PER Bit löschen
                                           ; Daten sind ungültig, daher verwerfen
                rti
sio_rdrf
                ldaa RDR                   ; Datenregister lesen
                ldab io_inbuf_w            ; Zeiger auf Schreibadresse holen
                incb                       ; prüfen ob Puffer schon voll
                andb #io_inbuf_mask        ; maximal 15 Einträge
                cmpb io_inbuf_r            ; Lesezeiger schon erreicht?
                beq  sio_ib_over           ; Overrun Error
                ldab io_inbuf_w            ; Zeiger erneut holen
                ldx  #io_inbuf             ; Basisadresse holen
                abx                        ; beides addieren -> Schreibadresse bestimmen
                staa 0,x                   ; Datenbyte schreiben
                incb                       ; Zeiger++
                andb #io_inbuf_mask        ;
                stab io_inbuf_w            ; und speichern
                rti
sio_ib_over
                ldab io_inbuf_er           ; Errorzähler holen
                incb
                bne  sio_ibo_stor          ; Maxval (255) schon erreicht?
                decb                       ; dann nicht weiterzählen
sio_ibo_stor
                stab io_inbuf_er           ; Neue Zahl der Buffer Overruns speichern
                ldab io_inbuf_w            ; Zeiger auf Puffer holen
                ldx  #io_inbuf             ; Basisadresse holen
                abx                        ; beides addieren -> Schreibadresse bestimmen
                staa 0,x                   ; Datenbyte schreiben, Zeiger nicht erhöhen
                rti
;
;******************
;******************
;
sio_tdre
                ldab io_outbuf_r           ; Zeiger auf Leseposition holen
                cmpb io_outbuf_w           ; Befinden sich noch Zeichen im Output Buffer?
                beq  sio_ob_empty          ; Sprung wenn es keine Daten gibt
                ldx  #io_outbuf            ; Basisadresse holen
                abx                        ; Zeiger addieren, Leseadresse berechnen
                ldaa 0,x                   ; Daten aus Puffer lesen
                incb                       ; Leseposition++
                andb #io_outbuf_mask       ; Im gültigen Rahmen bleiben (0-15)
                stab io_outbuf_r           ; Neue Zeigerposition speichern
                staa TDR                   ; Datenbyte ins Transmit Data Register schreiben
                bmi  sio_tdre_end          ; MSB gesetzt -> nächstes Byte darf sofort gesendet werden (2 Byte Kommando)
;                ldx  #LCDDELAY             ; Wartezeit holen
;                stx  lcd_timer             ; und Timer entsprechend setzen
sio_ob_empty
                aim  #%11111011,TRCSR1     ; "Transmit Data Register Empty"-Interrupt deaktivieren
sio_tdre_end
                rti

;************************************
CMI_SR               ; no CMI
                rti
;************************************
IRQ2_SR              ; no IRQ2
                rti
;************************************
TRAP_SR              ; no TRAP stuff
                rti
;************************************


