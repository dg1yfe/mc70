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
;*******************
; R E G I S T E R S
;*******************
base
                .MSFIRST                ; Motorola CPU -> MSB First
                .ORG $0000
Port1_DDR 	.db
Port2_DDR 	.db                     ; 20 - Pin 9 - Signalling Decode
                                        ; 21 - Pin10 - Data (PLL, EEPROM)
                                        ; 22 - Pin11 - Clock (PLL, EEPROM)
                                        ; 23 - Pin12 - SCI RX
                                        ; 24 - Pin13 - SCI TX
                                     ;* ; 25 - Pin14 - DPTT (TX Power Enable)
                                        ; 26 - Pin15 - Alert Tone
                                        ; 27 - Pin16 - Shift Reg Latch
Port1_Data      .db
Port2_Data 	.db                     ; 20 - Pin 9 - Signalling Decode
                                        ; 21 - Pin10 - Data (PLL, EEPROM)
                                        ; 22 - Pin11 - Clock (PLL, EEPROM)
                                        ; 23 - Pin12 - SCI RX
                                        ; 24 - Pin13 - SCI TX
                                     ;* ; 25 - Pin14 - DPTT (TX Power Enable)
                                        ; 26 - Pin15 - Alert Tone
                                        ; 27 - Pin16 - Shift Reg Latch
Port3_DDR 	.db
Port4_DDR 	.db
Port3_Data      .db
Port4_Data 	.db
TCSR1 		.db    			; Bit0 - OLVL Output Level 1 (P21)
					; Bit1 - IEDG Input Edge (P20, 0 - falling, 1 -	rising)
					; Bit2 - ETOI enable timer overflow interrupt
					; Bit3 - EOCI enable output compare interrupt
					; Bit4 - EICI enable input capture interrupt
					; Bit5 - TOF timer overflow flag
					; Bit6 - OCF1 output compare flag1
					; Bit7 - ICF input capture flag
FRC
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

RDR 		.db                     ; SCI Data Rx Register
TDR 		.db    			; SCI Data Tx Register
RP5CR 		.db
Port5_Data 	.db                     ; 50 - Pin17 - Emergency Input
				    ;*  ; 51 - Pin18 - PTT Input
				    ;*	; 52 - Pin19 - EEPROM Power Strobe ( 0 = EEPROM on)
				    ;*	; 53 - Pin20 - TEST Input
					; 54 - Pin21 - HUB/PGM (mit NMI&Alert Tone verbunden)
				    ;*	; 55 - Pin22 - SQ Det
				    ;*	; 56 - Pin23 - Lock Detect (PLL)
				    ;*	; 57 - Pin24 - SW B+

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
SR_data_buf     .db
                                                     ; 0 - Audio PA enable (1=enable)      (PIN 4 ) *
                                                     ; 1 - STBY&9,6V                       (PIN 5 )
                                                     ; 2 - T/R Shift                       (PIN 6 ) *
                                                     ; 3 - Hi/Lo Power (1=Lo Power)        (PIN 7 ) *
                                                     ; 4 - Ext. Alarm                      (PIN 14) *
                                                     ; 5 - Sel.5 ATT   (1=Attenuated Tones)(PIN 13) *
                                                     ; 6 - Mic enable  (1=enable)          (PIN 12) *
                                                     ; 7 - Rx Audio enable (1=enable)      (PIN 11)
stackbuf        .dw
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

tick_ms         .dw                                  ; 1ms Increment
tick_hms        .dw                                  ; 100ms Increment
gp_timer        .db                                  ; General Purpose Timer, 1ms Decrement
next_hms        .dw
lcd_timer       .dw                                  ; 1ms

irq_wd_reset    .db

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
ui_ptt_req      .db                                   ;

m_state		.db
m_menu          .db                                   ; Speicher für Untermenu
m_timer         .dw                                   ; 100ms
m_timer_en      .db    $00

sql_flag        .db
sql_timer       .db
pwr_mode                                              ; Mode Flag Bit   Function
sql_mode        .db                                   ;           7,6 = Power On Message
                                                      ;           5   = Carrier Squelch
                                                      ;           0   = Power (1=Lo, 0=Hi)

msg_mode        .db
mem_bank        .db                                    ; aktuelle Bank / Frequenzspeicherplätze

pll_locked_flag .db                                   ; Bit 0 - PLL not locked
pll_timer       .db

tone_timer      .db
tone_index      .db

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

#DEFINE io_outbuf_size  4
#DEFINE io_outbuf_mask  io_outbuf_size-1
io_outbuf_w     .db                                   ; Write-Pointer (zu Basisadresse addieren)
io_outbuf_r     .db                                   ; Read-Pointer (zu Basisadresse addieren)
io_outbuf_er    .db                                   ; Overflow Error
io_outbuf       .block  io_outbuf_size                ; Output Ringbuffer - 16 Byte


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
