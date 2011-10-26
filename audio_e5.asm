
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
OCI_OSC1                            ;   +19
               ldd  osc1_phase      ;+4  23    Phase holen (16 Bit)
               addd osc1_pd         ;+4  27    phasen delta addieren
               std  osc1_phase      ;+4  31    phase speichern

               anda #%00111111      ;+2  33    nur Bits 0-5 berücksichtigen (0-63)
               ldx  #dac_sin_tab    ;+3  36    Start der Sinus-outputtabelle holen

               tab                  ;+1  37
               lslb                 ;+1  38
               abx                  ;+1  38    Index addieren
               ldaa Port6_DDR_buf   ;+3  41
               ldab Port6_Data      ;+3  44
               andb #%10011111      ;+2  46
               addd 0,x             ;+5  51    ; add DAC value from sine table
               std  Port6_DDR       ;+4  55    ; store to DDR & Data

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

               ldx  #sin_64_3_1dB   ;+3  58    ; Sinustabelle indizieren
               andb #%00111111      ;+2  60
               abx                  ;+1  61
               adda 0,x             ;+4  65    ; Tabelleneintrag 2 addieren

               andb #%1110          ;+2  69    ; Bits 3-1 filtern
; TODO hier ggf. dither noise einfügen
               ldx  #dac_out_tab    ;+3  72    ; DAC Werte ausgeben
               abx                  ;+1  73

               ldaa Port6_DDR_buf   ;+3  76
               ldab Port6_Data      ;+3  79
               andb #%10011111      ;+2  81
               addd 0,x             ;+5  86    ; use ADD as OR
               std  Port6_DDR       ;+4  90    ; Store to DDR & Data

               ldab TCSR1           ;+3  93     ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  97
               addd #249            ;+3 100     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4 104

               ldaa TCSR2
               anda #%00100000
               beq  oos2_end
               ldd  OCR2
               addd #SYSCLK/1000
               std  OCR2
               dec  gp_timer        ;+6  77    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4  81
               inx                  ;+1  82    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  86
oos2_end
               rti                  ;+10 119 / 143/156/172
; CPU load with active NCO
;
; EVA5 / 7977600 Hz Xtal
;     -> 1994400 Hz E2 clock
;     -> 249 * 8000 Hz (NCO clock)       CPU load EVA5 = (1* 69,1 % + 7* 47,8 %) / 8 = 50,5 % average
;                                        (reduces effective CPU speed for program to ~988 kHz)


