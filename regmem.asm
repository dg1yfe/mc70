;****************************************************************************
;
;    MC70 - Firmware for the Motorola MC micro trunking radio
;           to use it as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2013  Felix Erckenbrecht, DG1YFE
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
; Common macros
;
; Internal State register
#define BIT_PLL_STATE (1 << 0)
#define BIT_PLL_UPDATE_NOW (1 << 1)
#define BIT_MTIMER_EN (1 << 7)
;
;
#IFDEF EVA5
#DEFINE PTTPORT       Port6_Data
#DEFINE PTTBIT        (1 << 7)

#DEFINE PORT_PLLLATCH Port6_Data
#DEFINE BIT_PLLLATCH  (1 << 3)

;VCO Select Output
#DEFINE VCOPORT       Port2_Data
#DEFINE VCOBIT        (1 << 5)

;Local tone output (alert tone)
#define PORT_ATONE    Port2_Data
#define DDR_ATONE     Port2_DDR
#define DDRbuf_ATONE  Port2_DDR_buf
#define BIT_ATONE     (1 << 6)

;PLL Lock Input
#define LOCKPORT      Port5_Data
#define LOCKBIT       (1 << 5)

;Power switch input
#define PORT_SWB      Port5_Data
#define BIT_SWB       (1 << 2)

;Power switch input
#define PORT_PWRFAIL  Port5_Data
#define BIT_PWRFAIL   (1 << 1)

;Squelch Input
#define PORT_SQ       Port5_Data
#define BIT_SQC       (1<< 6)
#define BIT_SQR       (1<< 7)

#define PORT_SQEXT    Port5_Data
#define DDR_SQEXT     Port5_DDR
#define DDRbuf_SQEXT  Port5_DDR_buf
#define BIT_SQEXT     (1<< 3)
;
;
#define BIT_UI_PTT_REQ (1 << 0)
#define BIT_DEFCH_SAVE (1 << 1)
#define TX_CTCSS       (1 << 2)
#define CDIFF_FLAG     (1 << 3)
#define SQBIT_C        (1 << 4)
#define SQBIT_R        (1 << 5)
#define SQBIT_BOTH     (SQBIT_R | SQBIT_C)

#define SQM_OFF       0
#define SQM_CARRIER   SQBIT_C
#define SQM_RSSI      SQBIT_R
#define SQM_BOTH      (SQBIT_R | SQBIT_C)
;
; Interface to shift register
#define SRCLKPORT     Port2_Data
#define SRCLKDDR      Port2_DDR
#define SRCLKBIT      (1<< 2)
#define SRDATAPORT    Port2_Data
#define SRDATADDR     Port2_DDR
#define SRDATADDRbuf  Port2_DDR_buf
#define SRDATABIT     (1<< 1)
#define PORT_SRLATCH  Port2_Data
#define DDR_SRLATCH   Port2_DDR
#define BIT_SRLATCH   (1<< 7)

; Shift register output
#define SR_RFPA       (1<< 0)
#define SR_9V6        (1<< 1)
#define SR_LCDRESET   (1<< 2)
#define SR_nCLKSHIFT  (1<< 3)
#define SR_AUDIOPA    (1<< 4)
#define SR_MIC        (1<< 5)
#define SR_nTXPWR     (1<< 6)
#define SR_RXAUDIO    (1<< 7)

#endif
;*************************************
;
; EVA9 CONSTANTS
;
#IFDEF EVA9
#DEFINE PTTPORT       Port5_Data
#DEFINE PTTBIT        (1<< 1)
; TODO: Set correct values for remaining port macros & use them
;VCO Select Output
#DEFINE VCOPORT       Port2_Data
#DEFINE VCOBIT        (1<< 5)

#DEFINE PORT_PLLLATCH Port6_Data
#DEFINE BIT_PLLLATCH  (1<< 7)

;PLL Lock Input
#define LOCKPORT      Port5_Data
#define LOCKBIT       (1<< 6)

;Power switch input
#define PORT_SWB      Port5_Data
#define BIT_SWB       (1 << 7)

