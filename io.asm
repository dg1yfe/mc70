;****************************************************************************
;
;    MC 70    v1.0.1 - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2010  Felix Erckenbrecht, DG1YFE
;
;
;****************************************************************************
;*************
; I O
;*************
;
;
;****************
; I O   I N I T
;****************
;
; Initialisiert I/O :
;                     - Port2 DDR ( SCI TX, PLL T/R Shift )
;                     - Port6 DDR ( PTT Syn Latch )
;                     - Port5 DDR ( EXT Alarm )
;                     - Port5 Data ( EXT Alarm off (1) )
;                     - RP5CR (HALT disabled)
;                     - I2C (Clock output, Clock=0)
;                     - Shift Reg (S/R Latch output, S/R Latch = 0, S/R init)
;                     - SCI TX = 1 (Pullup)
;
;
; Parameter: keine
;
; Ergebnis : nix
;
; changed Regs: A,B

;
;
io_init
                aim  #%11100111,RP5CR     ; nicht auf "Memory Ready" warten, das statische RAM ist schnell genug
                                          ; HALT Input auch deaktivieren, Port53 wird später als Ausgang benötigt

                ldab #%10110100
                stab Port2_DDR_buf             ; Clock (I2C),
                stab Port2_DDR                 ; SCI TX, T/R Shift (PLL), Shift Reg Latch auf Ausgang

; I2C Init
                aim  #%11111011,Port2_Data     ; I2C Clock = 0
;ShiftReg Init
                aim  #%01111111,Port2_Data     ; Shift Reg Latch = 0
;SCI TX
                oim  #%10000, Port2_Data       ; SCI TX=1

                clr  SR_data_buf               ; Shuft Reg Puffer auf 0 setzen

                ldaa #~(SR_RFPA)               ; disable PA
                ldab #(SR_nTXPWR + SR_nCLKSHIFT + SR_9V6)
                                               ; disable Power control, disable clock shift, enable 9,6 V
                jsr  send2shift_reg

; Port 5
                ldab #%00001000
                stab SQEXTDDR                  ; EXT Alarm auf Ausgang, Alles andere auf Input
                stab SQEXTDDRbuf
                oim  #%00001000, SQEXTPORT     ; EXT Alarm off (Hi)

; Port 6
                ldab #%01101100
                stab Port6_DDR_buf
                stab Port6_DDR                 ; A16 (Bank Switch), PTT Syn Latch und DAC auf Ausgang

                aim  #%10011011, Port6_Data    ; Bank 0 wählen


                ldx  #bank_switch_end-bank_switch_cpy
                pshx
                ldx  #bank_switch_cpy          ; Bank Switch Routine
                ldd  #bank0                    ; In RAM verschieben
                jsr  mem_trans
                pulx

                clr  led_buf
                clr  arrow_buf
                clr  arrow_buf+1

                clr  sql_ctr
                clr  ui_ptt_req             ;
                rts


;****************************
; S E N D 2 S h i f t _ R e g
;****************************
;
; AND before OR !
;
; Parameter : B - OR-Value
;             A - AND-Value
;
; changed Regs: A,B,X
;
send2shift_reg
                inc  irq_wd_reset                ; disable IRQ Watchdog Reset
                inc  tasksw_en

                anda SR_data_buf
                staa SR_data_buf
                orab SR_data_buf
                stab SR_data_buf

;                jsr  i2c_tx

                ldaa #8                 ; 8 Bit senden
s2sr_loop
                psha                    ; Bitcounter sichern
                lslb                    ; MSB in Carryflag schieben
                bcs  s2sr_bitset        ; Sprung, wenn Bit gesetzt
                I2C_DL                  ; Bit gelöscht, also Datenleitung 0
                I2C_CH
                I2C_CL                  ; Clock Hi/Lo toggle
                bra  s2sr_dec
s2sr_bitset
                I2C_DH                  ; Data Hi
                I2C_CH
                I2C_CL                  ; Clock Hi/Lo toggle
s2sr_dec
                pula
                deca                    ; A--
                bne  s2sr_loop
                I2C_DI                  ; Data auf Input & Hi


                oim  #$80, Port2_Data
                aim  #$7F, Port2_Data            ;Shift Reg Latch toggeln - Daten übernehmen

                dec  irq_wd_reset                ; disable IRQ Watchdog Reset
                dec  tasksw_en
                rts
;****************
; S E N D 2 P L L
;****************
;
; Parameter : A - Reg Select    (0=AN, 1=R)
;             B = Divider Value ( A )
;             X = Divider Value ( N / R)
;
;             gültige Werte für N: 3-1023
;                               A: 0-127
;                               R: 3-16383
;
; changed Regs: A,B,X
;
send2pll
                inc  irq_wd_reset                ; disable IRQ Watchdog Reset
                inc  tasksw_en
                tsta
                bne  set_r                       ; which register to set
set_an
                lslb                             ; shift MSB to Bit 7 (A=7 Bit)
                ldaa #6                          ; 6 Bit shiften
set_an_loop
                lslb                             ; B ein Bit nach links
                xgdx
                rolb                             ; X/lo ein Bit nach links, Bit von B einfügen
                rola                             ; X/hi ein Bit nach links, Bit von X/lo einfügen
                xgdx
                deca                             ; Counter --
                bne  set_an_loop

                ldaa #18                         ; A/N counter 17 Bit (10+7) + Control Bit(=0)

                bra  pll_loop                    ; send Bit to PLL Shift Reg
set_r
                xgdx
                lsld
                lsld
                orab #2                          ; Set Control Bit (select R)
                xgdx
                ldaa #15                         ; 14 Bit / R counter + Control Bit
pll_loop
                lslb                             ; B ein Bit nach links
                xgdx
                rolb                             ; X/lo ein Bit nach links, Bit von B einfügen
                rola                             ; X/hi ein Bit nach links, Bit von X/lo einfügen
                                                 ; Shift next Bit into Carry Flag
                xgdx

                psha                             ; A sichern
                bcc  pll_bit_is_0                ; test Bit
                I2C_DH                           ; I2C Data = high
                bra  pll_nextbit
pll_bit_is_0
                I2C_DL                           ; I2C Data = low

pll_nextbit
                I2C_CTGL                         ; I2C Clock, high/low toggle
                pula                             ; restore A
                deca                             ; Counter--
                bne  pll_loop
                I2C_DI                           ; I2C Data wieder auf Input
                oim  #%00001000, Port6_Data      ; PLL Syn Latch auf Hi
                nop
                nop
                aim  #%11110111, Port6_Data      ; PLL Syn Latch auf Lo
                dec  irq_wd_reset                ; re-enable Watchdog Reset
                dec  tasksw_en
                rts
