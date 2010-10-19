;****************************************************************************
;
;    MC 70    v1.0.1 - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2007  Felix Erckenbrecht, DG1YFE
;
;    This program is free software; you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation; either version 2 of the License, or
;    any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program; if not, write to the Free Software
;    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;
;
;****************************************************************************
;*************
; I O
;*************
;
;
; io_init
; send2shift_reg
; send2pll
; i2c_start
; i2c_stop
; i2c_ack
; i2c_tstack
; i2c_tx
; i2c_rx
; init_SCI
; sci_rx
; sci_rx_m
; sci_read
; sci_read_m
; sci_tx_buf
; sci_tx
; sci_tx_w
; check_inbuf
; check_outbuf
; sci_ack
; sci_read_cmd
; sci_trans_cmd
; men_buf_write
; led_set
; led_update
; arrow_set
; putchar
; printf
;
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
                                          ; HALT Input auch deaktivieren, Port53 wird sp�ter als Ausgang ben�tigt

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

                ldab #%01001010                ; #TX Power    = 1
                                               ; #Clock Shift = 1
                                               ; STBY&9,6V    = 1
                                               ;
                ldaa #%11111110                ; TX / #RX     = 0
                jsr  send2shift_reg

; Port 5
                ldab #%00001000
                stab Port5_DDR                 ; EXT Alarm auf Ausgang, Alles andere auf Input
                stab Port5_DDR_buf
                oim  #%00001000, Port5_Data    ; EXT Alarm off (Hi)

; Port 6
                ldab #%01101100
                stab Port6_DDR_buf
                stab Port6_DDR                 ; A16 (Bank Switch), PTT Syn Latch und DAC auf Ausgang

                aim  #%10011011, Port6_Data    ; Bank 0 w�hlen


                ldx  #bank_switch_end-bank_switch_cpy
                pshx
                ldx  #bank_switch_cpy          ; Bank Switch Routine
                ldd  #bank0                    ; In RAM verschieben
                jsr  mem_trans
                pulx

                clr  led_buf
                clr  arrow_buf
                clr  arrow_buf+1

                clr  ui_ptt_req             ;
                rts
;****************************
; S E N D 2 S h i f t _ R e g
;****************************
;
; Parameter : B - OR-Value
;             A - AND-Value
;
; changed Regs: A,B
;
send2shift_reg
                pshx
                inc  irq_wd_reset                ; disable IRQ Watchdog Reset
                inc  tasksw_en

                anda SR_data_buf
                staa SR_data_buf
                orab SR_data_buf
                stab SR_data_buf

                jsr  i2c_tx

                oim  #$80, Port2_Data
                aim  #$7F, Port2_Data            ;Shift Reg Latch toggeln - Daten �bernehmen

                dec  irq_wd_reset                ; disable IRQ Watchdog Reset
                dec  tasksw_en
                pulx
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
; changed Regs: none
;
send2pll
                pshb
                psha
                pshx
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
                rolb                             ; X/lo ein Bit nach links, Bit von B einf�gen
                rola                             ; X/hi ein Bit nach links, Bit von X/lo einf�gen
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
                rolb                             ; X/lo ein Bit nach links, Bit von B einf�gen
                rola                             ; X/hi ein Bit nach links, Bit von X/lo einf�gen
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
                pulx
                pula
                pulb
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
; Best�tigung des Adress und Datenworts -> 0 im 9. Clock Zyklus senden
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
; I2C "ACK" pr�fen
; Best�tigung des Adress und Datenworts -> 0 im 9. Clock Zyklus senden
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
                I2C_DL                  ; Bit gel�scht, also Datenleitung 0
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
                psha                    ; tempor�ren Speicher f�r empfangenes Byte

                tsx
                I2C_DI                  ; I2C Data Input
                ldaa #$80               ; Mit MSB beginnen