;Squelch Input
#define SQPORT        Port5_Data
#define SQBIT         (1<< 5)
;
#define SQM_OFF       0
#define SQM_CARRIER   SQBIT
;
#define BIT_UI_PTT_REQ (1 << 0)
#define BIT_DEFCH_SAVE (1 << 1)
#define TX_CTCSS       (1 << 2)
#define CDIFF_FLAG     (1 << 3)
#define BIT_PWRMODE    (1 << 4)
; Interface to shift register
; #define SRCLKPORT     Port2_Data
; #define SRCLKDDR      Port2_DDR
; #define SRCLKBIT      (1<< 2)
; #define SRDATAPORT    Port2_Data
; #define SRDATADDR     Port2_DDR
; #define SRDATABIT     (1<< 1)

; Shift register output
 ; 0 - Audio PA enable (1=enable)      (PIN 4 ) *
 ; 1 - STBY&9,6V                       (PIN 5 )
 ; 2 - T/R Shift                       (PIN 6 ) *
 ; 3 - Hi/Lo Power (1=Lo), Clk-Shift   (PIN 7 ) *
 ; 4 - Ext. Alarm (0=Lo)               (PIN 14) *
 ; 5 - Sel.5 ATT   (1=Attenuated Tones)(PIN 13) *
 ; 6 - Mic enable  (1=enable)          (PIN 12) *
 ; 7 - Rx Audio enable (1=enable)      (PIN 11)
#define SR_AUDIOPA    (1<< 0)
#define SR_9V6        (1<< 1)
#define SR_TXRX       (1<< 2)
#define SR_CLKSHIFT   (1<< 3)
#define SR_RFPWRHI    (1<< 3)
#define SR_EXTALARM   (1<< 4)
#define SR_SEL5ATT    (1<< 5)
#define SR_MIC        (1<< 6)
#define SR_RXAUDIO    (1<< 7)

#ENDIF

;*******************
; R E G I S T E R S
;*******************
base
                .MSFIRST                ; Motorola CPU -> MSB First
                .ORG $0000
Port1_DDR 	.db
#ifdef EVA5
Port2_DDR 	.db                         ; 20 - Pin 9 - Signalling Decode
                                        ; 21 - Pin10 - Data (PLL, EEPROM)
                                        ; 22 - Pin11 - Clock (PLL, EEPROM)
                                        ; 23 - Pin12 - SCI RX
                                        ; 24 - Pin13 - SCI TX
                                        ; 25 - Pin14 - T/R Shift (VCO Select, 0=TX, 1=RX)
                                        ; 26 - Pin15 - Alert Tone
                                        ; 27 - Pin16 - Shift Reg Latch
#endif
#ifdef EVA9
Port2_DDR 	.db                         ; 20 - Pin 9 - Signalling Decode
                                        ; 21 - Pin10 - Data (PLL, EEPROM)
                                        ; 22 - Pin11 - Clock (PLL, EEPROM)
                                        ; 23 - Pin12 - SCI RX
                                        ; 24 - Pin13 - SCI TX
                                     ;* ; 25 - Pin14 - DPTT (TX Power Enable)
                                        ; 26 - Pin15 - Alert Tone
                                        ; 27 - Pin16 - Shift Reg Latch
#endif
Port1_Data  	.db
#ifdef EVA5
Port2_Data	.db                         ; 20 - Pin 9 - Signalling Decode
                                        ; 21 - Pin10 - Data (PLL, EEPROM)
                                        ; 22 - Pin11 - Clock (PLL, EEPROM)
                                        ; 23 - Pin12 - SCI RX
                                        ; 24 - Pin13 - SCI TX
                                        ; 25 - Pin14 - T/R Shift (VCO Select, 0=TX, 1=RX)
                                        ; 26 - Pin15 - Alert Tone
                                        ; 27 - Pin16 - Shift Reg Latch