;
;
;
;**********************************************
; I 2 C
;**********************************************
;
;*******************
; I 2 C   S T A R T
;*******************
;
; I2C "START" Condition senden
;
; changed Regs: NONE
;
i2c_start
                psha
                I2C_DH                 ; Data Leitung auf Hi / CPU auf Eingang
                I2C_CH                 ; Clock Hi
                I2C_DL                 ; Datenleitung auf low
                I2C_CL                 ; Clock Lo
                pula
                rts
;******************
; I 2 C   S T O P
;******************
;
; I2C "STOP" Condition senden
;
; changed Regs: NONE
;
i2c_stop
                psha
                I2C_DL                 ; Datenleitung auf low
                I2C_CH                 ; Clock Leitung auf Hi
                I2C_DH                 ; Data Leitung auf Hi / CPU auf Eingang
                I2C_CL                 ; Clock Leitung auf Lo
                pula
                rts

;***************
; I 2 C   A C K
;***************
;
; I2C "ACK" senden
; Bestätigung des Adress und Datenworts -> 0 im 9. Clock Zyklus senden
;
; changed Regs: NONE
;
i2c_ack
                psha
                I2C_DL                 ; Data low
                I2C_CH                 ; Clock Hi
                I2C_CL                 ; Clock Lo
                I2C_DI                 ; Data wieder auf Eingang
                pula
                rts

;***********************
; I 2 C   T S T A C K
;***********************
;
; I2C "ACK" prüfen
; Bestätigung des Adress und Datenworts -> 0 im 9. Clock Zyklus senden
;
; Ergebnis    : A - 0 : Ack
;                   1 : No Ack / Error
;
; changed Regs: A
;
i2c_tstack
                I2C_DI                  ; Data Input
;                I2C_CTGL                ; clock Hi/Lo
                I2C_CH                  ; I2C Clock Hi
                ldaa Port2_Data         ;
                I2C_CLb                 ; I2C Clock Lo
                anda #$02               ; I2C Datenbit isolieren
                lsra                    ; an Pos. 0 schieben
                rts

;*************
; I 2 C   T X
;*************
;
; 8 Bit auf I2C Bus senden
;
; Parameter: B - Datenwort, wird mit MSB first auf I2C Bus gelegt
;
;
;
i2c_tx
                pshb
                psha

                ldaa #8                 ; 8 Bit senden
itx_loop
                psha                    ; Bitcounter sichern
                lslb                    ; MSB in Carryflag schieben
                bcs  itx_bitset         ; Sprung, wenn Bit gesetzt
                I2C_DL                  ; Bit gelöscht, also Datenleitung 0
                I2C_CH
                I2C_CL                  ; Clock Hi/Lo toggle
                bra  itx_dec
itx_bitset
                I2C_DH                  ; Data Hi
                I2C_CH
                I2C_CL                  ; Clock Hi/Lo toggle
itx_dec
                pula
                deca                    ; A--
                bne  itx_loop
                I2C_DI                  ; Data auf Input & Hi
                pula
                pulb
                rts
;*************
; I 2 C   R X
;*************
;
; Byte auf I2C Bus empfangen
;
; Ergebnis : B - Empfangenes Byte
;
; changed Regs: B
;
i2c_rx
                psha
                pshx
                clra
                psha                    ; temporären Speicher für empfangenes Byte

                tsx
                I2C_DI                  ; I2C Data Input
                ldaa #$80               ; Mit MSB beginnen
irx_loop
                I2C_CHb
                ldab Port2_Data         ; Daten einlesen
                andb #%10
                tstb                    ; Bit gesetzt?
                beq  irx_shift          ; Nein, dann kein Bit einfügen
                tab
                oraa 0,x                ; Wenn gesetzt, dann Bit einfügen
                staa 0,x                ; und speichern
                tba
irx_shift
                I2C_CLb                 ; Clock toggle
                lsra                    ; nächstes Bit
                bcc  irx_loop           ; wenn noch ein Bit zu empfangen ist -> loop

                pulb                    ; Ergebnis holen

                pulx                    ; X und
                pula                    ; A wiederherstellen
                rts

;**********************************************
; S C I
;**********************************************
;***********************
; I N I T _ S C I
;***********************
sci_init
                ldab #51						; TODO: MACRO
                stab TCONR                      ; Counter für 1200 bps

                ldab #%10000
                stab TCSR3                      ; Timer 2 aktivieren, Clock = E (Sysclk/4=2MHz), no Timer output

                ldab #%110100                   ; 7 Bit, Async, Clock=T2
                stab RMCR

                ldab #%110                      ; 1Stop Bit, Odd Parity, Parity enabled
                stab TRCSR2

                ldab #%1010
                stab TRCSR1                     ; TX & RX enabled, no Int

                rts

;************************
; S C I   R X
;************************
;                        A : Status (0=RX ok, 3=no RX)
;                        B : rxd Byte
;             changed Regs : A, B, X
;
sci_rx
                ldab io_inbuf_r           ; Zeiger auf Leseposition holen
                cmpb io_inbuf_w           ; mit Schreibposition vergleichen
                beq  src_no_data          ; Wenn gleich sind keine Daten gekommen
                ldx  #io_inbuf            ; Basisadresse holen
                abx                       ; Zeiger addieren, Leseadresse berechnen
                ldaa 0,x                  ; Datenbyte aus Puffer lesen
                incb                      ; Zeiger++
                andb #$io_inbuf_mask      ; Im gültigen Bereich bleiben
                stab io_inbuf_r           ; neue Zeigerposition speichern
                tab                       ; Datenbyte nach B
                clra                      ; A = 0
                rts
src_no_data
                ldaa #3
                clrb
                rts
;************************
; S C I   R E A D
;************************
;
; Zeichen vom serieller Schnittstelle lesen (blocking)
;
;                         B : rxd Byte
;              changed Regs : A, B, X
;
sci_read
                ldab io_inbuf_r           ; Zeiger auf Leseposition holen
                cmpb io_inbuf_w           ; mit Schreibposition vergleichen
                beq  sci_read             ; Wenn gleich sind keine Daten gekommen -> warten
                ldx  #io_inbuf            ; Basisadresse holen
                abx                       ; Zeiger addieren, Leseadresse berechnen
                ldaa 0,x                  ; Datenbyte aus Puffer lesen
                incb                      ; Zeiger++
                andb #$io_inbuf_mask      ; Im gültigen Bereich bleiben
                stab io_inbuf_r           ; neue Zeigerposition speichern
                tab                       ; Datenbyte nach B
                clra                      ; A = 0
                rts

