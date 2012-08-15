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
; EVA9 has 2 DACs, so we need two routines, one for each one of them
;
OCI_OSC1_sig                        ;   +19
               ldd  osc1_phase      ;+4  23    Phase holen (16 Bit)
               addd osc1_pd         ;+4  27    phasen delta addieren
               std  osc1_phase      ;+4  31    phase speichern
               ldx  #sin_tab4       ;+3  34    Start der Sinus-outputtabelle holen
               tab                  ;+1  35
               abx                  ;+1  36    Index addieren
               ldab Port6_Data      ;+3  39
               andb #%11110000      ;+2  41
               orab 0,x             ;+4  45    Sinus-Ausgabewert holen
               stab Port6_Data      ;+3  48
               ldab TCSR2           ;+3  51    ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  55
               addd #154            ;+3  58    ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4  62
               rol  oci_int_ctr     ;+6  68    ; Interrupt counter lesen
               bcc  oos1_end        ;+3  71    ; wenn Ergebnis <> 0, dann Ende
                                               ; shorted OCI_MAIN routine (dont do preemptive task switching)
               ldab #1              ;+2  73
               stab oci_int_ctr     ;+3  90    ; update counters again in 8 interrupts
               dec  gp_timer        ;+6  78    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4  82
               inx                  ;+1  83    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  87
oos1_end
               rti                 ;+10  100 / 81
; EVA9 / 4924600 Hz Xtal
;     -> 1231150 Hz E2 clock
;     -> (ca.) 154 * 8000 Hz (NCO clock)  CPU load EVA9 = (1* 64,9 % + 7* 52,6 %) / 8 = 54,1 % average
;                                         (reduces effective CPU speed for program to ~565 kHz)

OCI_OSC1_pl                         ;   +19
               ldd  osc3_phase      ;+4  23    Phase holen (16 Bit)
               addd osc3_pd         ;+4  27    phasen delta addieren
               std  osc3_phase      ;+4  31    phase speichern

               ldx  #sin_256_3_0dB_pl;+3 34    Start der Sinus-outputtabelle holen
               tab                  ;+1  35
               abx                  ;+1  36    Index addieren
               ldab Port6_Data      ;+3  39
               andb #%10001111      ;+2  41
               orab 0,x             ;+4  45    Sinus-Ausgabewert holen
               stab Port6_Data      ;+3  48
               ldab TCSR2           ;+3  51    ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  55
               addd #154            ;+3  58    ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4  62
               rol  oci_int_ctr     ;+6  68    ; Interrupt counter lesen
               bcc  oos1p_end       ;+3  71    ; wenn Ergebnis <> 0, dann Ende
                                               ; shorted OCI_MAIN routine (dont do preemptive task switching)
               ldab #1              ;+1  72
               dec  gp_timer        ;+6  78    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4  82
               inx                  ;+1  83    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  87
               stab oci_int_ctr     ;+3  90    ; update counters again in 8 interrupts
oos1p_end
               rti                 ;+10  100 / 81
; EVA9 / 4924600 Hz Xtal
;     -> 1231150 Hz E2 clock
;     -> (ca.) 154 * 8000 Hz (NCO clock)  CPU load EVA9 = (1* 65,6 % + 7* 52,6 %) / 8 = 54,2 % average
;                                         (reduces effective CPU speed for program to ~564 kHz)

;*****************
;digital tone Oscillator
;
; Single tone oscillator for Alert tone (local speaker)
;
OCI_OSC_ALERT                       ;   +19
               ldd  osc1_phase      ;+4  23    Phase holen (16 Bit)
               addd osc1_pd         ;+4  27    phasen delta addieren
               std  osc1_phase      ;+4  31    phase speichern

               anda #%00100000      ;+2  33    nur MSB berücksichtigen
               lsra                 ;+1  34
               lsra                 ;+1  35
               tab

               ldaa Port5_Data      ;+3  44
               anda #%11110111      ;+2  46
               aba
               staa Port5_Data      ;+4  55    ; store to Port5 Data

               ldab TCSR2           ;+3  51    ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  55
               addd #154            ;+3  58    ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4  62
               rol  oci_int_ctr     ;+6  68    ; Interrupt counter lesen
               bcc  oos1a_end       ;+3  71    ; wenn Ergebnis <> 0, dann Ende
                                               ; shorted OCI_MAIN routine (dont do preemptive task switching)
               rolb                 ;+1  72
               dec  gp_timer        ;+6  78    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4  82
               inx                  ;+1  83    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  87
               stab oci_int_ctr     ;+3  90    ; update counters again in 8 interrupts