irx_loop
                I2C_CHb
                ldab Port2_Data         ; Daten einlesen
                andb #%10
                tstb                    ; Bit gesetzt?
                beq  irx_shift          ; Nein, dann kein Bit einf�gen
                tab
                oraa 0,x                ; Wenn gesetzt, dann Bit einf�gen
                staa 0,x                ; und speichern
                tba
irx_shift
                I2C_CLb                 ; Clock toggle
                lsra                    ; n�chstes Bit
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
                pshb
                psha

                ldab #51
                stab TCONR                      ; Counter f�r 1200 bps

                ldab #%10000
                stab TCSR3                      ; Timer 2 aktivieren, Clock = E (Sysclk/4=2MHz), no Timer output

                ldab #%110100                   ; 7 Bit, Async, Clock=T2
                stab RMCR

                ldab #%110                      ; 1Stop Bit, Odd Parity, Parity enabled
                stab TRCSR2

                ldab #%1010
                stab TRCSR1                     ; TX & RX enabled, no Int

                pula
                pulb
                rts

;************************
; S C I   R X
;************************
;                        A : Status (0=RX ok, 3=no RX)
;                        B : rxd Byte
;             changed Regs : A, B
;
sci_rx
                ldab io_inbuf_r           ; Zeiger auf Leseposition holen
                cmpb io_inbuf_w           ; mit Schreibposition vergleichen
                beq  src_no_data          ; Wenn gleich sind keine Daten gekommen
                ldx  #io_inbuf            ; Basisadresse holen
                abx                       ; Zeiger addieren, Leseadresse berechnen
                ldaa 0,x                  ; Datenbyte aus Puffer lesen
                incb                      ; Zeiger++
                andb #$io_inbuf_mask      ; Im g�ltigen Bereich bleiben
                stab io_inbuf_r           ; neue Zeigerposition speichern
                tab                       ; Datenbyte nach B
                clra                      ; A = 0
                rts
src_no_data
                ldaa #3
                clrb
                rts
;************************
; S C I   R X   M
;************************
;
; Echo/Kommandobest�tigung lesen
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
; S C I   R E A D
;************************
sci_read
                ;B : rxd Byte
                ;changed Regs: A, B
;                bsr  sci_rx
;                tsta

                bsr  sci_rx
                cmpa #3
                beq  sci_read
		rts
;************************
; S C I   R E A D E
;************************
sci_read_m
                ;B : rxd Byte
                ;changed Regs: A, B
;                bsr  sci_rx
;                tsta

                bsr  sci_rx_m
                tsta
                bne  srdm_end
                swi                ; Taskswitch durchf�hren wenn gewartet werden mu�
                bra  sci_read_m
srdm_end
                rts
;************************
; S C I   T X   B U F
;************************
sci_tx_buf
                ;B : TX Byte
                ;A : Status (0=ok, 1=buffer full)
                tab
                ldab io_outbuf_w          ; Zeiger auf Schreibposition holen
                incb                      ; erh�hen
                andb #$0f                 ; Im Bereich 0-15 bleiben
                cmpb io_outbuf_r          ; mit Leseposition vergleichen
                beq  stb_full             ; Wenn gleich, ist Puffer voll

                ldab io_outbuf_w          ; Zeiger auf Schreibposition holen
                ldx  #io_outbuf           ; Basisadresse holen
                abx                       ; Zeiger addieren, Schreibadresse berechnen
                staa 0,x                  ; Datenbyte aus Puffer lesen
                incb                      ; Zeiger++
                andb #$0f                 ; Im Bereich 0-15 bleiben
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
                pshx                       ; x sichern
;stx_wait_tdr_empty1
;                ldaa TRCSR1
;                anda #%00100000
;                beq  stx_wait_tdr_empty1   ; sicher gehen dass TX Register leer ist
stx_writereg
                stab TDR                   ; Byte in Senderegister
