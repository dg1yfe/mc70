;****************************************************************************
;
;    MC70 - Firmware for the Motorola MC micro trunking radio
;           to use it as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2012  Felix Erckenbrecht, DG1YFE
;
;     This file is part of MC70.
;
;     MC70 is free software: you can redistribute it and/or modify
;     it under the terms of the GNU General Public License as published by
;     the Free Software Foundation, either version 3 of the License, or
;     (at your option) any later version.
; 
;     MC70 is distributed in the hope that it will be useful,
;     but WITHOUT ANY WARRANTY; without even the implied warranty of
;     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;     GNU General Public License for more details.
; 
;     You should have received a copy of the GNU General Public License
;     along with MC70.  If not, see <http://www.gnu.org/licenses/>.
; 
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
; Parameter: keine
;
; Ergebnis : nix
;
; changed Regs: A,B

;
;
io_init
                aim  #%11100111,RP5CR          ; do not wait for "Memory Ready", internal SRAM is fast enough
                                               ; also deactivate "HALT" input, Port53 is used as GPIO

                ldab #%10110100
                stab Port2_DDR_buf             ; Clock (I2C),
                stab Port2_DDR                 ; SCI TX, T/R Shift (PLL), Shift Reg Latch auf Ausgang

; I2C Init
                aim  #%11111011,Port2_Data     ; I2C Clock = 0
;ShiftReg Init
                aim  #%01111111,Port2_Data     ; Shift Reg Latch = 0
;SCI TX
                oim  #%10000, Port2_Data       ; SCI TX=1

                clr  SR_data_buf               ; clear shift reg buffer

                ldaa #~(SR_RFPA)               ; disable PA
                ldab #(SR_nTXPWR + SR_nCLKSHIFT + SR_9V6)
                                               ; disable Power control, disable clock shift, enable 9,6 V
                jsr  send2shift_reg            ; Shift register requires initialization within
                                               ; 0.5s after the radio is connected to power.
                                               ; An R-C combination (tau = 0.47 s) tristates
                                               ; the SR output for a maximum of 0.5 s after
                                               ; 5 V are present. (Up to 1.5 Volts are recognized as low)
                                               ; If SR is not initialized, the random state
                                               ; might shut-off the radio by pulling STBY&9,6V low
                                               ; This state would persist as long as 5 V are on.
                                               ; Since 5 V are directly generated from (unswitched) B+
                                               ; this state would persist until power connection is
                                               ; disabled.
; Port 5
                ldab #%00001000
                stab SQEXTDDR                  ; EXT Alarm auf Ausgang, Alles andere auf Input
                stab SQEXTDDRbuf
                oim  #%00001000, SQEXTPORT     ; EXT Alarm off (Hi)

; Port 6
                ldab #%00001100
                stab Port6_DDR_buf
                stab Port6_DDR                 ; A16 (Bank Switch), PTT Syn Latch auf Ausgang

                aim  #%10011011, Port6_Data    ; Bank 0 wählen

                clr  led_buf
                clr  arrow_buf
                clr  arrow_buf+1

                clr  sql_ctr
                clr  ui_ptt_req             ;
                rts

#ifdef EVA9
;*****************************
; I O   I N I T   S E C O N D
;*****************************
;
; Secondary I/O Initialization (if device is switched on):
;
; - enable external EEPROM
;
; Parameter: none
;
; Returns  : nothing
;
; changed Regs: A,B

io_init_second
                aim  #%00000000, Port5_Data    ; EEPROM on (/EEP Pwr Stb = 0)
                oim  #%10000000, RP5CR         ; Set Standby Power Bit
                rts
#endif

;****************************
; S E N D 2 S h i f t _ R e g
;****************************
;
; AND is performed before OR !
;
; Parameter : A - AND-Value
;             B - OR-Value
;
; changed Regs: A,B,X
;
send2shift_reg
                inc  bus_busy                ; disable IRQ Watchdog Reset
                inc  tasksw_en

                anda SR_data_buf
                staa SR_data_buf
                orab SR_data_buf
                stab SR_data_buf

                ldaa #8                 ; 8 Bit senden