;************************
; S C I   R X   M
;************************
;
; Echo/Kommandobestätigung lesen
;
;                         A : Status (0=RX ok, 1=no RX)
;                         B : rxd Byte
;              changed Regs : A, B
;
sci_rx_m
                ldab io_menubuf_r         ; Zeiger auf Leseposition holen
                cmpb io_menubuf_w         ; mit Schreibposition vergleichen
                beq  srm_no_data          ; Wenn gleich sind keine Daten gekommen
                ldx  #io_menubuf          ; Basisadresse holen
                abx                       ; Zeiger addieren, Leseadresse berechnen
                ldaa 0,x                  ; Datenbyte aus Puffer lesen
                incb                      ; Zeiger++
                andb #io_menubuf_mask     ; Im Bereich 0-7 bleiben
                stab io_menubuf_r         ; neue Zeigerposition speichern
                tab                       ; Datenbyte nach B
                clra                      ; A = 0
                rts
srm_no_data
                ldaa #1
                clrb
                rts

;************************
; S C I   R E A D   M
;************************
;
; Eingabe von Display lesen (blocking)
;
; Parameter:  none
;
; Ergebnis :  A : raw data
;             B : converted data
;
;  changed Regs : A, B
;
;
sci_read_m
                ldab io_menubuf_r         ; Zeiger auf Leseposition holen
                cmpb io_menubuf_w         ; mit Schreibposition vergleichen
                bne  srdm_cont            ; Wenn nicht gleich sind Daten gekommen -> weitermachen
                swi                       ; sonst Taskswitch
                ldd  m_timer              ; check m_timer
                bne  sci_read_m           ; loop if not zero
                ldaa #-1
                rts                       ; otherwise return with error code
srdm_cont
                ldx  #io_menubuf          ; Basisadresse holen
                abx                       ; Zeiger addieren, Leseadresse berechnen
                ldaa 0,x                  ; Datenbyte aus Puffer lesen
                incb                      ; Zeiger++
                andb #io_menubuf_mask     ; Im Bereich 0-7 bleiben
                stab io_menubuf_r         ; neue Zeigerposition speichern
                tab                       ; Datenbyte nach B
                pshx
                ldx  #key_convert         ; index key convert table
                abx
                ldab 0,x                  ; Key übersetzen
                pulx
                rts

;************************
; S C I   T X   B U F
;************************
sci_tx_buf
                ;B : TX Byte
                ;A : Status (0=ok, 1=buffer full)
                tab
                ldab io_outbuf_w          ; Zeiger auf Schreibposition holen
                incb                      ; erhöhen
                andb #io_outbuf_mask      ; Im Bereich 0-(size-1) bleiben
                cmpb io_outbuf_r          ; mit Leseposition vergleichen
                beq  stb_full             ; Wenn gleich, ist Puffer voll

                ldab io_outbuf_w          ; Zeiger auf Schreibposition holen
                ldx  #io_outbuf           ; Basisadresse holen
                abx                       ; Zeiger addieren, Schreibadresse berechnen
                staa 0,x                  ; Datenbyte aus Puffer lesen
                incb                      ; Zeiger++
                andb #io_outbuf_mask      ; Im Bereich 0-(size-1) bleiben
                stab io_outbuf_w          ; neue Zeigerposition speichern
                clra                      ; A = 0
                rts
stb_full
                ldaa #1
                rts
;************************
; S C I   T X
;************************
sci_tx
                ;B : TX Byte
                ;changed Regs: none
                psha
stx_wait_tdr_empty1
                ldaa TRCSR1
                anda #%00100000
                beq  stx_wait_tdr_empty1   ; sicher gehen dass TX Register leer ist
stx_writereg
                stab TDR                   ; Byte in Senderegister
stx_wait_tdr_empty2
;                ldaa TRCSR1
;                anda #%00100000
;                beq  stx_wait_tdr_empty2   ; Warten bis es gesendet wurde
                pula
                rts
;
;************************
; S C I   T X   W
;************************
;
; Sendet Zeichen in B nach Ablauf des LCD_TIMER. Setzt abhängig von gesendeten
; Zeichen den Timer neu. Berücksichtigt unterschiedliche Timeouts für $78, $4F/$5F und Rest
;
; Parameter    : B - zu sendendes Zeichen
;
; Ergebnis     : Nichts
;
; changed Regs : None
;
sci_tx_w
                pshb
                psha
                pshx                       ; x sichern
stw_chk_lcd_timer
                ldx  lcd_timer             ; lcd_timer holen
                beq  stw_wait_tdr_empty1   ; warten falls dieser >0 (LCD ist noch nicht bereit)
                swi                       ; Taskswitch
                bra  stw_chk_lcd_timer
stw_wait_tdr_empty1
                ldaa TRCSR1
                anda #%00100000
                beq  stw_wait_tdr_empty1
stw_writereg
                stab TDR
stw_wait_tdr_empty2
                ldaa TRCSR1
                anda #%00100000
                swi
                beq  stw_wait_tdr_empty2

                tba
                oraa #$10
                cmpa #$5D              ; auf 4D/5D prüfen - extended char
                beq  stw_end           ; nächstes Zeichen OHNE Delay senden
                oraa #$01
                cmpa #$5F              ; auf 4E/4F/5E/5F prüfen - extended char
                beq  stw_end           ; nächstes Zeichen OHNE Delay senden

                cmpb #$78              ; LCD Clear Zeichen?
                bcs  stw_10ms          ; Alles was <$78 ist mit normalem Delay
                ldx  #LCDDELAY*4       ; vierfacher Timeout für Clear & Reset Befehle
                stx  lcd_timer
                bra  stw_end
stw_10ms
                ldx  #LCDDELAY         ; normaler Timeout für Rest (außer 4f/5f)
                stx  lcd_timer
stw_end
                pulx
                pula
                pulb
                rts

;************************
; C H E C K   I N B U F
;************************
;
; Parameter : none
; Result    : A - Bytes in Buffer
;
check_inbuf
                ldaa io_inbuf_w
                suba io_inbuf_r
                anda #io_inbuf_mask
                rts
;
;************************
; C H E C K   O U T B U F
;************************
;
; Parameter : none
; Result    : A - Bytes in Buffer
;
check_outbuf
                ldaa io_outbuf_r
                suba io_outbuf_w
                anda #io_outbuf_mask
                rts
;
;****************
; S C I   A C K
;****************
;
; Parameter : B - gesendetes Zeichen, das bestätigt werden soll
;
; Result    : A - 0 = OK
;                 1 = Error / Timeout
;
sci_ack
                pshb                   ; Zeichen sichern
                ldaa #1
                psha

sak_empty_buf
                jsr  check_inbuf       ; Empfangspuffer überprüfen
                tsta
                beq  sak_start_chk     ; Wenn kein Zeichen
                decb
                beq  sak_start_chk     ; oder ein Zeichen drin ist, mit Auswertung fortsetzen
                jsr  sci_read          ; Ansonsten alle Zeichen ausser letztem lesen
                bra  sak_empty_buf