stx_wait_tdr_empty2
                ldaa TRCSR1
                anda #%00100000
                beq  stx_wait_tdr_empty2   ; Warten bis es gesendet wurde
                pulx
                pula
                rts
;
;************************
; S C I   T X   W
;************************
;
; Sendet Zeichen in B nach Ablauf des LCD_TIMER. Setzt abh�ngig von gesendeten
; Zeichen den Timer neu. Ber�cksichtigt unterschiedliche Timeouts f�r $78, $4F/$5F und Rest
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
                beq  stw_writereg          ; warten falls dieser >0 (LCD ist noch nicht bereit)
                swi                        ; Taskswitch
                bra  stw_chk_lcd_timer
stw_writereg
                stab TDR
stw_wait_tdr_empty
                ldaa TRCSR1
                anda #%00100000
                swi
                beq  stw_wait_tdr_empty

                tba
                oraa #$10
                cmpa #$5D              ; auf 4D/5D pr�fen - extended char
                beq  stw_end           ; n�chstes Zeichen OHNE Delay senden
                oraa #$01
                cmpa #$5F              ; auf 4E/4F/5E/5F pr�fen - extended char
                beq  stw_end           ; n�chstes Zeichen OHNE Delay senden

                cmpb #$78              ; LCD Clear Zeichen?
                bcs  stw_10ms          ; Alles was <$78 ist mit normalem Delay
                ldx  #LCDDELAY*4       ; vierfacher Timeout f�r Clear & Reset Befehle
                stx  lcd_timer
                bra  stw_end
stw_10ms
                ldx  #LCDDELAY         ; normaler Timeout f�r Rest (au�er 4f/5f)
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
                ldaa io_inbuf_r
                suba io_inbuf_w
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
; Parameter : B - gesendetes Zeichen, das best�tigt werden soll
;
; Result    : A - 0 = OK
;                 1 = Error / Timeout
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
                cmpb #$7F              ; Fehler? (Es wurde eine Taste gedr�ckt)
                bne  sak_chk_cmd
                bsr  sci_read_cmd      ; Ja, dann Kommando lesen und in Puffer f�r Men� speichern
                bra  sak_end
sak_chk_cmd
                tsx
                cmpb 1,x               ; Empfangenes Zeichen = gesendeten Zeichen?
                beq  sak_ok            ; Ja, dann zur�ck
                cmpb #$74              ; auf 'Input lock' pr�fen
                beq  sak_unlock
                jsr  check_inbuf       ; Noch Zeichen im Puffer?
                tsta
                bne  sak_getanswer     ; Ja, dann nochmal Vergleich durchf�hren
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
                pulb                   ; Zeichen zur�ckholen
                jsr  sci_tx_w          ; Best�tigung senden
                jsr  men_buf_write     ; Eingabe in Men� Puffer ablegen
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
                jsr  check_inbuf       ; Pr�fen wieviele Byte im Input Speicher sind
                beq  stc_ack           ; Wenn das letzte gerade gelesen wurde, ACK senden
                jsr  sci_read          ; n�chstes Zeichen lesen
                bra  stc_clear_buf     ; loop
stc_ack
                jsr  sci_tx_w          ; Sonst Best�tigung senden
                jsr  men_buf_write     ; und Eingabe in Men� Puffer ablegen
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
                incb                       ; pr�fen ob Puffer schon voll
                andb #io_menubuf_mask      ; maximal 15 Eintr�ge
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