s2sr_loop
                psha                    ; save bit counter
                lslb                    ; shift MSB to carryflag
                bcs  s2sr_bitset        ; branch if Bit set
                I2C_DL                  ; Bit clear, set data line to zero
                I2C_CH
                I2C_CL                  ; Clock Hi/Lo toggle
                bra  s2sr_dec
s2sr_bitset
                I2C_DH                  ; Data Hi
                I2C_CH
                I2C_CL                  ; Clock Hi/Lo toggle
s2sr_dec
                pula                    ; restore bit counter
                deca                    ; bit counter--
                bne  s2sr_loop
                I2C_DI                  ; set Data line Input & Hi (via ext. Pull-Up)


                oim  #BIT_SRLATCH, PORT_SRLATCH
                aim  #~BIT_SRLATCH,PORT_SRLATCH   ; toggle Shift Reg Latch - present data on shift reg outputs

                dec  bus_busy           ; disable IRQ Watchdog Reset
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
;             g�ltige Werte f�r N: 3-1023
;                               A: 0-127
;                               R: 3-16383
;
; changed Regs: A,B,X
;
send2pll
                inc  bus_busy                ; disable IRQ Watchdog Reset
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
                oim  #BIT_PLLLATCH, PORT_PLLLATCH; PLL Syn Latch auf Hi
                nop
                nop
                aim  #~BIT_PLLLATCH, PORT_PLLLATCH   ; PLL Syn Latch auf Lo
                dec  bus_busy                ; re-enable Watchdog Reset
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
                ldab #(SYSCLK/(32* 1200 ))-1    ;
                stab TCONR                      ; Counter f�r 1200 bps

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
; Parameter: A - Status (0=RX ok, 3=no RX)
;            B - rxd Byte
;
; changed Regs : A, B, X
;
; required Stack Space : 2
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
; Parameter : B - rxd Byte
;
; changed Regs : A, B, X
;
; required Stack Space : 2
;
sci_read
                ldab io_inbuf_r           ; Zeiger auf Leseposition holen
                cmpb io_inbuf_w           ; mit Schreibposition vergleichen
                beq  sci_read             ; Wenn gleich sind keine Daten gekommen -> warten
                ldx  #io_inbuf            ; Basisadresse holen
                abx                       ; Zeiger addieren, Leseadresse berechnen
                ldaa 0,x                  ; Datenbyte aus Puffer lesen
                incb                      ; Zeiger++
                andb #$io_inbuf_mask      ; Im g�ltigen Bereich bleiben
                stab io_inbuf_r           ; neue Zeigerposition speichern
                tab                       ; Datenbyte nach B
                clra                      ; A = 0
                rts

;************************
; S C I   R X   M
;************************
;
; Echo/Kommandobest�tigung lesen
;
; Parameter:  none
;
; Returns: A - raw value ( Bit 0-6)
;              Status  (Bit 7) (0=RX ok, 1=no RX)
;          B - converted Byte (Key convert Table)
;
; changed Regs : A, B
;
; required Stack Space : 2
;
sci_rx_m
                ldab io_menubuf_r         ; Zeiger auf Leseposition holen
                cmpb io_menubuf_w         ; mit Schreibposition vergleichen
                bne  srdm_cont
                ldaa #-1
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
; changed Regs : A, B
;
; required Stack Space : 4
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
; S C I   T X
;************************
;
; Transfer char to/via SCI
;
; Parameter:  none
;
; Returns : A - Status (0=ok, 1=buffer full)
;           B - TX Byte
;
; changed Regs : none
;
; required Stack Space : 3
;
sci_tx
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
; required Stack Space : 6
;
sci_tx_w
                pshb
                psha
                pshx                       ; x sichern
stw_chk_lcd_timer
                ldaa lcd_timer             ; lcd_timer holen
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
                ldab #LCDDELAY*4      ; vierfacher Timeout für Clear & Reset Befehle
                stab lcd_timer
                bra  stw_end
stw_10ms
                ldab #LCDDELAY         ; normaler Timeout für Rest (außer 4f/5f)
                stab lcd_timer
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
;****************
; S C I   A C K
;****************
;
; Parameter : B - gesendetes Zeichen, das best�tigt werden soll
;
; Result    : A - 0 = OK
;                 1 = Error / Timeout
;
; changed Regs: X
;
; required Stack Space : 13 / 4 + putchar 'p'
;
;
sci_ack
                pshb                   ; Zeichen sichern
                ldaa #1
                psha