sak_start_chk
                ldab #LCDDELAY
                stab gp_timer          ; Timer setzen
sak_loop
                ldab gp_timer          ; Timer abgelaufen?
                beq  sak_end           ; Dann Fehler ausgeben
                jsr  check_inbuf       ; Ist was im Ack Buffer?
                tsta
                bne  sak_getanswer     ; Ja, dann nachsehen was es ist
                swi                    ; Nix im Puffer - dann erstmal Taskswitch machen
                bra  sak_loop          ; nochmal nachsehen
sak_getanswer
                jsr  sci_read          ; Zeichen holen
                cmpb #$7F              ; Fehler? (Es wurde eine Taste gedrückt)
                bne  sak_chk_cmd
                bsr  sci_read_cmd      ; Ja, dann Kommando lesen und in Puffer für Menü speichern
                bra  sak_end
sak_chk_cmd
                tsx
                cmpb 1,x               ; Empfangenes Zeichen = gesendeten Zeichen?
                beq  sak_ok            ; Ja, dann zurück
                cmpb #$74              ; auf 'Input lock' prüfen
                beq  sak_unlock
                jsr  check_inbuf       ; Noch Zeichen im Puffer?
                tsta
                bne  sak_getanswer     ; Ja, dann nochmal Vergleich durchführen
                bra  sak_end           ; Ansonsten Ende mit Fehlermeldung
sak_ok
                tsx
                clr  0,x               ; Alles ok, A=0 => kein Fehler
sak_end
                pula
                pulb
                rts
sak_unlock
                ldab #$75              ; Kleiner Hack um bei Fehler der als "Keylock an" interpretiert wurde
                ldaa #'p'              ; Diesen wieder zu deaktivieren
                jsr  putchar
                bra  sak_end           ; Ende mit Fehlermeldung

;****************************
; S C I   R E A D   C M D
;****************************
;
; Parameter : B - Kommando / Eingabe Byte
;
; Returns : nothing
;
;
sci_read_cmd
                jsr  sci_read          ; Zeichen holen
                pshb
src_empty_buf
                jsr  sci_rx
                tsta
                beq  src_empty_buf     ; Solange Zeichen lesen bis Puffer leer ist
                pulb                   ; Zeichen zurückholen
                jsr  sci_tx_w          ; Bestätigung senden
                jsr  men_buf_write     ; Eingabe in Menü Puffer ablegen
                rts
;****************************
; S C I   T R A N S   C M D
;****************************
;
; Parameter : none
;
; Returns : none
;
;
sci_trans_cmd
                pshb
                psha
                pshx

                jsr  sci_rx            ; Zeichen holen
                tsta
                bne  stc_end           ; Falls nichts vorhanden - Ende
stc_clear_buf
                cmpb #$20              ; Werte >= $20 sind keine Eingaben
                bcc  stc_end
                jsr  check_inbuf       ; Prüfen wieviele Byte im Input Speicher sind
                beq  stc_ack           ; Wenn das letzte gerade gelesen wurde, ACK senden
                jsr  sci_read          ; nächstes Zeichen lesen
                bra  stc_clear_buf     ; loop
stc_ack
                jsr  sci_tx_w          ; Sonst Bestätigung senden
                jsr  men_buf_write     ; und Eingabe in Menü Puffer ablegen
stc_end
                pulx
                pula
                pulb
                rts
;****************************
; M E N   B U F   W R I T E
;****************************
;
; Parameter : B - Kommando / Eingabe Byte
;
; Returns : nothing
;
;
;
men_buf_write
                pshb
                psha
                pshx
                tba
                ldab io_menubuf_w          ; Zeiger auf Schreibadresse holen
                incb                       ; prüfen ob Puffer schon voll
                andb #io_menubuf_mask      ; maximal 15 Einträge
                cmpb io_menubuf_r          ; Lesezeiger schon erreicht?
                beq  mbw_end               ; Overrun Error, Zeichen verwerfen
                ldab io_menubuf_w          ; Zeiger erneut holen
                ldx  #io_menubuf           ; Basisadresse holen
                abx                        ; beides addieren -> Schreibadresse bestimmen
                staa 0,x                   ; Datenbyte schreiben
                incb                       ; Zeiger++
                andb #io_menubuf_mask      ;
                stab io_menubuf_w          ; und speichern
mbw_end
                pulx
                pula
                pulb
                rts

;
;************************************************
;
;************************
; P U T C H A R
;************************
;
; Putchar Funktion, steuert das Display an.
;
; Parameter : A - Modus
;                 'c' - ASCII Char, Char in B (ASCII $20-$7F, $A0-$FF = char + Blink)
;                 'x' - unsigned int (hex, 8 Bit)
;                 'u' - unsinged int (dezimal, 8 Bit)
;                 'l' - longint (dezimal, 32 Bit)
;                 'p' - PLAIN, gibt Zeichen unverändert aus, speichert es NICHT im Puffer
;                       Anwendung von 'p' : Senden von Display Befehlen (Setzen des Cursors, Steuern der LEDs, etc.)
;
;
;             B - Zeichen in Modus c,x,u,p
;                 Anzahl nicht darzustellender Ziffern in Modus 'l' (gezählt vom Ende! - 1=Einer, 2=Zehner+Einer, etc...)
;
;             Stack - Longint in Modus l
;
;
; Ergebnis :    nothing
;
; changed Regs: A,B,X
;
; changed Mem : CPOS,
;               DBUF,
;               Stack (longint)
;
;
putchar
               cmpa #'u'
               bne  pc_testlong
               jsr  uintdec
               jmp  pc_end
pc_testlong
               cmpa #'l'
               bne  pc_testhex
               jsr  ulongout
               jmp  pc_end
pc_testhex
               cmpa #'x'
               bne  pc_testchar
               jsr  uinthex
               jmp  pc_end
pc_testchar
               cmpa #'c'
               bne  pc_testplain
               jmp  pc_char_out
;               ldx  char_vector
;               jmp  0,x
;               pc_char_out
pc_testplain
               cmpa #'p'
               bne  pc_to_end
;               ldx  plain_vector
;               jmp  0,x
               jmp  pc_ext_send2    ; Plain - sende Bytevalue wie erhalten
pc_to_end
               jmp  pc_end          ; unsupported mode, abort/ignore

pc_char_out    ; ASCII Zeichen in B
               ldaa cpos            ; Cursorposition holen
               cmpa #8              ; Cursorpos >=8?
               bcc  pc_end          ; Dann ist das Display voll, nix ausgeben (geht auch viel schneller)
               jsr  pc_cache        ; Prüfen ob Zeichen schon an dieser Position geschrieben wurde
               tsta                 ; Wenn ja,
               beq  pc_end          ; dann nichts ausgeben
               jsr  store_dbuf      ; Zeichen in Displaybuffer speichern (ASCII)