;****************
; S E T   L E D
;****************
;
; Setzt Bits in LED Buffer entsprechend Parameter
; Der Buffer wird zyklisch im UI Task abgefragt und eine �nderung
; an das Display ausgegeben.
; Achtung: Durch die langsame Kommunikation mit dem Display kann es
;          vorkommen, dass schnelle �nderungen nicht oder unvollst�ndig
;          dargestellt werden
;
;
; Parameter : B - LED + Status (RED_LED/YEL_LED/GRN_LED + OFF/ON/BLINK/INVERT)
;
;                 RED_LED $33 - 00110011
;                 YEL_LED $31 - 00110001
;                 GRN_LED $32 - 00110010
;                 OFF       0 - 00000000
;                 ON        4 - 00000100
;                 BLINK     8 - 00001000
;                 INVERT  128 - 10000000
;
;
; Returns : nothing
;
;
led_set
                pshb
                psha
                pshx

                tba
                anda #%00110011                   ; LED Bits isolieren
                cmpa #RED_LED                     ; Rot?
                beq  lds_red
                cmpa #GRN_LED                     ; Gr�n?
                beq  lds_grn
lds_yel
                ldaa #1                           ; Gelb = 1 - 00000001
                bra  lds_cont
lds_grn
                ldaa #4                           ; Gr�n = 4 - 00000100
                bra  lds_cont
lds_red
                ldaa #16                          ; Rot = 16 - 00010000
lds_cont
                psha
                lsla
                psha                              ; 2 Status Bits auf Stack
                tsx                               ; Stackpointer nach X
                ldaa led_buf                      ; LED Buffer lesen

                tstb                              ; Status = Invert ?
                bmi  lds_invert                   ; Ja, dann verzweigen
                andb #%1100                       ; Status = Blink oder On ?
                beq  lds_off                      ; Ja, dann verzweigen
                andb #%1000                       ; Status = Blink?
                bne  lds_blink
                                                  ; Status = On
                com  0,x                          ; Maske erzeugen,
                anda 0,x                          ; BLINK Bit l�schen
                oraa 1,x                          ; ON Bit setzen
                bra  lds_store
lds_off
                com  0,x                          ; Maske erzeugen
                com  1,x                          ; um beide Bits
                anda 0,x                          ; zu
                anda 1,x                          ; l�schen
                bra  lds_store
lds_blink
                oraa 0,x                          ; Blink Bit setzen
                oraa 1,x                          ; ON Bit setzen
                bra  lds_store
lds_invert
                eora 1,x                          ; On Bit invertieren
lds_store
                ldab led_dbuf
                cba                               ; anzuzeigende LEDs und dargestellte gleich?
                beq  lds_end
                oraa #$80                         ; Nein? Dann changed Bit setzen
lds_end
                staa led_buf
                ins
                ins                               ; Stackspeicher freigeben

                pulx
                pula
                pulb
                rts

;**********************
; L E D   U P D A T E
;**********************
;
; Pr�ft LED Buffer auf Ver�nderung, steuert ggf. LEDs an
;
; Parameter : none
;
; Returns : nothing
;
;
led_update
                pshb
                psha
                pshx

                clra
                inc  tasksw_en              ; keinen erzwungenen Taskswitch durchf�hren
                ldab led_buf                ; LED Buffer lesen
                lslb                        ; MSB ins Carryflag schieben (Change Bit)
                rola                        ; Bit in A �bernehmen
                lsrb                        ; B nach rechts schieben, MSB = 0 setzen
                stab led_buf                ; Puffer speichern
                dec  tasksw_en              ; Taskswitches per Interrupt wieder zulassen
                tsta
                beq  ldu_end                ; Change Bit nicht gesetzt -> Ende

                pshb                        ; Wert aus LED_BUF sichern
                eorb led_dbuf               ; Unterschied zu aktuellem Status durch XOR bestimmen
                ldaa #3
ldu_loop
                lsrb                        ; 'On' Bit ins Carryflag
                bcc  ldu_nochg              ; Bit nicht ge�ndert, Blink Bit testen
                bsr  ldu_chg                ; Wenn es sich ge�ndert hat, die �nderung ans Display senden
                bra  ldu_lsr                ; �nderung des Blink Bit mu� nicht gepr�ft werden