sak_empty_buf
                jsr  check_inbuf       ; Empfangspuffer �berpr�fen
                tsta
                beq  sak_start_chk     ; Wenn kein Zeichen
                decb
                beq  sak_start_chk     ; oder ein Zeichen drin ist, mit Auswertung fortsetzen
                jsr  sci_read          ; Ansonsten alle Zeichen ausser letztem lesen
                bra  sak_empty_buf
sak_start_chk
                ldab #LCDDELAY
                stab ui_timer          ; Timer setzen
sak_loop
                ldab ui_timer          ; Timer abgelaufen?
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
; required Stack Space : 9
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
; TODO: Handle collision between ack & next repetition
; Possible solution: Discard any char for the menu buffer arriving within the next 2 ms
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
; changed Regs: A,B,X
;
; Required Stack Space : 2
;
men_buf_write
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
;                 'd' - unsinged int (dezimal, 8 Bit) (0-99, value is printed with leading zero)
;                 'u' - unsinged int (dezimal, 8 Bit)
;                 'l' - longint (dezimal, 32 Bit)
;                 'p' - PLAIN, gibt Zeichen unverändert aus, speichert es NICHT im Puffer
;                       Anwendung von 'p' : Senden von Display Befehlen (Setzen des Cursors, Steuern der LEDs, etc.)
;
;
;             B - Zeichen in Modus c,x,u,p,d
;                 Anzahl nicht darzustellender Ziffern in Modus 'l' (gezählt vom Ende! - 1=Einer, 2=Zehner+Einer, etc...)
;
;             X - Pointer auf longint in Modus L
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
; required Stack Space : 'c' - 15
;                        'd' - 24
;                        'u' - 23
;                        'l' - 33
;                        'x' - 23
;                        'p' - 15
;                        jeweils +15 bei Keylock
;
putchar
#ifdef SIM
                rts
#endif
                cmpa #'u'
                bne  pc_testdecd
                jsr  uintdec
                jmp  pc_end
pc_testdecd
                cmpa #'d'
                bne  pc_testlong
                jsr  uintdecd
                jmp  pc_end
pc_testlong
                cmpa #'l'
                bne  pc_testlong_ind
                jsr  ulongout
                jmp  pc_end
pc_testlong_ind
                cmpa #'L'
                bne  pc_testhex
                clra
                jsr  decout
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
pc_testplain
                cmpa #'p'
                bne  pc_to_end
                jmp  pc_ext_send2    ; Plain - sende Bytevalue wie erhalten
pc_to_end
                jmp  pc_end          ; unsupported mode, abort/ignore

pc_char_out    ; ASCII character in B
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
                pshb                 ; save index

                psha                 ; save character to print
                clra                 ; HiByte = 0

                lsld                 ; Index f�r Word Eintr�ge berechnen
                addd #char_convert   ; Basisadresse hinzuf�gen
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
               anda #CDIFF_FLAG
               beq  pcc_diff          ; Nein, dann weitermachen - Returnvalue = 'Zeichen ausgeben'

               ldaa #'p'
               addb #$60              ; $60 zu Cursorposition addieren -> Positionierungsbefehl erzeugen
               jsr  putchar           ; Cursor korrekt positionieren
               aim  #~CDIFF_FLAG, pcc_cdiff_flag ; clear flag, cursor positions match
               bra  pcc_diff
pcc_same
               inc  cpos              ; Cursor weitersetzen
               oim  #CDIFF_FLAG, pcc_cdiff_flag    ; Cursorposition in CPOS unterscheidet sich von tatsächlicher
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
; Required Stack Space : 21
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

;*****************
; U I N T D E C D
;
; Putchar Subroutine
;
; Prints 2 decimal digits
;
; Parameter : B - 8 Bit Integer
;
; Ergebnis : none
;
; changed Regs : A,B,X
;
; Required Stack Space : 21
;
uintdecd
               pshb                               ; Wert sichern
               cmpb #100
               bne  udd_cont
               subb #100
udd_cont
               cmpb #10
               bcs  udd_print_zero
               pulb
               bra  uintdec