;pc_convert_out
               tba                  ; save character to print
               andb #~CHR_BLINK     ; exclude Blink Bit

               subb #$20            ; ASCII chars <$20 not supported
               pshb                 ; Index merken

               psha                 ; save character to print
               clra                 ; HiByte = 0

               lsld                 ; Index für Word Einträge berechnen
               addd #char_convert   ; Basisadresse hinzufügen
               xgdx
               ldd  0,x             ; D=Eintrag in char_convert Tabelle

               xgdx
               pulb                 ; restore character to print
               andb #CHR_BLINK      ; check if should be printed blinking
               xgdx
               beq  pc_sendchar     ; if not, print plain
               tsta                 ; check if it is an extended or a single char
               beq  pc_blink_single
               oraa #$10            ; include blink bit in extended char code
               bra  pc_sendchar
pc_blink_single
               orab #$10            ; include blink bit in single char code

pc_sendchar
               pshb
               psha                   ; Tabellenzeichen merken
               tsta
               beq  pc_single         ; Zeichencode mit 1 Bytes?
               tab
pc_double
               jsr  sci_tx_w          ; Zeichen senden
               jsr  sci_ack           ; Auf Bestätigung warten
               tsta                   ; Zeichen erfolgreich gesendet?
               bne  pc_double         ; Wenn nicht, nochmal senden
               tsx
               ldab 1,x               ; 2. Byte vom Tabelleneintrag holen
pc_single                             ; Ausgabe von Zeichencodes mit 1 Byte
               jsr  sci_tx_w          ; send char from table
               jsr  sci_ack           ; Auf Quittung warten
               tsta                   ; Erfolgreich gesendet?
               bne  pc_single         ; Nein? Dann nochmal probieren
               pula                   ; gemerkten Tabelleneintrag holen
               ins                    ; lower char aus Tabelle wird nicht mehr benötigt,
               tab                    ; Blink Status ($4x / $5x) aber schon

               orab #$10
               cmpb #$5D              ; War Byte 1 = $4D oder $5D?
               beq  pc_extended       ; dann müssen wir noch ein $4E Char senden
               pulb                   ; gemerkten Index vom Stack löschen
               bra  pc_end
pc_extended
               anda #$10              ; Blink Bit isolieren
               ldx  #e_char_convert
               pulb                   ; gemerkten index vom Stack holen
               abx                    ; Tabelle indizieren
               ldab 0,x               ; extended character holen
               pshb                   ; Character sichern
               adda #$4E              ; Extended Zeichen senden, zu Blink Bit addieren
               tab                    ; nach B transferieren
pc_ext_send1
               jsr  sci_tx_w          ; send char
               jsr  sci_ack           ; Bestätigen lassen
               tsta
               bne  pc_ext_send1      ; nochmal senden, falls erfolglos gesendet

               pulb                   ; Character senden
pc_ext_send2
               jsr  sci_tx_w          ; send char
               jsr  sci_ack           ; Echo Char lesen
               tsta                   ; bei Fehler
               bne  pc_ext_send2      ; wiederholen
pc_end
               rts

pc_terminal
               jsr  sci_tx
               jmp  pc_end


;******************
; P C   C A C H E
;
; Putchar Subroutine
;
; Funktion zur Beschleunigung der Displayausgabe
; Überspringt Zeichen, die schon auf dem Display vorhanden sind
; Falls ein Unterschied zwischen vorhandenem und zu schreibenden Zeichen
; auftritt, wird der Cursor von dieser Funktion korrekt positioniert
;
; Parameter : B - Zeichen (ASCII)
;
; Ergebnis :  A - 0 = Zeichen überspringen
;                 1 = Zeichen ausgeben
;
pc_cache
               pshb
               pshx
               tba                    ; Zeichen nach A

               ldx  #dbuf
               ldab cpos              ; Cursorposition holen
               abx                    ; Zeichen unter dem Cursor addressieren
               cmpa 0,x               ; Mit auszugebenden Zeichen vergleichen
               beq  pcc_same          ; Wenn es gleich ist, Zeichen nicht ausgeben

               ldaa pcc_cdiff_flag    ; Unterscheidet sich Cursorposition in CPOS von tatsächlicher Cursorposition?
               beq  pcc_diff          ; Nein, dann weitermachen - Returnvalue = 'Zeichen ausgeben'

               ldaa #'p'
               addb #$60              ; $60 zu Cursorposition addieren -> Positionierungsbefehl erzeugen
               jsr  putchar           ; Cursor korrekt positionieren
               clr  pcc_cdiff_flag    ; Flag löschen, Positionen stimmen wieder überein
               bra  pcc_diff
pcc_same
               inc  cpos              ; Cursor weitersetzen
               ldab #1
               stab pcc_cdiff_flag    ; Cursorposition in CPOS unterscheidet sich von tatsächlicher
               clra                   ; Returnvalue: 'Zeichen überspringen'
               bra  pcc_end
pcc_diff
               ldaa #1
pcc_end
               pulx
               pulb
               rts

;***************
; U I N T H E X
;
; Putchar Subroutine
;
; Formatiert einen 8 Bit Integer für Hexadezimale Darstellung um und gibt ihn aus
;
; Parameter : B - 8 Bit Integer
;
; Ergebnis : none
;
; changed Regs : A,B,X
;
uinthex
               pshb                               ; Wert sichern
               lsrb
               lsrb
               lsrb
               lsrb                               ;  Hi Nibble in die unteren 4 Bit schieben

               bsr  sendnibble                    ; Nibble ausgeben
               pulb                               ; Wert wiederholen
               andb #$0F                          ; Hi Nibble ausblenden

               bsr  sendnibble                    ; Nibble ausgeben
               rts

;**********************
; S E N D   N I B B L E
;
; Putchar Subroutine
;
; Gibt einen 4 Bit Wert als HEX Digit (0-9,A-F) aus
;
; Parameter : B - 4 Bit Wert
;
; Ergebnis : none
;
; changed Regs : A,B,X
;
;
sendnibble     ; Nibble to send in B
               cmpb #10                         ; Wert
               bcs  snb_numeric                 ; >=10 ? Dann
               addb #7                          ; 7 addieren (Bereich A-F)
snb_numeric
               addb #$30                        ; $30 addieren, 0->'0' ... 9->'9' ... 10 ->'A' ... 15 ->'F'
               ldaa #'c'                        ; Als
               jsr  putchar                     ; Char ausgeben
               rts