ldu_nochg
                lsrb                        ; 'On' Bit hat sich nicht ge�ndert, Blink Bit testen
                bcc  ldu_dec                ; Blink Bit hat sich auch nicht ge�ndert, weiter mit n�chster Farbe
                bsr  ldu_chg                ; Blink Bit hat sich ge�ndert (�bergang ON -> Blink)
                bra  ldu_dec                ; Weitermachen mit n�chster Farbe
ldu_lsr
                lsrb                        ; 'ON' Bit hat sich ge�ndert, Blink Bit �nderung nicht beachten
ldu_dec
                deca                        ; Zu n�chster Farbe
                bne  ldu_loop               ; 0=Exit

                pulb                        ; Wert vom LED Buffer holen
                andb #$7F                   ; Change Bit ausblenden
                stab led_dbuf               ; Neuen Status der Display LEDs speichern
ldu_end
                pulx
                pula
                pulb
                rts
;-------
ldu_chg
                pshb
                psha
                tab                         ; Z�hler (Farbe) nach B

                tsx
                ldaa 4,x                    ; LED Buffer holen

                cmpb #3                     ; 3= gelbe LED
                beq  ldu_yel
                cmpb #2                     ; 2= gr�ne LED
                beq  ldu_grn
ldu_red
                ldab #RED_LED               ; Kommando f�r rote LED nach B
                anda #%110000               ; Status Bits f�r rote LED isolieren
                lsra
                lsra
                lsra
                lsra                        ; und nach rechts schieben
                bra  ldu_set
ldu_yel
                ldab #YEL_LED               ; Status Bits f�r gelbe LED isolieren
                anda #%11
                bra  ldu_set
ldu_grn
                ldab #GRN_LED               ; Status Bits f�r  LED isolieren
                anda #%1100
                lsra
                lsra
ldu_set
                lsra                        ; 'ON' Bit gesetzt?
                bcc  ldu_send               ; Nein? Dann LED deaktivieren
                orab #$04                   ; Andernfalls ON Bit setzen
                lsra                        ; Blink Bit gesetzt?
                bcc  ldu_send               ; Nein, dann LED nur einschalten
                andb #%11111011             ; ON Bit l�schen
                orab #$08                   ; Blink Bit setzen
ldu_send
                ldaa #'p'
                jsr  putchar                ; LED Kommando senden

                pula
                pulb
                rts
;
;********************
; A R R O W   S E T
;********************
;
; Parameter : B - Nummer    (0-7)
;             A - Reset/Set/Blink
;                 0 = Reset,
;                 1 = Set
;                 2 = Blink
;                 3 = Invert (off->on->off, blink->off->blink, on->off->on)
;
; Returns : nothing
;
arrow_set
                pshx
                psha
                pshb

                jsr  raise                  ; Nummer in Bit Position konvertieren (2^B)
                pshb
                tsx

                cmpa #3                     ; Modus testen
                beq  aws_invert_chk
                cmpa #2
                beq  aws_blnk_chk
                cmpa #1
                beq  aws_on_chk
aws_off_chk
                ldaa arrow_buf
                tab
                anda 0,x                    ; ON Bit isolieren
                beq  aws_end                ; Arrow ist schon aus -> Ende
aws_off
                com  0,x                    ; Maske zum ausblenden erzeugen
                andb 0,x                    ; On Bit l�schen
                stab arrow_buf              ; Status speichern
                ldab #A_OFF                 ; Kommando f�r 'aus' holen
                bra  aws_send
aws_on_chk
                ldaa arrow_buf
                tab
                anda 0,x                    ; Arrow schon aktiviert?
                beq  aws_on                 ; Nein -> aktivieren
                ldaa arrow_buf+1
                tab
                anda 0,x                    ; blinkt er?
                beq  aws_end                ; Nein, dann Ende
                com  0,x                    ; Ansonsten
                andb 0,x                    ; Blink Bit l�schen
                stab arrow_buf+1            ; Status speichern
                ldab arrow_buf
                com  0,x
