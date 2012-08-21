;****************************************************************************
;
;    MC70 - Firmware for the Motorola MC micro trunking radio
;           to use it as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2011  Felix Erckenbrecht, DG1YFE
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
;
; Port Function Macros
;
#DEFINE PTTPORT       Port6_Data
#DEFINE PTTBIT        (1<< 7)

;VCO Select Output
#DEFINE VCOPORT       Port2_Data
#DEFINE VCOBIT        (1<< 5)

;PLL Lock Input
#define LOCKPORT      Port5_Data
#define LOCKBIT       (1<< 5)
;Squelch Input
#define SQPORT        Port5_Data
#define SQBIT_C       (1<< 6)
#define SQBIT_R       (1<< 7)
#define SQEXTPORT     Port5_Data
#define SQEXTDDR      Port5_DDR
#define SQEXTDDRbuf   Port5_DDR_buf
#define SQEXTBIT      (1<< 3)

;
#define SQM_OFF       0
#define SQM_CARRIER   SQBIT_C
#define SQM_RSSI      SQBIT_R

; Interface to shift register
#define SRCLKPORT     Port2_Data
#define SRCLKDDR      Port2_DDR
#define SRCLKBIT      (1<< 2)
#define SRDATAPORT    Port2_Data
#define SRDATADDR     Port2_DDR
#define SRDATABIT     (1<< 1)

; Shift register output
#define SR_RFPA       (1<< 0)
#define SR_9V6        (1<< 1)
#define SR_LCDRESET   (1<< 2)
#define SR_nCLKSHIFT  (1<< 3)
#define SR_AUDIOPA    (1<< 4)
#define SR_MIC        (1<< 5)
#define SR_nTXPWR     (1<< 6)
#define SR_RXAUDIO    (1<< 7)

;*******************
; R E G I S T E R S
;*******************
base
                .MSFIRST                ; Motorola CPU -> MSB First
                .ORG $0000
Port1_DDR 	.db
Port2_DDR 	.db                         ; 20 - Pin 9 - Signalling Decode
                                        ; 21 - Pin10 - Data (PLL, EEPROM)
                                        ; 22 - Pin11 - Clock (PLL, EEPROM)
                                        ; 23 - Pin12 - SCI RX
                                        ; 24 - Pin13 - SCI TX
                                        ; 25 - Pin14 - T/R Shift (VCO Select, 0=TX, 1=RX)
                                        ; 26 - Pin15 - Alert Tone
                                        ; 27 - Pin16 - Shift Reg Latch
Port1_Data  	.db
Port2_Data 	.db                         ; 20 - Pin 9 - Signalling Decode
                                        ; 21 - Pin10 - Data (PLL, EEPROM)
                                        ; 22 - Pin11 - Clock (PLL, EEPROM)
                                        ; 23 - Pin12 - SCI RX
                                        ; 24 - Pin13 - SCI TX
                                        ; 25 - Pin14 - T/R Shift
                                        ; 26 - Pin15 - Alert Tone
                                        ; 27 - Pin16 - Shift Reg Latch
Port3_DDR 	.db
Port4_DDR 	.db
Port3_Data  	.db
Port4_Data 	.db
TCSR1 		.db    			; Bit0 - OLVL Output Level 1 (P21)
					; Bit1 - IEDG Input Edge (P20, 0 - falling, 1 - rising)
					; Bit2 - ETOI enable timer overflow interrupt
					; Bit3 - EOCI enable output compare interrupt
					; Bit4 - EICI enable input capture interrupt
					; Bit5 - TOF timer overflow flag
					; Bit6 - OCF1 output compare flag1
					; Bit7 - ICF input capture flag

FRC                 ; Free Running Counter
FRCH 		.db
FRCL 		.db

OCR1
OCR1H 		.db
OCR1L 		.db

ICR
ICRH 		.db
ICRL 		.db
TCSR2		.db    			; Bit0 - OE1 output enable1 (P21)
                            ; Bit1 - OE2 output enable2 (P25)
                            ; Bit2 - OLVL2 output level 2
                            ; Bit3 - EOCI enable output compare interrupt 2
                            ; Bit4 - unused
                            ; Bit5 - OCF2 output compare flag 2
                            ; Bit6 - OCF1 output compare flag 1
                            ; Bit7 - ICF input capture flag
                .ORG $10
RMCR 		.db     		;

                    ; Transmit Rate/Mode Control Register
TRCSR1 		.db
        					; Bit0 - Wake Up
        					; Bit1 - Transmit Enable
        					; Bit2 - Transmit Interrupt Enable
        					; Bit3 - Receive Enable
        					; Bit4 - Receive Interrupt Enable
        					; Bit5 - Transmit Data Register	Empty
        					; Bit6 - Overrun Framing Error
        					; Bit7 - Receive Data Register Full