;****************
; U I N T   D E C
;
; Putchar Subroutine
;
; Formatiert einen 8 Bit Integer für Dezimale Darstellung um und gibt ihn aus
;
; Parameter : B - 8 Bit Integer
;
; Ergebnis : none
;
; changed Regs : A,B,X
;
;
uintdec
               cmpb #10
               bcs  einer

               clra
               ldx  #10
               jsr  divide
               pshx                    ; Rest speichern - ergibt die Einer
               cmpb #10
               bcs  zehner

               clra
               ldx  #10
               jsr  divide
               pshx                    ; Rest speichern - ergibt die Zehner

               addb #$30
               ldaa #'c'
               jsr  putchar
               pulx                    ; Zehner wiederholen
               xgdx                    ; vom X ins AB Register transferieren
zehner
               addb #$30
               ldaa #'c'
               jsr  putchar
               pulx                    ; Einer wiederholen
               xgdx                    ; vom X ins AB Register transferieren
einer
               addb #$30
               ldaa #'c'
               jsr  putchar

               rts

;******************
; U L O N G   O U T
;
; Putchar Subroutine
;
; Formatiert einen 32 Bit Integer für Dezimale Darstellung um und gibt ihn aus
;
; Parameter : B - Anzahl der vom Ende der Zahl abzuschneidenden Ziffern
;             A - Anzahl der mindestens auszugebenden Stellen (MSB = fill with space)
;
;             Stack - 32 Bit Integer
;
; Ergebnis : none
;
; changed Regs : A,B,X
;
;
; 7 Long LoWord,LoByte
; 6 Long LoWord,HiByte
; 5 Long HiWord,LoByte
; 4 Long HiWord,HiByte
; 3 R-Adresse2 lo
; 2 R-Adresse2 hi
; 1 R-Adresse1 lo
; 0 R-Adresse1 hi
;
ulongout
               clra
               tsx
               inx
               inx
               inx
               inx
udecout
               psha                    ; Minimum digits to Stack
               pshx                    ; Zeiger auf Longint auf Stack
               andb #7                 ; max. 7 Stellen abschneiden
               pshb                    ; Exponent auf stack
               tsx
               ldab #9                 ; index für 10^x Tabelle berechnen
               sbcb 0,x
               ins                     ; Exponent vom Stack löschen
; TODO Überprüfung auf b>9
               lslb
               lslb                    ; Index *4 (DWords werden adressiert)
               ldx  #exp10_9
               abx                     ; 10er Potenz Tabelle adressieren
               ldd  2,x                ; LoWord lesen
               pshb
               psha
               ldx  0,x                ; HiWord lesen und beides
               pshx                    ; als Divisor auf Stack
               jsr  divide3232         ; 32 Bit Division durchführen
               pulx
               pulx                    ; Rest löschen
               pulx                    ; Zeiger holen
               ldab #$ff
               pshb
ulo2_divloop
               pshx                    ; Zeiger auf Longint Kopie auf Stack legen (Dividend)
               ldd  #10
               jsr  divide32s          ; Longint durch 10 dividieren
               xgdx                    ; Rest (0-9) nach D
               pulx                    ; Zeiger auf Quotient holen
               pshb                    ; Rest auf Stack
               ldab 3,x
               orab 2,x
               orab 1,x
               orab 0,x
               xgdx
               subd #6
               xgdx
               ldaa 0,x
               anda #$7f
               tpa
               beq  ulo2_nodecr
               dec  0,x                ; decrement min number of digits
ulo2_nodecr
               xgdx
               addd #6
               xgdx
               tstb                    ; Prüfen ob Quotient = 0
               bne  ulo2_divloop       ; Wenn nicht, dann erneut teilen
               tap
               bne  ulo2_divloop       ; Mindestanzahl noch nicht erreicht
               xgdx
               subd #6
               xgdx
               ldaa 0,x
ulo2_prntloop
               pulb
               cmpb #$ff               ; Prüfen ob alle Ergebniswerte vom Stack gelesen wurden
               beq  ulo2_end           ; Ja, dann Ende
               tstb
               beq  ulo_zero           ; print accorcing to modifier if digit is 0
               clra                    ; print everything from 1st non-zero digit
ulo_zero
               tsta                    ; print zero (A=0) or space (A!=0)
               beq  ulo_print
               ldab #$f0
ulo_print
               addb #$30               ; $30 addieren
               ldaa #'c'
               jsr  putchar            ; Zeichen ausgeben
               bra  ulo2_prntloop      ;
ulo2_end
               ins
               rts

;**********************
; S T O R E   D B U F
;
; Putchar Subroutine
;
; stores Byte from B in Display Buffer - if Space left
;
; changed Regs: NONE
;
store_dbuf
               pshb
               psha
               pshx                    ; Save X-Reg
               tba                     ; Char nach A
               ldab cpos               ; Get Cursor Position
               cmpb #8                 ; cursor outside of Display?
               bcc  store_dbuf_end     ;
               ldx  #dbuf              ; get display buffer base address
               abx                     ; add index
               staa 0,x                ; store byte
               inc  cpos               ; inc cpos
store_dbuf_end
               pulx
               pula
               pulb
               rts

;
;************************************
; P R I N T F
;************************************
;
;
;
; 7 - Arg
#define PES_ARG      7
; 5 - Return
; 4 - B
; 3 - A
; 2 - ARG Offset
#define PES_ARG_OFS  2
; 1 - Modifier2
; 0 - Modifier1
#define PES_MODIF1   1
#define PES_MODIF2   0

printf
               ; X : Pointer auf 0-terminated String
               ; Stack : Variables
               ; changed Regs: X
               pshb
               psha
               clra
               psha
               des
               des
print_loop
               ldab 0,x             ; Zeichen holen
               beq  end_printf      ; =$00 ? Dann String zu Ende -> Return
               inx                  ; Zeiger auf nächstes Zeichen
               cmpb #'%'            ; auf "%" testen
               beq  print_escape    ;
print_char
               ldaa #'c'
print_put
               pshx
print_putpl
               jsr  putchar
               tsx
               clr  2,x
               clr  3,x             ; clear modifier variables
               pulx
               bra  print_loop
print_end
end_printf
               ins
               ins
               ins
               pula
               pulb
               rts
print_escape
               pula
               ins
               psha
               pshb                    ; remember the 2 bytes read before
               ldab 0,x                ; read next byte
               beq  print_end
               inx
               tba
               anda #~$20              ; ignore case
               cmpa #'x'
               beq  pes_hex
               cmpa #'i'
               beq  pes_dec
               cmpa #'d'
               beq  pes_dec
               cmpa #'s'
               beq  pes_str
               cmpa #'c'
               beq  pes_char
               cmpb #'%'
               beq  print_char         ; print "%"
                                       ; all types have been checked
               cmpb #'9'+1             ; check possible modifiers for sanity
               bcc  print_loop         ; (only numeric values allowed)
               cmpb #'0'
               bcs  print_loop
               bra  print_escape