udd_print_zero
               ldab #'0'
               ldaa #'c'
               jsr  putchar
               pulb
               bra  uintdec
;****************
; U I N T   D E C
;
; Putchar Subroutine
;
; Formatiert einen 8 Bit Integer für Dezimale Darstellung um und gibt ihn aus
;
; Parameter : B - 8 Bit Integer
;
; Returns : nothing
;
; changed Regs : A,B,X
;
; Required Stack Space : 21
;                        36 (bei keylock)
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
; Parameter : B - Anzahl der vom Ende der Zahl abzuschneidenden Ziffern (Bit 0-3)
;                 Flags (Bit 4-7, only ulongout -> see below)
;             A - Anzahl der mindestens auszugebenden Stellen (Bit 0-3)
;                 
;                 Flags (udecout/decout)
;                 force sign inversion on return (Bit 4)
;                 force negative sign (Bit 5)
;                 Force sign print (Bit 6)
;                 Prepend space instead of zero (Bit 7)
;
;             Stack - 32 Bit Integer
;
; Ergebnis : none
;
; changed Regs : A,B,X
;
; Required Stack Space : 31
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
               tba
               andb #$0f
               anda #$f0
               tsx
               inx
               inx
               inx
               inx
udecout
decout
               psha                    ; Put minimum number of digits to print to Stack
               pshx                    ; Put pointer to longint to stack
               pshb                    ; save digits to truncate
               ldaa 0,x
               bpl  ulo2_ispositive    ; check for sign of long
               jsr  sig_inv32s         ; invert longint
               tsx
               oim  #$70,3,x           ; add flag for "print sign, sign negative, sign inversion"
ulo2_ispositive
               pulb
               andb #7                 ; truncate at max. 7 digits
               beq  ulo2_notrunc       ; wenn nichts abzuschneiden, Division �berspringen
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
ulo2_notrunc
               pulx                    ; get pointer to long
               pula                    ; get no. of digits to print
               tab
               andb #$40               ; check if sign should be printed
               beq  ulo2_nosign        ; branch if not
               tab
               andb #$0f               ; check if min number of digits is given
               beq  ulo2_nosign        ; dont change anything if it isn't given
               deca                    ; decrease number of digits if sign
                                       ; is to be printed
ulo2_nosign
               pshx
               ldab #$da
               pshb                    ; push end marker to stack
ulo2_divloop
               psha                    ; put number of digits to print to stack
               pshx                    ; Zeiger auf Longint Kopie auf Stack legen (Dividend)
               ldd  #10
               jsr  divide32s          ; Longint durch 10 dividieren
               xgdx                    ; Rest (0-9) nach D
               pulx                    ; Zeiger auf Quotient holen
               pula                    ; get no. of digits to print from stack
               pshb                    ; Rest auf Stack
               ldab 3,x
               orab 2,x
               orab 1,x
               orab 0,x                ; Prepare Quotient for test if zero

               pshx                    ; Save Pointer
               psha                    ; Save Digit counter
               anda #$0f               ; extract counter bits
               beq  ulo2_nodecr        ; already at zero? Then branch and dont
               tsx
               dec  0,x                ; decrement min number of digits
ulo2_nodecr
               pula                    ; Digit Counter nach A
               pulx                    ; Pointer nach X
               tstb                    ; Pr�fen ob Quotient = 0
               bne  ulo2_divloop       ; Wenn Quotient >0, dann erneut teilen
               tab
               andb #$40               ; test if sign should be shown
               beq  ulo2_testfill      ; if not, check for number of prepend digits
               tab
               andb #$80               ; check for "fill with space" (sign at end of spaces, before 1st digit)
               beq  ulo2_testfill      ; start prepend action if it is "fill with 0" (sign in front of zeros)
               tab
               andb #$20               ; test for negative sign
               beq  ulo2_putposbk
               ldab #'-'-'0'
               bra  ulo2_signputbk
ulo2_putposbk
               ldab #'+'-'0'
ulo2_signputbk
               pshb                    ; push sign to stack