aws_on
                orab 0,x                    ; ON Bit setzen
                stab arrow_buf
                ldab arrow_buf+1
                com  0,x
                andb 0,x
                stab arrow_buf+1            ; Blink Bit l�schen
                ldab #A_ON                  ; Kommando f�r an holen
                bra  aws_send
aws_blnk_chk
                ldaa arrow_buf+1
                tab
                anda 0,x                    ; Blink Bit isolieren
                beq  aws_blink              ; Wenn nicht gesetzt -> aktivieren
                ldaa arrow_buf
                tab
                anda 0,x                    ; aktiviert?
                bne  aws_end                ; Ja, dann Ende
                ldab arrow_buf+1            ; Blink Status holen
aws_blink
                orab 0,x                    ; Blink Bit setzen
                stab arrow_buf+1            ; Status speichern
                ldab arrow_buf
                orab 0,x                    ; On Bit setzen
                stab arrow_buf              ; Status speichern
                ldab #A_BLINK               ; Blink Kommando laden
                bra  aws_send
aws_invert_chk
                ldaa arrow_buf
                tab
                anda 0,x                    ; Arrow schon an?
                bne  aws_off                ; Ja -> deaktivieren
                ldaa arrow_buf+1
                tab
                anda 0,x                    ; blinken?
                bne  aws_blink              ; Ja, dann blinken
                ldab arrow_buf
                bra  aws_on                 ; Ansonsten normal einschalten
aws_send
                ldaa cpos
                psha
                pshb
                ldaa #'p'
                ldab 1,x
                jsr  lcd_cpos               ; Cursor setzen
                pulb
                addb #ARROW
                ldaa #'p'
                jsr  putchar                ; Arrow setzen
                pulb
                jsr  lcd_cpos
aws_end
                ins

                pulb
                pula
                pulx
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
;                 'c' - ASCII Char
;                 'x' - unsigned int (hex, 8 Bit)
;                 'u' - unsinged int (dezimal, 8 Bit)
;                 'l' - longint (dezimal, 32 Bit)
;                 'p' - PLAIN, gibt Zeichen unver�ndert aus, speichert es NICHT im Puffer
;                       Anwendung von 'p' : Senden von Display Befehlen (Setzen des Cursors, Steuern der LEDs, etc.)
;
;
;             B - Zeichen in Modus c,x,u,p
;                 Anzahl nicht darzustellender Ziffern in Modus 'l' (gez�hlt vom Ende! - 1=Einer, 2=Zehner+Einer, etc...)
;
;             Stack - Longint in Modus l
;
; Ergebnis :    nothing
;
; changed Regs: none
;
; changed Mem : CPOS,
;               DBUF
;
;
putchar
               pshb
               psha
               pshx

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
               ldx  plain_vector
               jmp  0,x
;               pc_ext_send2    ; Plain - sende Bytevalue wie erhalten
pc_to_end
               jmp  pc_end          ; unsupported mode, abort/ignore

pc_char_out    ; ASCII Zeichen in B
               ldaa cpos            ; Cursorposition holen
               cmpa #8              ; Cursorpos >=8?
               bcc  pc_end          ; Dann ist das Display voll, nix ausgeben (geht auch viel schneller)
               jsr  pc_cache        ; Pr�fen ob Zeichen schon an dieser Position geschrieben wurde
               tsta                 ; Wenn ja,
               beq  pc_end          ; dann nichts ausgeben
               jsr  store_dbuf      ; Zeichen in Displaybuffer speichern (ASCII)

pc_convert_out
               clra                 ; HiByte = 0
               subb #$20            ; ASCII chars <$20 not supported
               pshb                 ; Index merken
               lsld                 ; Index f�r Word Eintr�ge berechnen
               addd #char_convert   ; Basisadresse hinzuf�gen
               xgdx
               ldd  0,x

pc_sendchar
               pshb
               psha                   ; Tabellenzeichen merken
               tsta
               beq  pc_single         ; Zeichencode mit 1 Bytes?
               tab