;**********
pes_char
               pshx
               tsx
               ldab 2+PES_ARG_OFS,x    ; get Offset of next Variable
               inc  2+PES_ARG_OFS,x    ; increment offset
               abx
               ldab 2+PES_ARG,x        ; get variable
               pulx
               bra  print_char         ; print as character
;**********
pes_str
               pshx
               tsx
               ldab 2+PES_ARG_OFS,x    ; get Offset of next Variable
               tba
               adda #2
               staa 2+PES_ARG_OFS,x    ; store new Offset
               abx
               ldx  2+PES_ARG,x        ; get pointer
pst_loop
               ldab 0,x                ; get char from string
               beq  pst_return         ; exit on "NULL"
               ldaa #'c'
               pshx
               jsr  putchar            ; print char
               pulx
               bra  pst_loop           ; loop
pst_return
               pulx
               bra  print_loop         ; print as character
;**********
pes_hex
               pshx
               tsx
               ldab 2+PES_ARG_OFS,x    ; get Offset of next Variable
               inc  2+PES_ARG_OFS,x    ; increment offset
               abx
               ldab 2+PES_ARG,x        ; get variable
               pshb
               tsx
               ldaa 3+PES_MODIF2,x     ; get modifier 2
phx_print
               tsx
               ldab 1,x
               lsrb
               lsrb
               lsrb
               lsrb
               cmpa #'0'               ; check if '0' modifier was given
               beq  phx_hinib          ; if it was, print both nibbles
               tstb                    ; if not, test hi nibble
               beq  phx_lonib          ; omit printout if it is zero
phx_hinib
               jsr  sendnibble         ; print hi nibble
phx_lonib
               pulb
               andb #$0f
               jsr  sendnibble         ; print lo nibble
               pulx
               jmp  print_loop         ; continue
;**********
pes_dec
               pshx                    ; put String pointer onto stack
               tsx
               ldab 2+PES_ARG_OFS,x    ; get Offset of next Variable
               tba
               adda #4
               staa 2+PES_ARG_OFS,x    ; increment offset
               abx
               pshx                    ; push pointer to long onto stack
               tsx
               ldaa 4+PES_MODIF2,x     ; get modifier 2
               beq  pdc_print          ; if there is no modifier 2, print unmodified
               cmpa #'+'               ; sign modifier?
               beq  pdc_print          ; then start print
; "%+02i"->print at least 2 digits, use 0 to prepend, always print sign
; "%02i"-> print at least 2 digits, use 0 to prepend, print sign for neg. values
; "%+2i"-> print at least 2 digits with sign, use space to prepend
; "%2i" -> print at least 2 digits, use space to prepend
; "%+i" -> print w sign
pdc_modif1
               ldab 4+PES_MODIF1,x     ; get modifier 1
               beq  pdc_fws            ; if there is none, start print, fill with space
               cmpb #'0'
               beq  pdc_zero           ; fill with '0'
pdc_fws
               ldab #$80               ; load 'fill with space' modifier bit
               suba #'0'               ; convert ascii char to number of digits to print
               aba                     ; add number of digits to print
               bra  pdc_print
pdc_zero
               suba #'0'               ; convert ascii char to number of digits to print
pdc_print
               pulx
               psha
               pshx
               ldd  0,x                ; test sign of longint
               bpl  pdc_chksprint      ; if positive, check if sign should be shown
               jsr  sig_inv32s         ; invert sign
               ldab #'-'
               ldaa #'c'
               jsr  putchar

               clrb                    ; do not truncate printout
               pulx                    ; get longint pointer from stack
               pula
               pshx
               jsr  uintdec
               pulx
               jsr  sig_inv32s         ; invert sign back
               pulx                    ; get pointer to next char from stack
               jmp  print_loop         ; continue
pdc_chksprint
               tsx
               ldab 3+2+PES_MODIF2,x   ; get modifier 2
               beq  pdc_noprintsign    ; if it was unset, continue with printing
               cmpb #'+'               ; if it was '+',
               beq  pdc_printsign      ; print the sign char
               ldab 3+2+PES_MODIF1,x   ; get modifier 1
               beq  pdc_noprintsign    ; if it was unset, continue with printing
               cmpb #'+'               ; if it was '+'
               beq  pdc_printsign      ; print the sign char
               tsx
               ldd  3,x                ; get pointer to next string char
               subd #4                 ; point to char before modifier 1
               ldab 0,x                ; get char befor Modifier 1
               cmpb #'+'               ; check if this was a '+'
               bne  pdc_noprintsign    ; if not, branch and dont print the sign
pdc_printsign
               ldab #'+'               ; print the sign
               ldaa #'c'
               jsr  putchar
pdc_noprintsign
               clrb                    ; do not truncate printout
               pulx                    ; get longint pointer from stack
               pula                    ; get min. digit count and digit fill indicator
               jsr  uintdec
               pulx                    ; get pointer to next char from stack
               jmp  print_loop         ; continue

;*************
pdc_sign
               tsx
               ldx  2,x                ; get pointer to long
               ldx  0,x                ; get hi word of long
               pshb
               psha
               xgdx
               tsta                    ; test sign bit
               bmi  pds_neg
               tstb                    ; test if pos sign should be printed
               beq  pds_end            ; exit if not
               ldab #'+'
               bra  pds_print
pds_neg
               ldab #'-'
pds_print
               ldaa #'c'
               jsr  putchar            ; print sign
pds_end
               pula
               pulb
               rts                     ; return



;*********
; A T O I
;*********
;
; Umrechnung String -> Integer (long)
;
; conversion ignores non-numeric chars preceeding the number
; conversion stops at NULL or
; 		   at non-numeric char trailing the number
;
; Parameter    : D  - Adresse vom Input String (nullterminiert)
;                X  - Adresse f�r Ergebnis (Integer, 32 Bit)
;
; Ergebnis     : X - *Output (32 Bit Integer)
;
; changed Regs : A, B , X
;
; local Stack variables:
; 0 - *input
; 2 - *frequenz
atoi
frq_calc_freq
                pshx                       ; Adresse f�r output auf Stack sichern
                pshb
                psha                       ; Adresse vom Eingabepuffer auf Stack

                ldd  #0
                std  0,x
                std  2,x                   ; output = 0

                pulx                       ; Adresse vom String wiederholen
                clra                       ; Z�hler auf 0
atoi_loop
                ldab 0,x
                andb #~CHR_BLINK           ; Blink Bit ausblenden
                beq  atoi_end              ; Schon das Stringende erreicht?
                cmpb #'0'
                bcs  atoi_nonum
                cmpb #'9'+1
                bcs  atoi_isnum
atoi_nonum
                pshx
                tsx
                ldx  2,x                   ; get *output 
                ldab 0,x                   ; get output
                orab 1,x
                orab 2,x
                orab 3,x
                beq  atoi_next             ; if output is still zero,
                                           ; ignore non-numeric chars
                pulx
                bra  atoi_end              ; else stop conversion here