ulo2_testfill
               tab
               andb #$0f               ; Test digit counter
               beq  ulo2_tstsignfr     ; Mindestanzahl erreicht, Zahl ausgeben
               tsta
               bmi  ulo2_pp_space
               ldx  #0                 ; use zero to fill
               bra  ulo2_fill_loop
ulo2_pp_space
               ldx  #' '-'0'           ; use Space to fill
ulo2_fill_loop
               xgdx                    ; save AB to X
               pshb                    ; push zero to stack
               xgdx                    ; restore AB
               decb                    ; decrement digit count
               bne  ulo2_fill_loop     ; loop until zero
               anda #$f0               ; mask digit count, keep Space/Zero marker
ulo2_tstsignfr
               tab
               andb #$40               ; test if sign should be shown
               beq  ulo2_prntloop      ; if not, start print
               tab
               andb #$80               ; check for "fill with space" (sign at end of spaces, before 1st digit)
               bne  ulo2_prntloop      ; start printout if it is "fill with space" (sign in front of zeros)
               tab
               andb #$20               ; test for negative sign
               beq  ulo2_putposfr      ; if sign is positive, branch
               ldab #'-'-'0'           ; else load "-", subtract '0' because it is added later
                                       ; again (conversion 'number' to 'char')
               bra  ulo2_signputfr
ulo2_putposfr
               ldab #'+'-'0'           ; load "+" sign
ulo2_signputfr
               pshb                    ; push sign to stack

;************
ulo2_prntloop
               pulb                    ; Rest vom Stack holen
               cmpb #$da               ; test for end marker
               beq  ulo2_end           ; Escape here, if marker found

               psha                    ; save flags
               addb #'0'               ; add $30 (num to char conversion)
               ldaa #'c'
               jsr  putchar            ; print char
               pula                    ; restore flags
               bra  ulo2_prntloop      ;
ulo2_end
               pulx                    ; restore pointer to long
               tab
               andb #$10               ; check if long was inverted
               beq  ulo2_return
               jsr  sig_inv32s         ; eventually invert sign (again)
ulo2_return
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
; required Stack Space : 6
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
; Print formatted string including variables
;
; Parameter : X - Poiter to zero terminated String
;
;             Stack - Variables:
;                     %x - Pointer to long (32 Bit)
;                     %d - Pointer to long (32 Bit)
;                     %c - Char
;                     %s - Pointer to string
;
; Returns : nothing
;
; changed Regs : X
;
; Required Stack Space :
;                           (bei keylock)
;
;
;
; 8 - Arg
#define PES_ARG      8
; 7 - Return L
; 6 - Return H
; 5 - B
; 4 - A
; 3 - ARG Offset
#define PES_ARG_OFS  3
; 2 - Modifier2
; 1 - Modifier2
; 0 - Modifier1
#define PES_MODIF0   2
#define PES_MODIF1   1
#define PES_MODIF2   0

printf
               ; X : Pointer auf 0-terminated String
               ; Stack : Variables
               ; changed Regs: X
               pshb
               psha
               clra                 ; clear Arg Offset
               psha                 ; push to stack
               psha
               psha
               psha                 ; clear modifier variables
print_loop
               ldab 0,x             ; Zeichen holen
               beq  end_printf      ; =$00 ? Dann String zu Ende -> Return
               inx                  ; Zeiger auf nächstes Zeichen
               cmpb #'%'            ; auf "%" testen
               beq  print_esc       ;
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
               ins
               pula
               pulb
               rts
print_esc
               clrb                    ; delete "%" character
print_escape
               pshx
                                       ; shift modifier FiFo
               tsx
               ldaa 2+PES_MODIF1,x
               staa 2+PES_MODIF0,x     ; make modifier 1 new modifier 0
               ldaa 2+PES_MODIF2,x
               staa 2+PES_MODIF1,x     ; make modifier 2 new modifier 1
               stab 2+PES_MODIF2,x     ; store new char as modifier 2
               pulx

               ldab 0,x                ; read next byte
               beq  print_end          ; check for end of string
               inx                     ; set pointer to next char
               tba
               oraa #$20               ; ignore case - make everything lower case
               cmpa #'x'
               beq  pes_hex            ; check for Hex
               cmpa #'i'
               bne  pes_chkd           ; check for Integer (decimal)
               jmp  pes_dec