oos1a_end
               rti                 ;+10  100 / 81

; CPU load with active NCO
;
; EVA9 / 4924600 Hz Xtal
;     -> 1231150 Hz E2 clock
;     -> 154 * 8000 Hz (NCO clock)       CPU load EVA9 = (1* 56,6 % + 7* 35,3 %) / 8 = 38,0 % average
;                                        (reduces effective CPU speed for program to ~1237 kHz)
;*****************
;digital double tone Oscillator
;
OCI_OSC2                            ;   +19    Ausgabe Stream1 (Bit 0-2)
               ldd  osc1_phase      ;+4  23    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  27    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  31    ; und neuen Phasenwert 1 speichern
               ldx  #sin_tab_lo     ;+3  34    ; Sinustabelle indizieren
               tab                  ;+1  35
               abx                  ;+1  36

               ldd  osc2_phase      ;+4  40    ; 16 Bit Phase 2 holen
               addd osc2_pd         ;+4  44    ; 16 Bit delta Phase 2 addieren
               std  osc2_phase      ;+4  48    ; neuen Phasenwert 2 speichern
               tab                  ;+1  49
               ldaa 0,x             ;+4  53    ; Tabelleneintrag 1 holen
               ldx  #sin_tab_hi     ;+3  56    ; Sinustabelle (Wertebereich 0-7)
               abx                  ;+1  57
               ldab 0,x             ;+4  61    ; Tabelleneintrag 2 holen
               aba                  ;+1  62    ; Tabelleneintrag 1 addieren

               ldab Port6_Data      ;+3  65
               andb #%11110000      ;+2  67
               aba                  ;+4  71    ; combine with DAC value
               staa Port6_Data      ;+3  74    ; Store to DAC reg

               ldab TCSR2           ;+3  77    ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  81
               addd #154            ;+3  84     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4  88

               rol  oci_int_ctr     ;+6  94
               bne  oos2_end        ;+3  97
               rolb                 ;+1  98
               dec  gp_timer        ;+6 104    ; Universaltimer-- / HW Task
; Basis Tick Counter
               ldx  tick_ms         ;+4 108
               inx                  ;+1 109    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4 113
               stab oci_int_ctr     ;+3 116
oos2_end
               rti                  ;+10 107 / 126
; CPU load with active NCO
;
; EVA9 / 4924600 Hz Xtal
;     -> 1231150 Hz E2 clock
;     -> 154 * 8000 Hz (NCO clock)       CPU load EVA9 = (1* 81,8 % + 7* 69,5 %) / 8 = 78,8 % average
;                                        (reduces effective CPU speed for program to ~260 kHz)
;--------------
; 1 tone signal DAC,
; 1 tone pl DAC
OCI_OSC2_sp                         ;   +19    Ausgabe Stream1 (Bit 0-2)
               ldd  osc1_phase      ;+4  23    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  27    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  31    ; und neuen Phasenwert 1 speichern
               ldx  #sin_tab4       ;+3 34    ; Sinustabelle indizieren
               tab                  ;+1  37
               abx                  ;+1  38

               ldd  osc3_phase      ;+4  42    ; 16 Bit Phase 1 holen
               addd osc3_pd         ;+4  46    ; 16 Bit delta phase 1 addieren
               std  osc3_phase      ;+4  50    ; und neuen Phasenwert 1 speichern
               tab
               ldaa 0,x             ;+4  54    ; Tabelleneintrag 1 holen
               ldx  #sin_256_3_0dB_pl
               abx
               oraa 0,x             ;+4  58    ; combine results to new DAC1 & DAC2 output
               staa Port6_Data      ;+3  61    ; Store to DAC reg, remember to keep Bit 7 = 0 (PLL Syn Latch)

               ldab TCSR2           ;+3  64    ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  68
               addd #154            ;+3  71     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4  75

               rol  oci_int_ctr     ;+6  81
               bne  oos2pl_end      ;+3  84
               rolb                 ;+1  85
               dec  gp_timer        ;+6  91    ; Universaltimer-- / HW Task
