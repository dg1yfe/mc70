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
;********************************************************

;********
; N C O
;********
;
; interrupt routines for numerically controlled oscillator
;
;Pin 30 & 31
;    P65 P66
;*****************
;digital tone Oscillator
;
; Single tone oscillator without noise shaping (less CPU usage)
;
OCI_OSC1_sig
OCI_OSC1                            ;   +19
               ldd  osc1_phase      ;+4  23    Phase holen (16 Bit)
               addd osc1_pd         ;+4  27    phasen delta addieren
               std  osc1_phase      ;+4  31    phase speichern

               anda #%00111111      ;+2  33    nur Bits 0-5 berücksichtigen (0-63)
               ldx  #dac_sin_tab    ;+3  36    Start der Sinus-outputtabelle holen

               ldab Port2_Data      ;+3  39    get noise from Signalling Decode Input
               andb #1              ;+2  41    this is cheaper than generating pseudo-noise
               aba                  ;+1  42    using an LFSR and it is REAL noise

               tab                  ;+1  37
               lslb                 ;+1  38
               abx                  ;+1  38    Index addieren

               ldaa Port6_DDR_buf   ;+3  41
               ldab Port6_Data      ;+3  44
               andb #%10001111      ;+2  46
               addd 0,x             ;+5  51    ; add DAC value from sine table
               std  Port6_DDR       ;+4  55    ; store to DDR & Data

oos1_timer
               ldab TCSR2           ;+3  58    ; Timer Control / Status Register 2 lesen
               ldd  OCR1H           ;+4  62
               addd #249            ;+3  65    ; ca 8000 mal pro sek Int auslösen
               std  OCR1H           ;+4  69

               ldaa TCSR2
               anda #%00100000
               beq  oos1_end
               ldd  OCR2
               addd #SYSCLK/1000
               std  OCR2
               dec  gp_timer        ;+6  77    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4  81
               inx                  ;+1  82    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  86

oos1_end
               rti                 ;+10  88 / 112/125/141
;********
; N C O
;********
;
; Single tone oscillator without noise shaping (less CPU usage)
;
OCI_OSC1_pl                         ;   +19
               ldd  osc3_phase      ;+4  23    Phase holen (16 Bit)
               addd osc3_pd         ;+4  27    phasen delta addieren
               std  osc3_phase      ;+4  31    phase speichern

               ldx  #pl_dac_sin_tab ;+3  15    ; Sinustabelle indizieren
               tab                  ;+1  16    ; Phasenwert (int)
               abx                  ;+1  17    ; addieren
               abx                  ;+1  17    ; addieren

;               ldab Port2_Data      ;+3  39    get noise from Signalling Decode Input
;               andb #1              ;+2  41    this is cheaper than generating pseudo-noise
;               abx                  ;+1  42    using an LFSR and it is REAL noise
;               abx                  ;+1  42

               ldaa Port6_DDR_buf   ;+3  41
               ldab Port6_Data      ;+3  44
               andb #%10001111      ;+2  46
               addd 0,x             ;+5  51    ; add DAC value from sine table
               std  Port6_DDR       ;+4  55    ; store to DDR & Data

               ldab TCSR2           ;+3  58    ; Timer Control / Status Register 2 lesen
               ldd  OCR1H           ;+4  62
               addd #SYSCLK/8000    ;+3  65    ; ca 8000 mal pro sek Int auslösen
               std  OCR1H           ;+4  69

               ldaa TCSR2
               anda #%00100000
               beq  oos1p_end
               ldd  OCR2
               addd #SYSCLK/1000
               std  OCR2
               dec  gp_timer        ;+6  77    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4  81
               inx                  ;+1  82    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  86

oos1p_end
               rti                 ;+10  88 / 112/125/141