pes_chkd
               cmpa #'d'
               bne  pes_chks           ; check for Integer (decimal)
               jmp  pes_dec
pes_chks
               cmpa #'s'
               beq  pes_str            ; check for string
               cmpa #'c'
               beq  pes_char           ; check for char
               cmpb #'%'
               beq  print_char         ; check for "%" -> print "%"
                                       ; all types have been checked
               cmpb #'+'               ; check for + (print pos. sign)
               beq  print_escape       ; loop (put + modifier in FiFo)
               cmpb #'9'+1             ; check possible modifiers for sanity
               bcc  print_loop         ; only numeric values allowed, exit from Escape on error
               cmpb #'0'
               bcs  print_loop         ; only numeric values allowed, exit from Escape on error
               bra  print_escape       ; modifier is numeric, loop (shift it into FiFo)
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
               inx
               bra  pst_loop           ; loop
pst_return
               pulx
               jmp  print_loop         ; print as character
;**********
pes_hex
               pshx                    ; put String pointer onto stack
               tsx
               ldab 2+PES_ARG_OFS,x    ; get Offset of next Variable
               tba
               inca
               inca
               staa 2+PES_ARG_OFS,x    ; increment offset by 2 byte
               abx
               ldx  2+PES_ARG,x        ; get pointer to long
               pshx                    ; push pointer to long onto stack
               tsx
               ldaa 4+PES_MODIF2,x     ; get modifier 2
               beq  phx_print          ; if there is no modifier 2, print unmodified
;               cmpa #'+'               ; sign modifier? (dont care, hex will be printed without sign)
;               beq  phx_print          ; then start print
               ldab 4+PES_MODIF1,x     ; get modifier 1
               beq  phx_fws            ; if there is none, start print, fill with space
               cmpb #'0'
               beq  phx_zero           ; fill with '0'
phx_fws
               adda #$80               ; load 'fill with space' modifier bit
phx_zero
               suba #'0'               ; convert ascii char to number of digits to print
               psha
phx_count
               ldab #8                 ; maximum number of digits to print
               tsx
               ldx  1,x                ; get pointer to long
phx_count_lp
               ldaa 0,x                ; get byte from long (start with MSB)
               anda #$f0               ; isolate hi nibble
               bne  phx_fill           ; end counting, if != 0
               decb                    ; decrease counter if == 0
               ldaa 0,x
               anda #$0f               ; isolate lo nibble
               bne  phx_fill           ; end counting if != 0
               inx                     ; point to next byte of long
               decb                    ; decrease counter if == 0
               bne  phx_count_lp       ; loop through all 4 bytes / 8 nibbles
               ldab #1                 ; print at least "0" if long was 0
phx_fill
               pshb                    ; save number of relevant digits of long
               tba                     ; A = number of non-zero digits of long
               tsx
               ldab 1,x                ; B = number of digits to print at least
               andb #$7f               ; mask space/zero indicator bit
               sba                     ; (A - B) if A >= B
               bcc  phx_print          ; print everything, dont prepend anything
               nega                    ; invert result
                                       ; A = digits to prepend
               ldab #'0'
               tst  1,x                ; check if to prepend with 0 or space
               bpl  phx_fill_lp
               ldab #' '
phx_fill_lp
               psha
               pshb
               ldaa #'c'
               jsr  putchar            ; print fill char
               pulb
               pula
               deca
               bne  phx_fill_lp        ; repeat for required number of digits
phx_print
               pulb                    ; get number of digits to print
               tba
               ins                     ; discard numer of digits to prepend
               tsx
               ldx  0,x                ; get pointer to long
               subb #8                 ; digits to print - 8 (gives negative digits to skip)
               negb                    ; invert sign
               pshb
               lsrb                    ; divide by two
               abx                     ; add to pointer
               pulb
               ins
               ins                     ; remove old pointer to long from stack
               pshx                    ; store altered pointer to stack
phx_loop
               andb #1                 ; check if hi nibble shall be skipped
               bne  phx_lonib
               tsx
               ldx  0,x                ; get pointer to long
               ldab 0,x                ; get byte
               lsrb
               lsrb
               lsrb
               lsrb                    ; isolate hi nibble
               bra  phx_put
