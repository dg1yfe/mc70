;****************************************************************************
;
;    MC70     v1.0   - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2010  Felix Erckenbrecht, DG1YFE
;
;
;
;****************************************************************************
;************************
; Stack
;
;
;****************************************************************************
#DEFINE STACK1  $1FFF
#DEFINE STACK2  $1EFF
;************************
; Timing
; Frequency of crystal
#DEFINE XTAL 7977600
; System clock ("E") is 1/4th of that
#DEFINE SYSCLK XTAL/4
;
#DEFINE MENUTIMEOUT   40  ; 4 sek Eingabetimeout
#DEFINE PLLCHKTIMEOUT 2   ; 200ms Timeout für PLL Check
#DEFINE PTT_DEBOUNCE_VAL 20
#DEFINE TX_TO_RX_TIME 5  ; 5 ms TX -> RX Umschaltung
#DEFINE RX_TO_TX_TIME 5  ; 5 ms RX -> TX Umschaltung
;
;************************
#DEFINE TONE_DPHASE SYSCLK/(2*1750)-1  ; Tone Phase Delta (Xtal/4/2 /Tone -1)
;
;
;************************
; Frequenzkram
;
;#DEFINE FBASE 140000000         ; lowest frequency (for eeprom storage) = 140MHz (430 MHz with 70 cm)
#DEFINE FBASE 430000000         ; lowest frequency (for eeprom storage) = 140MHz (430 MHz with 70 cm)
;
;#DEFINE FDEF  145500000         ; Default Frequency
#DEFINE FDEF  433500000         ; Default Frequency
#DEFINE RXZF   21400000         ; 21,4 MHz IF (RX VCO has to be 21,4MHz below RX frequency)
#DEFINE FREF   14400000         ; 14,4 MHz reference frequency
#DEFINE FOFF0         0         ; Offset0
#DEFINE FOFF06  0600000         ; Offset1
#DEFINE FOFF76  7600000         ; Offset1
#DEFINE FSTEP     12500         ; Schrittweite !> 3,5 kHz für f<458,3MHz ( muß größer sein als Frequenz/(Vorteiler*1023) )
;
#DEFINE PLLREF FREF/FSTEP
;#DEFINE PRESCALER    40         ; PLL Prescaler (40 für 2m, 127 für 70cm)
#DEFINE PRESCALER   127         ; PLL Prescaler (40 für 2m, 127 für 70cm)
#DEFINE PLLLOCKWAIT 200         ; Maximale Wartezeit in ms für PLL um einzurasten
;#DEFINE FSTEP      6250        ; Schrittweite !> 3,5 kHz für f<458,3MHz ( muß größer sein als Frequenz/(128*1023) )
;#DEFINE PLLREF     1152
;#DEFINE PLLREF     2304
;
;************************
; Squelch
;
#DEFINE SQL_HYST   10           ; define squelch hysteresis in 5 ms steps
;
; **************************************************************
#DEFINE RED_LED       $33
#DEFINE YEL_LED       $31
#DEFINE GRN_LED       $32
#DEFINE LED_OFF       0
#DEFINE LED_ON        4
#DEFINE LED_BLINK     8
#DEFINE LED_INVERT    128

#DEFINE ARROW         $6D
#DEFINE A_OFF           0
#DEFINE A_ON            1
#DEFINE A_BLINK         2

; Blink Char
#DEFINE CHR_BLINK     $80

; non printable chars
#DEFINE semikolon  $3B
#DEFINE komma      $2C
#DEFINE backslash  $5C


#DEFINE WAIT(ms)    pshx \ ldx  #ms \ jsr wait_ms \ pulx
#DEFINE LCDDELAY  41     ; 41ms

#DEFINE PCHAR(cmd)  ldaa #'c' \ ldab #cmd \ jsr putchar
#DEFINE PUTCHAR     ldaa #'c' \ jsr putchar
#DEFINE PINT(cmd)   ldaa #'u' \ ldab #cmd \ jsr putchar
#DEFINE PHEX(cmd)   ldaa #'x' \ ldab #cmd \ jsr putchar
#DEFINE PPLAIN(cmd) psha \ ldaa #'p' \ ldab #cmd \ jsr putchar \ pula