;*****************
;digital tone Oscillator
;
; Single tone oscillator without noise shaping (less CPU usage)
;
OCI_OSC1d                           ;   +19
               ldd  osc1_phase      ;+4  23    Phase holen (16 Bit)
               addd osc1_pd         ;+4  27    phasen delta addieren
               std  osc1_phase      ;+4  31    phase speichern

               ldx  #sin_256        ;+3  34    Start der Sinus-outputtabelle holen

               tab                  ;+1  35
               abx                  ;+1  36    Index addieren
               ldaa 0,x             ;+4  40
               ldab Port2_Data      ;+3  43    get noise from Signalling Decode Input
               andb #1              ;+2  45    this is cheaper than generating pseudo-noise
               aba

               tab
               ldx  #dac_out_tab2    ;+3  50    Start der DAC/Portvalue Tabelle holen
               abx                  ;+1  51

               ldaa Port6_DDR_buf   ;+3  54
               ldab Port6_Data      ;+3  57
               andb #%10001111      ;+2  59
               addd 0,x             ;+5  64    ; add DAC value from sine table
               std  Port6_DDR       ;+4  68    ; store to DDR & Data

               ldab TCSR2           ;+3  71    ; Timer Control / Status Register 2 lesen
               ldd  OCR1H           ;+4  75
               addd #249            ;+3  78    ; ca 8000 mal pro sek Int auslösen
               std  OCR1H           ;+4  82

               ldd  osc1_dither     ;+4  86    ; get LFSR
               lslb                 ;+1  87    ; shift LFSR
               rola                 ;+1  88
               bcc  $+4             ;+3  91    ; do nothing if MSB was 0
               eorb #%01010011      ;+2  93    ; calculate Feedback
               std  osc1_dither     ;+4  97/95 ; store LFSR
                                    ;------
               ldaa TCSR2           ;+3  99
               anda #%00100000      ;+2 101
               beq  oos1d_end       ;+3 104
               ldd  OCR2            ;+4 108
               addd #SYSCLK/1000    ;+3 111
               std  OCR2            ;+4 115
               dec  gp_timer        ;+6 121    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4 125
               inx                  ;+1 126    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4 130

oos1d_end
               rti                 ;+10  106 / 140
;********
; N C O
;********
;
;*****************
;digital tone Oscillator
;
; Single tone oscillator for Alert tone (local speaker)
;
OCI_OSC_ALERT                       ;   +19
               ldd  osc1_phase      ;+4  23    Phase holen (16 Bit)
               addd osc1_pd         ;+4  27    phasen delta addieren
               std  osc1_phase      ;+4  31    phase speichern

               ldab PORT_ATONE      ;+3  44
               anda #%00100000      ;+2  33    nur MSB berücksichtigen
               beq  ooa_zero        ;+3
               orab #BIT_ATONE      ;+2  46
               stab PORT_ATONE      ;+4
               jmp  oos1_timer      ;+3
ooa_zero
               andb #~BIT_ATONE     ;+2
               stab PORT_ATONE      ;+4  55    ; store to Port2 Data
               jmp  oos1_timer      ;+3

; CPU load with active NCO
;
; EVA5 / 7977600 Hz Xtal
;     -> 1994400 Hz E2 clock
;     -> 249 * 8000 Hz (NCO clock)       CPU load EVA5 = (1* 56,6 % + 7* 35,3 %) / 8 = 38,0 % average
;                                        (reduces effective CPU speed for program to ~1237 kHz)
;*****************
;digital double tone Oscillator
;
; TODO: Sinn von Dither untersuchen, 16 Bit LFSR (z.B. x^16 + x^12 + x^5 + 1) addieren
;
OCI_OSC2                            ;   +19    Ausgabe Stream1 (Bit 0-2)
               ldd  osc1_phase      ;+4  23    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  27    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  31    ; und neuen Phasenwert 1 speichern
               ldx  #sin_64_3_1dB   ;+3  34    ; Sinustabelle indizieren
               tab                  ;+1  35
               andb #%00111111      ;+2  37
               abx                  ;+1  38

               ldd  osc2_phase      ;+4  42    ; 16 Bit Phase 2 holen
               addd osc2_pd         ;+4  46    ; 16 Bit delta Phase 2 addieren
               std  osc2_phase      ;+4  50    ; neuen Phasenwert 2 speichern
               tab                  ;+1  51
               ldaa 0,x             ;+4  55    ; Tabelleneintrag 1 holen

               ldx  #sin_64_3_0dB   ;+3  58    ; Sinustabelle indizieren
               andb #%00111111      ;+2  60
               abx                  ;+1  61
               adda 0,x             ;+4  65    ; Tabelleneintrag 2 addieren

               tab                  ;+1  66
               andb #%1110          ;+2  68    ; Bits 3-1 filtern