#endif
#ifdef EVA9
Port2_Data 	.db                         ; 20 - Pin 9 - Signalling Decode
                                        ; 21 - Pin10 - Data (PLL, EEPROM)
                                        ; 22 - Pin11 - Clock (PLL, EEPROM)
                                        ; 23 - Pin12 - SCI RX
                                        ; 24 - Pin13 - SCI TX
                                     ;* ; 25 - Pin14 - DPTT (TX Power Enable)
                                        ; 26 - Pin15 - Alert Tone
                                        ; 27 - Pin16 - Shift Reg Latch
#endif
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
#ifdef EVA5
Port5_Data 	.db             ; 50 - Pin17 - Emergency Input
                			; 51 - Pin18 - Power Fail Input (1=Power Fail, 0=Power Good)
                			;              -> this one is denoted wrong in the service manual
                			;              where it states: "U601 monitors the B+ voltage level.
                			;              If B+ rise lower than 9,6V the power fail signal
                			;              rise down to 0V." (sic)
                			;              In fact PWR FAIL is 1 when B+ < 9.6 V and 0 when B+>=9.6V
                			; 52 - Pin19 - SW B+
                			; 53 - Pin20 - Ext Alarm
                			; 54 - Pin21 - HUB/PGM (mit NMI&Alert Tone verbunden)
                			; 55 - Pin22 - Lock Detect (PLL)
                			; 56 - Pin23 - SQ Det
                			; 57 - Pin24 - RSSI
#endif
#ifdef EVA9
Port5_Data 	.db     ;   ; 50 - Pin17 - Emergency Input
				    ;*  ; 51 - Pin18 - PTT Input
				    ;*	; 52 - Pin19 - EEPROM Power Strobe ( 0 = EEPROM on)
				    ;*	; 53 - Pin20 - TEST Input
					;   : 54 - Pin21 - HUB/PGM (mit NMI&Alert Tone verbunden)
				    ;*	; 55 - Pin22 - SQ Det
				    ;*	; 56 - Pin23 - Lock Detect (PLL)
				    ;*	; 57 - Pin24 - SW B+

#endif
#ifdef EVA5
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
#endif
#ifdef EVA9
Port6_DDR 	.db                 ;*  ; 60 - Pin25 - Sig. DAC Bit0
				    ;*  ; 61 - Pin26 - Sig. DAC Bit1
				    ;*	; 62 - Pin27 - Sig. DAC Bit2
				    ;*	; 63 - Pin28 - Sig. DAC Bit3
				    ;*	; 64 - Pin29 - PL DAC Bit0
				    ;*	; 65 - Pin30 - PL DAC Bit1
				    ;*	; 66 - Pin31 - PL DAC Bit2
				    ;*	; 67 - Pin32 - Syn Latch


Port6_Data	.db                     ;*  ; 60 - Pin25 - Sig. DAC Bit0
				    ;*  ; 61 - Pin26 - Sig. DAC Bit1
				    ;*	; 62 - Pin27 - Sig. DAC Bit2
				    ;*	; 63 - Pin28 - Sig. DAC Bit3
				    ;*	; 64 - Pin29 - PL DAC Bit0
				    ;*	; 65 - Pin30 - PL DAC Bit1
				    ;*	; 66 - Pin31 - PL DAC Bit2
				    ;*	; 67 - Pin32 - Syn Latch
#endif
Port7_Data      .db
OCR2
OCR2H           .db
OCR2L           .db
TCSR3           .db
TCONR           .db                     ; Time Constant Register
T2CNT		.db
TRCSR2 		.db                     ; Transmit/Receive Control Status Register 2
Test_Register 	.db
Port5_DDR 	.db                     ; 50 - Pin17 - Emergency Input
				    ;*  ; 51 - Pin18 - PTT Input
				    ;*	; 52 - Pin19 - EEPROM Power Strobe ( 0 = EEPROM on)
				    ;*	; 53 - Pin20 - TEST Input
					; 54 - Pin21 - HUB/PGM (mit NMI&Alert Tone verbunden)
				    ;*	; 55 - Pin22 - SQ Det
				    ;*	; 56 - Pin23 - Lock Detect (PLL, 0= unlocked))
				    ;*	; 57 - Pin24 - SW B+
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
#ifdef EVA5
SR_data_buf     .db
                                                     ; 0 - R468/Q405 - TX/RX Switch (1=TX) (PIN 4 )
                                                     ; 1 - STBY&9,6V                       (PIN 5 )
                                                     ; 2 - LCD Reset,                      (PIN 6 )
                                                     ; 3 - /Clock Shift,                   (PIN 7 )
                                                     ; 4 - Audio PA enable (1=enable)      (PIN 14)
                                                     ; 5 - Mic enable                      (PIN 13)
                                                     ; 6 - /TX Power enable                (PIN 12)
                                                     ; 7 - Rx Audio enable (1=enable)      (PIN 11)
