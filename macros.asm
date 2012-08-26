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
;
; Additional instructions for HD6303
; HD6303 is a superset of MC6801/MC6803 which is a superset of MC6800
;
.ADDINSTR AIM     #*,*,X  61      3       COMB    8
.ADDINSTR AIM     #*,*    71      3       COMB    8
.ADDINSTR EIM     #*,*,X  65      3       COMB    8
.ADDINSTR EIM     #*,*    75      3       COMB    8
.ADDINSTR OIM     #*,*,X  62      3       COMB    8
.ADDINSTR OIM     #*,*    72      3       COMB    8
.ADDINSTR SLP     ""      1A      1       NOP     8
.ADDINSTR TIM     #*,*,X  6B      3       COMB    8
.ADDINSTR TIM     #*,*    7B      3       COMB    8
.ADDINSTR XGDX    ""      18      1       NOP     8

; Define hardware to compile for
;
;
#DEFINE EVA5
;#DEFINE EVA9
;#DEFINE BAND2M
#DEFINE BAND70CM
#ifndef EVA5
#ifndef EVA9
.ECHO "\r\n ERROR: Select a model hardware to compile for: EVA5 or EVA9!\r\n"
.END
#endif
#endif
;************************
; Stack
;
#ifdef EVA5
#DEFINE STACK1  $1fff
#DEFINE STACK2  $1eff
#endif
#ifdef EVA9
#DEFINE STACK1  $013f     ; Main Loop Stack - max 32 Bytes
#DEFINE STACK2  $00ff     ; UI Task Stack   - ~100 Bytes
#DEFINE DEBSTACK $00b3    ; Stack für Debug Ausgaben
#endif
;
;************************
; Timing
; Frequency of crystal in EVA5
#ifdef EVA5
#define XTAL 7977600
#endif
#ifdef EVA9
; Frequency of crystal in EVA9
#define XTAL 4924800
#endif
;
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
;
;
; remove this comment to run the binary in the simulator
;#define SIM
;************************
; Frequency settings
;
;
#DEFINE RXZF   21400000         ; 21.4 MHz IF (RX VCO has to be 21,4MHz below RX frequency)
#DEFINE FREF   14400000         ; 14.4 MHz reference frequency
#DEFINE FOFF0         0         ; Offset0
#DEFINE FOFF06  0600000         ; Offset1
#DEFINE FOFF76  7600000         ; Offset2
#DEFINE FSTEP     12500         ; Schrittweite !> 3,5 kHz für f<458,3MHz ( muß größer sein als Frequenz/(Vorteiler*1023) )
;
;
#ifndef BAND2M
#ifndef BAND70CM
.ECHO "\r\nNo frequency band selected, using 2m / 144 MHz as default\r\n"
#define BAND2M
#endif
#endif
;
#IFDEF BAND2M
;
.ECHO   "\r\nCompiling for 144 MHz\r\n\r\n"
#DEFINE FBASE 140000000         ; lowest frequency (for eeprom storage) = 140MHz (430 MHz with 70 cm)
#DEFINE FBASE_MEM_RECALL 140000000
#DEFINE FDEF  145500000         ; Default Frequency
#DEFINE FTXOFF  FOFF06          ; Offset1
#DEFINE PRESCALER    40         ; PLL Prescaler (40 für 2m, 127 für 70cm)
;
#ELSE                           ; assume 70 cm
;
.ECHO   "\r\nCompiling for 430 MHz\r\n\r\n"
#DEFINE FBASE 430000000         ; lowest frequency (for eeprom storage) = 140MHz (430 MHz with 70 cm)
#DEFINE FBASE_MEM_RECALL 400000000
#DEFINE FDEF  433500000         ; Default Frequency
#DEFINE FTXOFF   FOFF76         ; Offset1
#DEFINE PRESCALER   127         ; PLL Prescaler (40 für 2m, 127 für 70cm)
;
#ENDIF

#DEFINE PLLREF FREF/FSTEP
;
;
#define CTCSS_INDEX_MAX 55

; **************************************************************


#DEFINE WAIT(ms)    pshx \ ldx  #ms \ jsr wait_ms \ pulx
#DEFINE LCDDELAY  41     ; 41ms
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

;******************************************************************
#DEFINE P_SIGIN 1

;******************************************************************
; Blink Char
#DEFINE CHR_BLINK     $80
; non printable chars
#DEFINE semikolon  $3B
#DEFINE komma      $2C
#DEFINE backslash  $5C


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
; Parameter:
;           X:D   Summand (32Bit)
;           Stack Summand (32Bit)
; Ergebnis:
;           Stack Summe   (32Bit)
;
; Kommentar siehe MATH.ASM
;
#DEFINE ADD32 pshx
#DEFCONT    \ tsx
#DEFCONT    \ addd 2+2,x
#DEFCONT    \ std  2+2,x
#DEFCONT    \ pula \ pulb
#DEFCONT    \ adcb 1+2,x
#DEFCONT    \ stab 1+2,x
#DEFCONT    \ adca 0+2,x
#DEFCONT    \ staa 0+2,x
;***********************
;
; Parameter:
;           Stack Minuend    (32Bit)
;           X:D   Subtrahend (32Bit)
; Ergebnis:
;           Stack Differenz  (32Bit)
;
; Kommentar siehe MATH.ASM
;
#DEFINE SUB32 pshb \ psha \ pshx
#DEFCONT    \ tsx
#DEFCONT    \ ldd  6,x
#DEFCONT    \ subd 2,x
#DEFCONT    \ std  6,x
#DEFCONT    \ ldd  4,x
#DEFCONT    \ sbcb 1,x
#DEFCONT    \ stab 5,x
#DEFCONT    \ sbcb 0,x
#DEFCONT    \ stab 4,x
#DEFCONT    \ pulx \ pula \ pulb


#DEFINE SUB32b pshb \ psha \ pshx
#DEFCONT    \ tsx
#DEFCONT    \ ldd  2,x
#DEFCONT    \ subd 6,x
#DEFCONT    \ std  6,x
#DEFCONT    \ ldd  0,x
#DEFCONT    \ sbcb 5,x
#DEFCONT    \ stab 5,x
#DEFCONT    \ sbcb 4,x
#DEFCONT    \ stab 4,x
#DEFCONT    \ pulx \ pula \ pulb

; Vorzeichenumkehr
;
; Parameter:
;           X:D   Zahl  (32Bit)
; Ergebnis:
;           Not(Zahl)+1 (Vorzeichenumkehr)
;
; Kommentar siehe MATH.ASM
;
#DEFINE SIGINV32 coma \ comb
#DEFCONT       \ xgdx
#DEFCONT       \ coma \ comb
#DEFCONT       \ xgdx
#DEFCONT       \ addd #1
#DEFCONT       \ xgdx
#DEFCONT       \ adcb #0
#DEFCONT       \ adca #0
#DEFCONT       \ xgdx

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