#DEFINE PRINTF(cmd) pshx \ ldx #cmd \ jsr printf \ pulx
; *******
; I 2 C
; *******
; Clock Toggle
#DEFINE I2C_CT oim #%100, Port2_Data \ aim #%11111011, Port2_Data
;
; Clock Pin auf Ausgang schalten
#DEFINE I2C_CO oim #%100, Port2_DDR_buf \ ldaa Port2_DDR_buf \ staa Port2_DDR \
;
; Clock In
; Clock Pin auf Eingang schalten
#DEFINE I2C_CI aim #%11111011, Port2_DDR_buf \ ldaa Port2_DDR_buf \ staa Port2_DDR
;
#DEFINE I2C_CIb aim #%11111011, Port2_DDR_buf \ ldab Port2_DDR_buf \ stab Port2_DDR
;
; Clock Pin auf Eingang schalten, Pull-Up Widerstand zieht Leitung auf Hi
#DEFINE I2C_CH I2C_CI
;
#DEFINE I2C_CHb I2C_CIb
;
; Clock Lo
; Clock Pin auf Ausgang schalten und auf 0 setzen
#DEFINE I2C_CL  aim #%11111011, Port2_Data \ oim #%100, Port2_DDR_buf \ ldaa Port2_DDR_buf \ staa Port2_DDR
;
#DEFINE I2C_CLb aim #%11111011, Port2_Data \ oim #%100, Port2_DDR_buf \ ldab Port2_DDR_buf \ stab Port2_DDR
;
#DEFINE I2C_CTGL psha \ I2C_CH \ nop \ nop \ I2C_CL \ pula
; Data in
; Data Pin auf Eingang setzen, ( High durch PullUp )
#DEFINE I2C_DI aim #%11111101, Port2_DDR_buf \ ldaa Port2_DDR_buf \ staa Port2_DDR
; Data out
; Data Pin auf Ausgang setzen
#DEFINE I2C_DO oim #%10, Port2_DDR_buf \ ldaa Port2_DDR_buf \ staa Port2_DDR
; Data Hi
#DEFINE I2C_DH I2C_DI
; Data Lo
#DEFINE I2C_DL  aim #%11111101, Port2_Data \ oim #%10, Port2_DDR_buf \ ldaa Port2_DDR_buf \ staa Port2_DDR
;
#DEFINE I2C_DLb aim #%11111101, Port2_Data \ oim #%10, Port2_DDR_buf \ ldab Port2_DDR_buf \ stab Port2_DDR
; Data & Clock Lo
#DEFINE I2C_CDL oim #%110, Port2_DDR_buf \ ldaa Port2_DDR_buf \ staa Port2_DDR \ aim #%11111001, Port2_Data
; Data & Clock Hi
#DEFINE I2C_CDH aim #%11111001, Port2_DDR_buf \ ldaa Port2_DDR_buf \ staa Port2_DDR
;***********************
;
; Character Stuff
;
#DEFINE LCD_A     $4A
#DEFINE LCD_ULINE $4B
#DEFINE LCD_SPACE $4C
;
;
; "segment type""pos hor""pos. vert""diagonal"
#DEFINE seg15left  $4D
#DEFINE seg15right $4E
#DEFINE seg7       $4E
#DEFINE segblink   $10

#DEFINE seg15o   $10
#DEFINE seg15lo  $20
#DEFINE seg15lod $02
#DEFINE seg15lu  $40
#DEFINE seg15u   $01
#DEFINE seg15lud $08
#DEFINE seg15lm  $04

#DEFINE seg15mo  $20
#DEFINE seg15mu  $40
#DEFINE seg15rod $04
#DEFINE seg15ro  $01
#DEFINE seg15ru  $02
#DEFINE seg15rud $10
#DEFINE seg15rm  $08

#DEFINE seg7o  $04
#DEFINE seg7m  $08
#DEFINE seg7u  $10
#DEFINE seg7lo $20
#DEFINE seg7lu $40
#DEFINE seg7ro $01
#DEFINE seg7ru $02

;4D - solid:
;5D - blink:
;Cursor bleibt stehen nach $xD zur Ergänzung des Zeichens mit $xE
;15Seg:
;    1010
;20 02 __ __ __
;20  02____  __
;  0404  ____
;40  08____  __
;40 08 __ __ __
;    0101

;4E - solid:
;5E - blink:
;Segment Codes

;7Seg:
;  04
;20  01
;  08
;40  02
;  10

;15Seg:
;     ____
;__ __ 20 04 01
;__  __2004  01
;  ____  0808
;__  __4010  02
;__ __ 40 10 02
;    ____
;

; Tastencodes - Dx = Taste unter Display, Nx=numerische Tasten
;
#DEFINE D1 $01
#DEFINE D2 $02
#DEFINE D3 $03
#DEFINE D4 $04
#DEFINE D5 $05
#DEFINE D6 $06
#DEFINE D7 $07
#DEFINE D8 $08
#DEFINE CLEAR $14
#DEFINE N1 $11
#DEFINE N2 $0D
#DEFINE N3 $09
#DEFINE N4 $12
#DEFINE N5 $0E
#DEFINE N6 $0A
#DEFINE N7 $13
#DEFINE N8 $0F
#DEFINE N9 $0B
#DEFINE STERN $14
#DEFINE N0 $10
#DEFINE RAUTE $0C
;
;
; Tastencodes nach "Key-Convert" Tabelle ( 0 - 9 = Numerische Tasten)
;
;
#DEFINE KC_D1 $11
#DEFINE KC_D2 $12
#DEFINE KC_D3 $13
#DEFINE KC_D4 $14
#DEFINE KC_D5 $15
#DEFINE KC_D6 $16
#DEFINE KC_D7 $17
#DEFINE KC_D8 $18
#DEFINE KC_RAUTE $19
#DEFINE KC_STERN $10

#DEFINE KC_CLEAR KC_D4


