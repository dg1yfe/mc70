;****************************************************************************
;
;    MC 70    v1.0.1 - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2007  Felix Erckenbrecht, DG1YFE
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
                pshb
                psha
                pshx

                clr   irq_wd_reset                ; IRQ Routine darf Watchdog zurücksetzen
                ldd   FRC
                addd  #1994                       ; etwa alle 1ms einen Int auslösen
                std   OCR1
                ldab  #%1000
                stab  TCSR1                       ; enable Output Compare Interrupt
                ldx   #0
                stx   tick_ms
                stx   tick_hms
                inx
                stx   next_hms

                pulx
                pula
                pulb
                rts
;************************
; I N I T   S I O   I N T
;************************
;
; SIO Interrupt initialisieren
;
init_SIO
                pshb
                psha
                pshx

                clr  io_outbuf_w
                clr  io_outbuf_r                  ; Output Ringbuffer initialisieren

                clr  io_inbuf_w
                clr  io_inbuf_r                   ; Input Ringbuffer initialisieren

;                oim  #%10100,TRCSR1               ; SIO Interrupt aktivieren
                oim  #%10000,TRCSR1               ; SIO Interrupt aktivieren nur für RX

                pulx
                pula
                pulb
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
                ldab TCSR2                 ; Timer Sontrol / Status Register 2 lesen
                tba
                andb #%00001000            ; Auf EOCI2 testen
                beq  ocf1

                ldab TCSR2                 ; Timer Sontrol / Status Register 2 lesen
                ldd  OCR2
                addd #285                  ; ca 7000 mal pro sek Int auslösen
                std  OCR2
                andb #1                    ;
                bne  ocf1_test             ; nur jedes 2. Mal OCF2 aufrufen
                jsr  ocf2
ocf1_test
                dec  oci_ctr
                beq  ocf1                  ; Kein OCF1 - Ende
                jmp  end_int
ocf1
                ldab #7
                stab oci_ctr

                tst  irq_wd_reset          ; währen I2C Zugriff,
                bne  oci_no_wd_reset       ; keinen Watchdog Reset durchführen
                jsr  watchdog_toggle       ; Watchdog Reset (Pseudo I2C Zugriff)
oci_no_wd_reset
                ldab TCSR1
                ldd  FRC
                addd #1994
                std  OCR1H                 ; in 1ms wieder einen Int ausführen
; General Purpose Timer
                dec  gp_timer              ; Universalvtimer--
; Basis Tick Counter
                ldx  tick_ms
                inx                        ; 1ms Tick-Counter erhöhen
                stx  tick_ms
; 100ms Tick Counter
                cpx  next_hms              ; schon 100ms vergangen?
                bne  oci_no_hms

                xgdx
                addd #100                  ; nächsten 100ms Tick Berechnen
                std  next_hms              ; und speichern

                ldx  tick_hms
                inx                        ; 100ms Tick Counter erhöhen
                stx  tick_hms

                bsr  oci_hms_timer         ; Alle 100ms Timer erhöhen
oci_no_hms
; LCD Timeout Timer aktualisieren
                ldx  lcd_timer             ; lcd_timer holen
                beq  oci_no_lcd_dec        ; falls lcd_timer schon =0, kein decrement mehr
                dex                        ; ansonsten lcd_timer--
                bne  oci_store_lcdt        ; Wenn Timer jetzt gerade abgelaufen, dann
;                oim  #%00000100, TRCSR1    ; den Transmit Interrupt wieder zulassen
oci_store_lcdt
                stx  lcd_timer             ; und speichern
oci_no_lcd_dec
; Squelch Timer
                ldab sql_timer             ; sql timer holen
                beq  oci_no_sql_dec        ; falls auf 0, nicht mehr runterzaehlen
                decb                       ; ansonsten timer--
                stab sql_timer             ; und speichern
oci_no_sql_dec
; PLL Status check
                jsr  pll_lock_chk          ; returns B=0 if PLL is NOT locked
                ldaa pll_locked_flag
                anda #$7F
                cba                        ; hat sich PLL lock Status geändert?
                beq  oci_pll_no_chg        ; Nein, dann Ende
                orab #$80                  ; "changed" Flag setzen
                stab pll_locked_flag       ; und mit dem aktuellen Status speichern
oci_pll_no_chg
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
;
;  100 MS Timer (menu, pll)
;
oci_hms_timer
                ldx  m_timer               ; m_timer = 0 ?
                beq  oci_pll_timer         ; Dann kein decrement
                dex                        ; m_timer --
                stx  m_timer               ; und sichern
oci_pll_timer
                ldab  pll_timer
                beq   oci_rc_timer
;                beq   oci_hms_timer_end
                decb
                stab  pll_timer
; Roundcount Timer
oci_rc_timer
                dec  rc_timer              ; rc timer--
                bne  oci_tone_timer        ; falls auf 0, nicht mehr runterzaehlen
                ldab #10
                stab rc_timer              ; RC Timer auf 1sek
                ldd  roundcount            ; Rundenzähler holen
                std  rc_last_sec           ; und Anzahl der Runden der letzten Sekunde speichern
                clr  roundcount
                clr  roundcount+1          ; Zähler auf 0 setzen

                ldd  ts_count
                std  ts_last_s
                clr  ts_count
                clr  ts_count+1
oci_tone_timer
                ldab tone_timer
                beq  oci_hms_timer_end
                dec  tone_timer
                bne  oci_hms_timer_end
                jsr  tone_stop
                clr  ui_ptt_req
oci_hms_timer_end
                rts
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

sin_tab
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
                rts

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