pc_double
               jsr  sci_tx_w          ; Zeichen senden
               jsr  sci_ack           ; Auf Best�tigung warten
               tsta                   ; Zeichen erfolgreich gesendet?
               bne  pc_double         ; Wenn nicht, nochmal senden
               tsx
               ldab 1,x               ; Tabelleneintrag holen

pc_single                             ; Ausgabe von Zeichencodes mit 1 Byte
               jsr  sci_tx_w          ; send 2nd char
               jsr  sci_ack           ; Auf Quittung warten
               tsta                   ; Erfolgreich gesendet?
               bne  pc_single         ; Nein? Dann nochmal probieren
               pula
               pulb                   ; gemerkten Tabelleneintrag holen
               oraa #$10
               cmpa #$5D              ; War Byte 1 = $4D oder $5D?
               beq  pc_extended       ; dann m�ssen wir noch ein $4E Char senden
               pulb
               bra  pc_end
pc_extended
               clra
               ldx  #e_char_convert
               pulb
               abx
               ldab 0,x               ; extended character holen
               pshb                   ; Character sichern
               ldab #$4E              ; Extended Zeichen senden
pc_ext_send1
               jsr  sci_tx_w          ; send char
               jsr  sci_ack           ; Best�tigen lassen
               tsta
               bne  pc_ext_send1      ; nochmal senden, falls erfolglos gesendet

               pulb                   ; Character senden
pc_ext_send2
               jsr  sci_tx_w          ; send char
               jsr  sci_ack           ; Echo Char lesen
               tsta                   ; bei Fehler
               bne  pc_ext_send2      ; wiederholen
pc_end
               pulx
               pula
               pulb
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
; �berspringt Zeichen, die schon auf dem Display vorhanden sind
; Falls ein Unterschied zwischen vorhandenem und zu schreibenden Zeichen
; auftritt, wird der Cursor von dieser Funktion korrekt positioniert
;
; Parameter : B - Zeichen (ASCII)
;
; Ergebnis :  A - 0 = Zeichen �berspringen
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

               ldaa pcc_cdiff_flag    ; Unterscheidet sich Cursorposition in CPOS von tats�chlicher Cursorposition?
               beq  pcc_diff          ; Nein, dann weitermachen - Returnvalue = 'Zeichen ausgeben'

               ldaa #'p'
               addb #$60              ; $60 zu Cursorposition addieren -> Positionierungsbefehl erzeugen
               jsr  putchar           ; Cursor korrekt positionieren
               clr  pcc_cdiff_flag    ; Flag l�schen, Positionen stimmen wieder �berein
               bra  pcc_diff
pcc_same
               inc  cpos              ; Cursor weitersetzen
               ldab #1
               stab pcc_cdiff_flag    ; Cursorposition in CPOS unterscheidet sich von tats�chlicher
               clra                   ; Returnvalue: 'Zeichen �berspringen'
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
; Formatiert einen 8 Bit Integer f�r Hexadezimale Darstellung um und gibt ihn aus
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
               cmpb #$0A                        ; Wert
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
; Formatiert einen 8 Bit Integer f�r Dezimale Darstellung um und gibt ihn aus
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
; Formatiert einen 32 Bit Integer f�r Dezimale Darstellung um und gibt ihn aus
;
; Parameter : B - Anzahl der vom Ende der Zahl abzuschneidenden Ziffern
;
;             Stack - 32 Bit Integer
;
; Ergebnis : none
;
; changed Regs : A,B,X
;
;
;11 Long LoWord,LoByte
;10 Long LoWord,HiByte
; 9 Long HiWord,LoByte
; 8 Long HiWord,HiByte
; 7 B
; 6 A
; 5 XL
; 4 XH
; 3 R-Adresse2 lo
; 2 R-Adresse2 hi
; 1 R-Adresse1 lo
; 0 R-Adresse1 hi
;
ulongout
               pshb                   ; B = nr of digits to cut off from end - push onto stack
               tsx
               ldd  11,x              ; get Longint/LoWord
               tst  0,x               ; cut something?
               beq  ulongout_divend   ; if not -> print longint directly