; Basis Tick Counter
               ldx  tick_ms         ;+4  95
               inx                  ;+1  96    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4 100
               stab oci_int_ctr     ;+3 103
oos2pl_end
               rti                  ;+10  94 / 114
; CPU load with active NCO
;
; EVA9 / 4924600 Hz Xtal
;     -> 1231150 Hz E2 clock
;     -> 154 * 8000 Hz (NCO clock)       CPU load EVA9 = (1* 74,0 % + 7* 61,0 %) / 8 = 62,6 % average
;                                        (reduces effective CPU speed for program to ~460 kHz)
;--------------

;*****************
;digital triple tone Oscillator
;
OCI_OSC3                            ;   +19
               ldd  osc1_phase      ;+4  23    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  27    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  31    ; und neuen Phasenwert 1 speichern
               ldx  #sin_tab_lo     ;+3  34    ; Sinustabelle indizieren
               tab                  ;+1  35
               abx                  ;+1  36

               ldd  osc2_phase      ;+4  40    ; 16 Bit Phase 2 holen
               addd osc2_pd         ;+4  44    ; 16 Bit delta Phase 2 addieren
               std  osc2_phase      ;+4  48    ; neuen Phasenwert 2 speichern
               tab                  ;+1  49

               ldaa 0,x             ;+4  53    ; Tabelleneintrag 1 holen
               ldx  #sin_tab_hi     ;+3  56    ; Sinustabelle (Wertebereich 0-7)
               abx                  ;+1  57
               ldab 0,x             ;+4  61    ; Tabelleneintrag 2 holen

               aba                  ;+1  62    ; Tabelleneintrag 1 addieren
                                    ;-------
               anda #%00011110      ;+2  64    ; filter relevant bits
               xgdx                 ;+2  66    ; save result to X
               ldd  osc3_phase      ;+4  70    ; 16 Bit Phase 3 holen
               addd osc3_pd         ;+4  74    ; 16 Bit delta Phase 3 addieren
               std  osc3_phase      ;+4  78    ; neuen Phasenwert 3 speichern
               tab                  ;+1  79    ;
               clra                 ;+1  80
               addd #sin_256_3_0dB_pl;+3 83    ; build index for Sine tab (value already shifted to Bit 5-7)
               xgdx                 ;+2  85    ; transfer to index reg and get previous result back to A
               oraa 0,x             ;+4  89    ; combine results to new DAC1 & DAC2 output
               staa Port6_Data      ;+3  92    ; Store to DAC reg, remember to keep Bit 0 = 0 (PLL Syn Latch)

               ldab TCSR2           ;+3  95    ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  99
               addd #154            ;+3 102     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4 106
               rol  oci_int_ctr     ;+6   6
               bne  oos3_end        ;+3   9
               dec  gp_timer        ;+6  15    ; Universaltimer-- / HW Task
; Basis Tick Counter
               ldx  tick_ms         ;+4  19
               inx                  ;+1  20    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  24
               ldab #1              ;+2  26
               stab oci_int_ctr     ;+3  29
oos3_end
               rti                  ;+10 19 / 39
                                    ;------------
                             ; EVA5 133     + 19/39 = 152 / 172
                             ; EVA9 106     + 19/39 = 125 / 145
; CPU load with active NCO
;
;
; EVA9 / 4924600 Hz Xtal
;     -> 1231150 Hz E2 clock
;     -> 154 * 8000 Hz (NCO clock)       CPU load EVA9 = (1* 94,1 % + 7* 81,2 %) / 8 = 82,8 % average
;                                        (reduces effective CPU speed for program to ~212 kHz)