RDR 		.db             ; SCI Data Rx Register
TDR 		.db    			; SCI Data Tx Register
RP5CR 		.db
Port5_Data 	.db             ; 50 - Pin17 - Emergency Input
                			; 51 - Pin18 - Power Fail Input (1=Power Fail, 0=Power Good)
                			; 52 - Pin19 - SW B+
                			; 53 - Pin20 - Ext Alarm
                			; 54 - Pin21 - HUB/PGM (mit NMI&Alert Tone verbunden)
                			; 55 - Pin22 - Lock Detect (PLL)
                			; 56 - Pin23 - SQ Det
                			; 57 - Pin24 - RSSI

Port6_DDR 	.db             ; 60 - Pin25 - Key 3/4 Detect (2nd SCI RX)             - 0
                			; 61 - Pin26 - Key 1,(SCI TX Loopback), **/OE Override - 0
                			; 62 - Pin27 - Key 2 (Control Head Spare), **A16       - 1
                			; 63 - Pin28 - Syn Latch (PLL)                         - 1
                			; 64 - Pin29 - Yel LED/Test, Call LED SW2              - 0
                			; 65 - Pin30 - Signalling Encoding MSB                 - var
                			; 66 - Pin31 - Signalling Encoding LSB                 - var
                			; 67 - Pin32 - PTT input                               - 0

;                                                                                      Flash Mod
Port6_Data	.db             ; 60 - Pin25 - Key 3/4 Detect, 2nd SCI RX
                			; 61 - Pin26 - Key 1, Serial Data In (?)   *** /OE Override
                			; 62 - Pin27 - Key 2                       *** A16
                			; 63 - Pin28 - Syn Latch (PLL)
                			; 64 - Pin29 - /Test
                			; 65 - Pin30 - Signalling Encoding MSB
                			; 66 - Pin31 - Signalling Encoding LSB
                			; 67 - Pin32 - PTT input
Port7_Data      .db
OCR2
OCR2H           .db
OCR2L           .db
TCSR3           .db
TCONR           .db                     ; Time Constant Register
T2CNT		.db
TRCSR2 		.db                     ; Transmit/Receive Control Status Register 2
Test_Register 	.db
Port5_DDR 	.db
P6CR 		.db
		.db
		.db
		.db
		.db
		.db
		.db

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; MC MICRO
;
;*****************************
; I N T E R N A L   R A M
;*****************************
int_ram         .ORG   $0040               ; Start of CPU internal RAM
Port2_DDR_buf   .db
Port5_DDR_buf   .db
Port6_DDR_buf   .db
SR_data_buf     .db
                                                     ; 0 - R468/Q405 - TX/RX Switch (1=TX) (PIN 4 )
                                                     ; 1 - STBY&9,6V                       (PIN 5 )
                                                     ; 2 - LCD Reset,                      (PIN 6 )
                                                     ; 3 - /Clock Shift,                   (PIN 7 )
                                                     ; 4 - Audio PA enable (1=enable)      (PIN 14)
                                                     ; 5 - Mic enable                      (PIN 13)
                                                     ; 6 - /TX Power enable                (PIN 12)
                                                     ; 7 - Rx Audio enable (1=enable)      (PIN 11)
stackbuf        .dw
oci_vec         .dw
tasksw          .db
last_tasksw     .db
tasksw_en       .db
start_task      .dw

pcc_cdiff_flag  .db                                    ; Flag

led_buf         .db                        ; Bit 0 (1)  - gelb
                                           ; Bit 1 (2)  - gelb blink
                                           ; Bit 2 (4)  - grün
                                           ; Bit 3 (8)  - grün blink
                                           ; Bit 4 (16) - rot
                                           ; Bit 5 (32) - rot blink
                                           ; Bit 6 (64) - unused
                                           ; Bit 7 (128)- change flag
led_dbuf        .db

arrow_buf       .dw                        ; Bit  0 - Arrow 0
                                           ; Bit  1 - Arrow 1
                                           ; ...
                                           ; Bit  8 - Arrow 0 blink
                                           ; ...
                                           ; Bit 14 - Arrow 6 blink

dbuf            .block 8                   ; Main Display Buffer
cpos            .db                        ; Cursorposition

dbuf2           .block 9                   ; Display Buffer2 + Byte für CPOS

f_in_buf        .block 9                   ; 9 byte buffer

osc1_phase      .dw                        ; dual use: frequency input
osc1_pd         .dw                        ; & oscialltor 1 & 2 (1750 Hz & DTMF)
osc2_phase      .dw
osc2_pd         .dw
oci_int_ctr     .db

f_step          .dw                        ; Schrittweite in Hz