atoi_isnum      
                pshx                       ; save bufferaddress (index)
                psha                       ; save counter
                subb #$30                  ; get number from ascii code

                pshb                       ; store on stack
                clrb
                pshb
                pshb
                pshb                       ; Faktor 1 auf Stack - Ziffer von Eingabe

                tab
                lslb
                lslb                       ; calc Index for 4 Byte entries

                clra
                addd #exp10                ; add base address
                xgdx
                ldd  2,x
                ldx  0,x                   ; Faktor 2 nach D:X
                jsr  multiply32            ; Multiplizieren
                ins
                ins
                ins
                ins                        ; Faktor 1 vom Stack l�schen

                pshx                       ; Highword vom Ergebnis sichern
                tsx
                ldx  5,x                   ; Zieladresse vom Stack holen

                addd 2,x                   ; add new digit to output
                std  2,x

                pula
                pulb                       ; Highword vom Stack holen

                adcb 1,x
                stab 1,x
                adca 0,x
                staa 0,x                   ; store new output

                pula                       ; Z�hler wiederholen
atoi_next
                pulx                       ; String Adresse wiederholen
        	inx                        ; Adresse ++
                inca                       ; Z�hler --
                cmpa #8                    ; Z�hler <8 (maximale Eingabel�nge)
                bcs  atoi_loop              ; dann loop
atoi_end
                pulx                       ; sonst: Zieladresse vom Stack l�schen und
                rts                        ; R�cksprung



;#################################
char_conv_solid
char_convert
               .dw  $4C   ; ' '
               .dw  $4E60 ; '!'
               .dw  $4E21 ; '"'
               .dw  $4D45 ; '#'
               .dw  $4D35 ; '$'
               .dw  $4D28 ; '%'
               .dw  $4D47 ; '&'
               .dw  $4E20 ; '''
               .dw  $4D71 ; '('
               .dw  $4D11 ; ')'
               .dw  $4F29 ; '*'
               .dw  $4F28 ; '+'
               .dw  $4D08 ; ','
               .dw  $4D04 ; '-'
               .dw  $4D01 ; '.'
               .dw  $4D08 ; '/'
               .dw  $40   ; '0'
               .dw  $41
               .dw  $42
               .dw  $43
               .dw  $44
               .dw  $45
               .dw  $46
               .dw  $47
               .dw  $48
               .dw  $49   ; '9'
               .dw  $4D11 ; ':'
               .dw  $4D18 ; ';'
               .dw  $4E14 ; '<'
               .dw  $4D05 ; '='
               .dw  $4D0A ; '>'
               .dw  $4F27 ; '?'
               .dw  $4D75 ; '@'
               .dw  $4F0D ; 'A'
               .dw  $4F0E
               .dw  $4F0F
               .dw  $4F10
               .dw  $4F11
               .dw  $4F12
               .dw  $4F13
               .dw  $4F14
               .dw  $4F15
               .dw  $4F16
               .dw  $4F17
               .dw  $4F18
               .dw  $4F19
               .dw  $4F1A
               .dw  $4F1B
               .dw  $4F1C
               .dw  $4F1D
               .dw  $4F1E
               .dw  $4F1F
               .dw  $4F20
               .dw  $4F21
               .dw  $4F22
               .dw  $4F23
               .dw  $4F24
               .dw  $4F25
               .dw  $4F26 ; 'Z'
               .dw  $4D71 ; '[' (same as '(')
               .dw  $4D02 ; '\'
               .dw  $4D11 ; ']' (same as ')')
               .dw  $4E05 ; '^'
               .dw  $4B   ; '_'
               .dw  $4D02 ; '`'
               .dw  $4F0D ; 'A'
;               .dw  $4A   ; 'A'
               .dw  $4F0E
               .dw  $4F0F
               .dw  $4F10
               .dw  $4F11
               .dw  $4F12
               .dw  $4F13
               .dw  $4F14
               .dw  $4F15
               .dw  $4F16
               .dw  $4F17
               .dw  $4F18
               .dw  $4F19
               .dw  $4F1A
               .dw  $4F1B
               .dw  $4F1C
               .dw  $4F1D
               .dw  $4F1E
               .dw  $4F1F
               .dw  $4F20
               .dw  $4F21
               .dw  $4F22
               .dw  $4F23
               .dw  $4F24
               .dw  $4F25
               .dw  $4F26 ; 'Z'
               .dw  $4D71 ; '{' (same as '(')
               .dw  $4E60 ; '|' (same as '!')
               .dw  $4D11 ; '}' (same as ')')
               .dw  $4D22 ; '~'
e_char_convert
               .db  0
               .db  0
               .db  0
               .db  $0A ; '#'
               .db  $6A ; '$'
               .db  $06 ; '%'
               .db  $50 ; '&'
               .db  0
               .db  $00
               .db  $03 ; ')'
               .db  0
               .db  0
               .db  $00 ; ','
               .db  $08 ; '-'
               .db  $00 ; '.'
               .db  $04 ; '/'
               .db  $40 ; '0'
               .db  $41
               .db  $42
               .db  $43
               .db  $44
               .db  $45
               .db  $46
               .db  $47
               .db  $48
               .db  $49 ; '9'
               .db  $00 ; ':'
               .db  $00 ; ';'
               .db  0   ; '<'
               .db  $08 ; '='
               .db  $00 ; '>'
               .db  0   ; '?'
               .db  $09 ; '@'
               .db  $0D ; 'A' ...
               .db  $0E
               .db  $0F
               .db  $10
               .db  $11
               .db  $12
               .db  $13
               .db  $14
               .db  $15
               .db  $16
               .db  $17
               .db  $18
               .db  $19
               .db  $1A
               .db  $1B
               .db  $1C
               .db  $1D
               .db  $1E
               .db  $1F
               .db  $20
               .db  $21
               .db  $22
               .db  $23
               .db  $24
               .db  $25
               .db  $26 ; 'Z'
               .db  $00 ; '['
               .db  $10 ; '\'
               .db  $03 ; ']'
               .db  $00 ; '^'
               .db  $00 ; '_'
               .db  $00 ; '`'
               .db  $0D ; 'A' ...
               .db  $0E
               .db  $0F
               .db  $10
               .db  $11
               .db  $12
               .db  $13
               .db  $14
               .db  $15
               .db  $16
               .db  $17
               .db  $18
               .db  $19
               .db  $1A
               .db  $1B
               .db  $1C
               .db  $1D
               .db  $1E
               .db  $1F
               .db  $20
               .db  $21
               .db  $22
               .db  $23
               .db  $24
               .db  $25
               .db  $26 ; 'Z'
               .db  $00 ; '{'
               .db  $00
               .db  $03 ; '}' 3
               .db  $04 ; '~' 4