phx_lonib
               pulx                    ; get pointer to long
               ldab 0,x                ; get byte from long
               inx                     ; increment pointer
               pshx                    ; store to stack
               andb #$0f               ; isolate lo-nibble
phx_put
               psha
               jsr  sendnibble         ; print nibble
               pula
               deca                    ; decrement digit counter
               tab                     ; transfer to a (for nibble selection)
               bne  phx_loop
               ins
               ins                     ; remove pointer to long from stack
               pulx                    ; get string pointer back to X
               jmp  print_loop         ; continue
;**********
pes_dec
               pshx                    ; put String pointer onto stack
               tsx
               ldab 2+PES_ARG_OFS,x    ; get Offset of next Variable
               tba
               inca
               inca
               staa 2+PES_ARG_OFS,x    ; increment offset by 2 byte
               abx
               ldx  2+PES_ARG,x        ; get pointer to long
               pshx                    ; push pointer to long onto stack
               tsx
               ldaa 4+PES_MODIF2,x     ; get modifier 2
               beq  pdc_print          ; if there is no modifier 2, print unmodified
               cmpa #'+'               ; sign modifier?
               bne  pdc_modif1         ; no? Assume number, check modifier 1
               ldaa #$40               ; force print with sign
               bra  pdc_print
; "%+02i"->print at least 2 digits, use 0 to prepend, always print sign
; "%02i"-> print at least 2 digits, use 0 to prepend, print sign for neg. values
; "%+2i"-> print at least 2 digits with sign, use space to prepend
; "%2i" -> print at least 2 digits, use space to prepend
; "%+i" -> print w sign
pdc_modif1
               anda #$0f               ; convert ascii char to number of digits to print
                                       ; (silently assume modifier is a numeric char)
                                       ; simultaneously reset hi nibble to zero (used for flags)
               ldab 4+PES_MODIF1,x     ; get modifier 1
               beq  pdc_ppsel          ; if there is none, prepend with space
pdc_m1chk
               cmpb #'0'               ; Is modifier 1 '0' ?
               bne  pdc_m1chks         ; If not, perform another check
               oraa #$80               ; modifier is '0', set (inverted) flags to prepend with '0'
                                       ; ( assume valid numer is given by modifier 2)
               ldab 4+PES_MODIF0,x     ; check if modifier 0
pdc_m1chks
               cmpb #'+'               ; is a '+'
               bne  pdc_ppsel          ; if not, then print
               oraa #$40               ; else make sure the sign gets printed too
pdc_ppsel
               eora #$80               ; invert flag to select prepend char (space or zero)
pdc_print
               clrb                    ; do not truncate printout
               pulx                    ; get longint pointer from stack
               jsr  udecout
               pulx
               jmp  print_loop         ; continue

;*************


;*********
; A T O L
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
atol
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
;*********
; U T O A
;*********
;
; 16 Bit Unsigned to String
;
; Parameter    : D  - unsigned int
;                X  - Address for result (7 bytes (5 digits + 1 sign + terminating zero))
;
; Ergebnis     : X - *Output (zero-terminated string)
;
; changed Regs : A, B
;
utoa
               pshx                    ; save target pointer to stack
               xgdx                    ; move input to X

               ldab #42
               pshb                    ; push end marker to stack
utoa_divloop
               xgdx                    ; get integer
               ldx  #10
               jsr  divide             ; divide uint by 10
               xgdx                    ; move remainder (0-9) to D
                                       ; and quotient to X
               pshb                    ; push remainder onto Stack

               cpx  #0
               bne  utoa_divloop       ; if quotient >0, divide again
               tsx
utoa_lenloop                           ; loop until end of string to
               ldab 0,x
               inx
               cmpb #42
               bne  utoa_lenloop
               ldx  0,x                ; get the target pointer back
               clra
utoa_prntloop
               pulb                    ; Rest vom Stack holen
               cmpb #42                ; test for end marker
               beq  utoa_end           ; Escape here, if marker found
               addb #'0'               ; add $30 (num to char conversion)
               stab 0,x                ; store to target
               inx
               staa 0,x                ; insert zero termination
               bra  utoa_prntloop      ;
utoa_end
               pulx                    ; restore pointer to buffer
               rts                     ; return



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