tick_ms         .dw                                  ; 1ms Increment
s_tick_ms       .db                                  ; Software timer
tick_hms        .dw                                  ; 100ms Increment
gp_timer        .db                                  ; General Purpose Timer, 1ms Decrement
ui_timer        .db
next_hms        .db
lcd_timer       .db                                  ; 1ms

#define TXRX       1
#define PLL_LOCKED 2
#define PTT_REQ  $40
#define BUS_BUSY $80
;trx_state       .db
bus_busy        .db

frequency       .dw                                  ; aktuelle Frequenz
                .dw

offset          .dw                                  ; Für RX/TX verwendete Shift (0/+TXS/-TXS)
                .dw
txshift         .dw                                  ;
                .dw
channel         .dw                                  ; aktuell in der PLL gesetzter Kanal
                .dw
ui_frequency    .dw                                    ; Über UI eingegebene Frequenz wird hier gespeichert
                .dw
ui_txshift      .dw                                    ; Über UI eingegebene Frequenz wird hier gespeichert
                .dw

rxtx_state      .db                                   ; 0=RX
ptt_debounce    .db

cfg_defch_save
ui_ptt_req      .db                                   ;

cfg_head        .db                                   ; Type of Control Head

m_svar1         .db
m_svar2         .db
m_state	        .db
m_timer         .dw                                   ; 100ms
m_timer_en      .db    $00

sql_timer       .db
sql_mode        .db                                   ; Mode ($80 = Carrier, $40 = RSSI, 0 = off)
sql_ctr         .db

mem_bank        .db                                    ; aktuelle Bank / Frequenzspeicherplätze

pll_locked_flag .db                                   ; Bit 0 - PLL not locked
pll_timer       .db

tone_timer      .db
tone_index      .db
oci_ctr         .db

ts_count        .dw

osc1_dither
osc3_phase      .dw                        ; dual use: frequency input
osc_buf         .db

osc3_pd         .dw                        ; & oscialltor 1 & 2 (1750 Hz & DTMF)
o2_en_          .db
o2_en1          .db
o2_en2          .db
o2_dither       .db

;*****************************
; I O   R I N G B U F F E R
;*****************************
#DEFINE io_menubuf_size   4
#DEFINE io_menubuf_mask io_menubuf_size-1
io_menubuf      .block  io_menubuf_size               ; Menü Ringbuffer - 8 Byte
io_menubuf_w    .db                                   ; Write-Pointer (zu Basisadresse addieren)
io_menubuf_r    .db                                   ; Read-Pointer (zu Basisadresse addieren)
io_menubuf_e    .db                                   ; Overflow Error

#DEFINE io_inbuf_size   4
#DEFINE io_inbuf_mask   io_inbuf_size-1
io_inbuf        .block  io_inbuf_size                 ; Input Ringbuffer - 4 Byte
io_inbuf_w      .db                                   ; Write-Pointer (zu Basisadresse addieren)
io_inbuf_r      .db                                   ; Read-Pointer (zu Basisadresse addieren)
io_inbuf_er     .db                                   ; Overflow Error

#DEFINE io_outbuf_size  4
#DEFINE io_outbuf_mask  io_outbuf_size-1
io_outbuf_w     .db                                   ; Write-Pointer (zu Basisadresse addieren)
io_outbuf_r     .db                                   ; Read-Pointer (zu Basisadresse addieren)
io_outbuf_er    .db                                   ; Overflow Error
io_outbuf       .block  io_outbuf_size                ; Output Ringbuffer - 16 Byte
;****************
; E X T   R A M
;****************
#DEFINE SUBAUDIOBUF_LEN 24+2
ext_ram         .org $0200
subaudiobuf     .org $0400
                .block SUBAUDIOBUF_LEN

;##############################
; S T A R T   V E K T O R E N
;##############################
Start_vec       .org  $FFD0
                .dw   $FFFF
                .dw   $FFFF
                .dw   $FFFF
                .dw   $FFFF
                .dw   $FFFF
                .dw   $FFFF
                .dw   $FFFF
                .dw   Start

start_vec_sel   .db   $FF
;##############################
; C P U   I N T - V E C T O R S
;##############################

                .org  $FFE8
OCR_def_value   .dw   $99B4
IRQ2_vector     .dw   IRQ2_SR
CMI_vector      .dw   CMI_SR
TRAP_vector     .dw   TRAP_SR
SIO_vector      .dw   SIO_SR
TOI_vector      .dw   TOI_SR
OCI_vector      .dw   OCI_SR
ICI_vector      .dw   ICI_SR
IRQ1_vector     .dw   IRQ1_SR
SWI_vector      .dw   SWI_SR
NMI_vector      .dw   NMI_SR
RESET_vector    .dw   reset
;RESET_vector    .dw   debug_loader