#endif
#ifdef EVA9
SR_data_buf     .db
                                                     ; 0 - Audio PA enable (1=enable)      (PIN 4 ) *
                                                     ; 1 - STBY&9,6V                       (PIN 5 )
                                                     ; 2 - T/R Shift                       (PIN 6 ) *
                                                     ; 3 - Hi/Lo Power (1=Lo Power)        (PIN 7 ) *
                                                     ; 4 - Ext. Alarm                      (PIN 14) *
                                                     ; 5 - Sel.5 ATT   (1=Attenuated Tones)(PIN 13) *
                                                     ; 6 - Mic enable  (1=enable)          (PIN 12) *
                                                     ; 7 - Rx Audio enable (1=enable)      (PIN 11)
#endif
stackbuf        .dw
oci_vec         .dw
tasksw          .db
last_tasksw     .db
tasksw_en       .db
start_task      .dw

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

cfg_head        .db                                   ; Type of Control Head
cfg_defch_save  .db

m_svar1         .db
m_svar2         .db
m_state	        .db
m_timer         .dw                                   ; 100ms

sql_timer       .db

tx_ctcss_flag
pcc_cdiff_flag
ui_ptt_req
#ifdef EVA9
pwr_mode                                              ; Mode Flag Bit   Function
#endif
sql_mode        .db                                   ;           7,6 = Power On Message
                                                      ;           5   = Carrier Squelch
                                                      ;           4   = EVA9: Power (1=Lo, 0=Hi)
                                                      ;                 EVA5: RSSI Squelch
                                                      ;           3   = PCC CDIFF FLAG
                                                      ;           2   = CTCSS during TX
                                                      ;           1   = BIT_DEFCH_SAVE
                                                      ;           0   = PTT req. by UI task
;sql_mode        .db                                   ; Mode ($80 = Carrier, $40 = RSSI, 0 = off)
msg_mode        .db
sql_ctr         .db

mem_bank        .db                                    ; aktuelle Bank / Frequenzspeicherplätze

                                                      ; Bit   Function

intern_state                                          ; Internal State Register
m_timer_en                                            ; Bit     FUNCTION
                                                      ;     7 - Menu timer enabled
pll_update_flag                                       ;     1 - request immediate PLL state update
pll_locked_flag .db                                   ;     0 - PLL not locked


pll_timer       .db

tone_timer      .db
ctcss_index     .db

oci_int_ctr     .db

osc1_phase      .dw                        ; dual use: frequency input
osc1_pd         .dw                        ; & oscialltor 1 & 2 (1750 Hz & DTMF)
osc2_phase      .dw                        ; dual use: frequency input
osc2_pd         .dw                        ; & oscialltor 1 & 2 (1750 Hz & DTMF)

#ifdef EVA5
osc1_dither     .dw
#endif
osc_buf         .db
osc3_phase      .dw                        ; dual use: frequency input

osc3_pd         .dw                        ; & oscialltor 1 & 2 (1750 Hz & DTMF)
#ifdef EVA5
o2_en_          .db
o2_en1          .db
o2_en2          .db
o2_dither       .db
#endif
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

f_in_buf        .block 9

#ifdef EVA5
;****************
; E X T   R A M
;****************
#DEFINE SUBAUDIOBUF_LEN 24+2
ext_ram         .org $0200
subaudiobuf     .org $0400
                .block SUBAUDIOBUF_LEN
#endif

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