; TODO hier ggf. dither noise einfügen
               ldx  #dac_out_tab2   ;+3  71    ; DAC Werte ausgeben
               abx                  ;+1  72

               ldaa Port6_DDR_buf   ;+3  75
               ldab Port6_Data      ;+3  78
               andb #%10001111      ;+2  82
               addd 0,x             ;+5  87    ; use ADD as OR
               std  Port6_DDR       ;+4  91    ; Store to DDR & Data

               ldab TCSR1           ;+3  94     ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  98
               addd #249            ;+3 101     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4 105

               ldaa TCSR2           ;+3 108
               anda #%00100000      ;+3 111
               beq  oos2_end        ;+3 114
               ldd  OCR2            ;+4 118
               addd #SYSCLK/1000    ;+3 121
               std  OCR2            ;+4 125
               dec  gp_timer        ;+6 131    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4 135
               inx                  ;+1 136    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4 140
oos2_end
               rti                  ;+10 124 / 150
; CPU load with active NCO
;
; EVA5 / 7977600 Hz Xtal
;     -> 1994400 Hz E2 clock
;     -> 249 * 8000 Hz (NCO clock)       CPU load EVA5 = (7* 49,8 % + 1* 60,2 %) / 8 = 51,1 % average
;                                        (reduces effective CPU speed for program to ~975 kHz)
;*****************
;digital dual tone Oscillator using modulation
;(DTMF + CTCSS)
;
OCI_OSC2m                           ;   +19    Ausgabe Stream1 (Bit 0-2)
               ldd  osc2_phase      ;+4  23    ; 16 Bit Phase 2 holen
               addd osc2_pd         ;+4  27    ; 16 Bit delta Phase 2 addieren
               std  osc2_phase      ;+4  31    ; neuen Phasenwert 2 speichern
               anda #%01000000	    ;+2  33    ; isolate MSB (0/180° phase indicator)
               ldx  #dac_sin_tab    ;+3  36    ; Sinustabelle indizieren
               tab                  ;+1  37
               abx                  ;+1  38
               ldd  osc1_phase      ;+4  42    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  46    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  50    ; und neuen Phasenwert 1 speichern
               tab                  ;+1  51
               andb #%01111110      ;+2  53
               abx                  ;+1  54
               ldab Port2_Data
               andb #1
               lslb
               abx
               ldaa Port6_DDR_buf   ;+3  56
               ldab Port6_Data      ;+3  59
               andb #%10001111      ;+2  61
               addd 0,x             ;+5  66    ; add DAC value from sine table
               std  Port6_DDR       ;+4  70    ; store to DDR & Data

               ldab TCSR1           ;+3  73     ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  77
               addd #249            ;+3  80     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4  84

               ldaa TCSR2           ;+3  87
               anda #%00100000      ;+3  90
               beq  oos2m_end       ;+3  93
               ldd  OCR2            ;+4  97
               addd #SYSCLK/1000    ;+3 100
               std  OCR2            ;+4 104
               dec  gp_timer        ;+6 110    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4 114
               inx                  ;+1 115    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4 119
oos2m_end
               rti                  ;+10 103 / 129
; CPU load with active NCO
;
; EVA5 / 7977600 Hz Xtal
;     -> 1994400 Hz E2 clock
;     -> 249 * 8000 Hz (NCO clock)       CPU load EVA5 = (7* 40,6 % + 1* 50,8 %) / 8 = 41,8 % average
;                                        (reduces effective CPU speed for program to ~1160 kHz)
;*****************
;digital double tone Oscillator, Signalling & CTCSS
;
;
OCI_OSC2_sp                         ;   +19
               ldd  osc1_phase      ;+4  23    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  27    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  31    ; und neuen Phasenwert 1 speichern
               ldx  #sin_64_3_1dB   ;+3  34    ; Sinustabelle indizieren
               tab                  ;+1  35
               andb #%00111111      ;+2  37
               abx                  ;+1  38

               ldd  osc3_phase      ;+4  42    ; 16 Bit Phase 2 holen
               addd osc3_pd         ;+4  46    ; 16 Bit delta Phase 2 addieren
               std  osc3_phase      ;+4  50    ; neuen Phasenwert 2 speichern

               ldab 0,x             ;+4  54    ; Tabelleneintrag 1 holen

               anda #%11000000      ;+2  56    ; filter topmost bits, 01 = sub 1 from B, 11 = add 1 to B
               rola                 ;+1  57
               rola                 ;+1  58    ; keep sign as Bit 0 and value in carry flag
               beq  oo2sp_add       ;+3  61    ; decide if to perform addition or subtraction
               adcb #0              ;+2  63    ; add 0 and carry
               bra  oo2sp_da        ;+3  66    ; continue with indexing DAC table