ulongout_divloop
               pshb
               psha                   ; push Longint/LoWord on Stack
               tsx
               ldx  11,x              ; get Longint/HiWord
               pshx                   ; store on Stack
               ldd  #10               ; get Divisor
               jsr  divide32          ; divide longint by 10 (to cut off one digit)
               pula
               pulb
               tsx
               std  11,x              ; store new longint / HiWord
               pula
               pulb
               std  13,x               ; store new longint / LoWord
               dec  2,x                ; cut off another digit?
               bne  ulongout_divloop   ; yes? then repeat the division
               tsx
ulongout_divend
               ldx  9,x                ; get longint HiWord
               pshb
               psha                    ; push LoWord onto stack
               pshx                    ; push HiWord onto stack as parameter for "ulongdec"
               jsr  ulongdec           ; output everything
               pulx
               pulx                    ; remove Parameters from stack
               ins                     ; remove "cut-off" counter from stack

               rts

;******************
; U L O N G   D E C
;
; Putchar Subroutine f�r dezimale Ausgabe
;
; Teilt den Longint Wert rekursiv solange durch 10, bis der Quotient 0 ist,
; danach wird der Wert ausgegeben
;
;
ulongdec
               pshx
               pshb
               psha                    ; Register sichern

               tsx
               ldd  8,x                ; Dividend LoWord holen
               pshb
               psha                    ; auf Stack speichern
               ldx  6,x                ; Dividend HiWord holen
               pshx                    ; auf Stack speichern
               ldd  #10                ; Divisor holen
               jsr  divide32           ; Division durchf�hren
               pshx                    ; Rest sichern
                                       ; Quotient ist bereits auf Stack
               tsx
               orab 2,x                ;
               orab 3,x                ;
               subd #0                 ; 32 Bit Quotient = 0 ?
               pula
               pulb                    ; Rest wiederholen
               beq  uld_out            ; Wenn der Quotient = 0 ist, Zeichen ausgeben
               jsr  ulongdec           ; wenn >0, diese funktion rekursiv aufrufen
uld_out
               pulx
               pulx                    ; Quotient vom Stack l�schen
               addb #$30               ; ASCII Char erzeugen
               ldaa #'c'
               jsr  putchar
uld_end
               pula
               pulb
               pulx
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
printf
               ; X : Pointer auf 0-terminated String
               ; changed Regs: X
               pshb
               psha
print_loop
               ldab 0,x             ; Zeichen holen
               beq  end_printf      ; =$00 ? Dann String zu Ende -> Return
               inx                  ; Zeiger auf n�chstes Zeichen
               cmpb #'%'            ; auf "%" testen
               beq  print_num       ;
               cmpb #backslash      ; auf "\" testen
               beq  print_special
print_char
               ldaa #'c'
print_put
               pshx
               jsr  putchar
               pulx
               bra  print_loop
end_printf
               pula
               pulb
               rts
print_special
               ldab 0,x
               bra  print_char
print_num
               ldaa 0,x
               bra  print_put

;#################################
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
key_convert
               .db  $00
               .db  $11 ;D1
               .db  $12 ;D2
               .db  $13 ;D3
               .db  $14 ;D4
               .db  $15 ;D5
               .db  $16 ;D6
               .db  $17 ;D7
               .db  $18 ;D8
               .db  $03 ; 3
               .db  $06 ; 6
               .db  $09 ; 9
               .db  $19 ; #
               .db  $02 ; 2
               .db  $05 ; 5
               .db  $08 ; 8
               .db  $00 ; 0
               .db  $01 ; 1
               .db  $04 ; 4
               .db  $07 ; 7
               .db  $10 ; *