oo2sp_add
               sbcb #0              ;+2  63    ; subtract 0 and carry
               bra  oo2sp_da        ;+3  66    ; continue with indexing DAC table
oo2sp_da
               lslb                 ;+1  67    ; table has 16 bit values, adjust index
               ldx  #dac_out_tab2   ;+3  70    ; get DAC table base
               abx                  ;+1  71    ; add index

               ldaa Port6_DDR_buf   ;+3  74
               ldab Port6_Data      ;+3  77
               andb #%10001111      ;+2  79
               addd 0,x             ;+5  84    ; use ADD as OR
               std  Port6_DDR       ;+4  88    ; Store to DDR & Data

               ldab TCSR1           ;+3  91     ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  95
               addd #249            ;+3  98     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4 102

               ldaa TCSR2           ;+3 105
               anda #%00100000      ;+3 108
               beq  oo2sp_end       ;+3 111
               ldd  OCR2            ;+4 115
               addd #SYSCLK/1000    ;+3 118
               std  OCR2            ;+4 122
               dec  gp_timer        ;+6 128    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4 132
               inx                  ;+1 133    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4 137
oo2sp_end
               rti                  ;+10 121 / 147
; CPU load with active NCO
;
; EVA5 / 7977600 Hz Xtal
;     -> 1994400 Hz E2 clock
;     -> 249 * 8000 Hz (NCO clock)       CPU load EVA5 = (7* 40,6 % + 1* 50,8 %) / 8 = 41,8 % average
;                                        (reduces effective CPU speed for program to ~1160 kHz)
;*****************
;
; digital triple tone Oscillator
; DTMF + CTCSS
;
OCI_OSC3                            ;   +19
               ldd  osc1_phase      ;+4  23    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  27    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  31    ; und neuen Phasenwert 1 speichern
               ldx  #sin_64_3_1dB   ;+3  34    ; Sinustabelle indizieren
               tab                  ;+1  35
               andb #%00111111      ;+2  37
               abx                  ;+1  38

               ldd  osc2_phase      ;+4  42    ; 16 Bit Phase 2 holen
               addd osc2_pd         ;+4  46    ; 16 Bit delta Phase 2 addieren
               std  osc2_phase      ;+4  50    ; neuen Phasenwert 2 speichern
               tab                  ;+1  51
               ldaa 0,x             ;+4  55    ; Tabelleneintrag 1 holen

               ldx  #sin_64_3_1dB   ;+3  58    ; Sinustabelle indizieren
               andb #%00111111      ;+2  60
               abx                  ;+1  61
               adda 0,x             ;+4  65    ; Tabelleneintrag 2 addieren
               tab                  ;+1  66
               andb #%1110          ;+2  68    ; Bits 3-1 filtern
               ldx  #dac_out_tab3   ;+3  71    ; DAC Werte ausgeben
               abx                  ;+1  72

               ldd  osc3_phase      ;+4  76
               addd osc3_pd         ;+4  80
               std  osc3_phase      ;+4  84
               clrb                 ;+1  85
               lsla                 ;+1  86
               rolb                 ;+1  87
               rolb                 ;+1  88
               abx                  ;+1  89

               ldaa Port6_DDR_buf   ;+3  92
               ldab Port6_Data      ;+3  95
               andb #%10001111      ;+2  97
               addd 0,x             ;+5 102    ; use ADD as OR
               std  Port6_DDR       ;+4 106    ; Store to DDR & Data

               ldab TCSR1           ;+3 109     ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4 113
               addd #249            ;+3 116     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4 120

               ldaa TCSR2           ;+3 123
               anda #%00100000      ;+3 126
               beq  oos3_end        ;+3 129
               ldd  OCR2            ;+4 133
               addd #SYSCLK/1000    ;+3 136
               std  OCR2            ;+4 140
               dec  gp_timer        ;+6 146    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4 150
               inx                  ;+1 151    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4 155
oos3_end
               rti                  ;+10 139 / 165
; CPU load with active NCO
;
; EVA5 / 7977600 Hz Xtal
;     -> 1994400 Hz E2 clock
;     -> 249 * 8000 Hz (NCO clock)       CPU load EVA5 = (7* 54,7 % + 1* 65,0 %) / 8 = 56,0 % average
;                                        (reduces effective CPU speed for program to ~878 kHz)


