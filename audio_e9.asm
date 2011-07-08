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
               anda #%00111111      ;+2  33    64 Byte sin table, stay within limits
               ldx  #sin_64_4_0dB_sig;+3 36    Start der Sinus-outputtabelle holen
               tab                  ;+1  37
               abx                  ;+1  38    Index addieren
               ldab Port6_Data      ;+3  41
               andb #%11100001      ;+2  43
               orab 0,x             ;+4  47    Sinus-Ausgabewert holen
               stab Port6_Data      ;+3  50
               ldab TCSR2           ;+3  53    ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  57
               addd #154            ;+3  60    ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4  64
               rol  oci_int_ctr     ;+6  70    ; Interrupt counter lesen
               bcc  oos1_end        ;+3  73    ; wenn Ergebnis <> 0, dann Ende
                                               ; shorted OCI_MAIN routine (dont do preemptive task switching)
               dec  gp_timer        ;+6  79    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4  83
               inx                  ;+1  84    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  88
               ldab #1              ;+2  90
               stab oci_int_ctr     ;+3  93    ; update counters again in 8 interrupts
oos1_end
               rti                 ;+10  103 / 83
; EVA9 / 4924600 Hz Xtal
;     -> 1231150 Hz E2 clock
;     -> (ca.) 154 * 8000 Hz (NCO clock)  CPU load EVA9 = (1* 66,9 % + 7* 53,9 %) / 8 = 55,5 % average
;                                         (reduces effective CPU speed for program to ~548 kHz)

OCI_OSC1_pl                         ;   +19
               ldd  osc3_phase      ;+4  23    Phase holen (16 Bit)
               addd osc3_pd         ;+4  27    phasen delta addieren
               std  osc3_phase      ;+4  31    phase speichern

               ldx  #sin_256_3_0dB_pl;+3 34    Start der Sinus-outputtabelle holen
               tab                  ;+1  35
               abx                  ;+1  36    Index addieren
               ldab Port6_Data      ;+3  39
               andb #%00011111      ;+2  41
               orab 0,x             ;+4  45    Sinus-Ausgabewert holen
               stab Port6_Data      ;+3  48
               ldab TCSR2           ;+3  51    ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  55
               addd #154            ;+3  58    ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4  62
               rol  oci_int_ctr     ;+6  68    ; Interrupt counter lesen
               bcc  oos1p_end       ;+3  71    ; wenn Ergebnis <> 0, dann Ende
                                               ; shorted OCI_MAIN routine (dont do preemptive task switching)
               dec  gp_timer        ;+6  77    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4  81
               inx                  ;+1  82    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  86
               ldab #1              ;+2  88
               stab oci_int_ctr     ;+3  91    ; update counters again in 8 interrupts
oos1p_end
               rti                 ;+10  101 / 81
; EVA9 / 4924600 Hz Xtal
;     -> 1231150 Hz E2 clock
;     -> (ca.) 154 * 8000 Hz (NCO clock)  CPU load EVA9 = (1* 65,6 % + 7* 52,6 %) / 8 = 54,2 % average
;                                         (reduces effective CPU speed for program to ~564 kHz)

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
               anda #%00011110      ;+2   2    ; filter relevant bits
               tab
               ldx  #sin_tab16      ;+3  20    ; build index for Sine tab (value already shifted to Bit 5-7)
               xgdx                 ;+2  22    ; transfer to index reg and get previous result back to A
               oraa 0,x             ;+4  26    ; combine results to new DAC1 & DAC2 output
               staa Port6_Data      ;+3  29    ; Store to DAC reg, remember to keep Bit 0 = 0 (PLL Syn Latch)

               ldab TCSR2           ;+3  32    ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  36
               addd #154            ;+3  39     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4  43

               rol  oci_int_ctr     ;+6 106
               bne  oos2_end        ;+3 109
               dec  gp_timer        ;+6 115    ; Universaltimer-- / HW Task
; Basis Tick Counter
               ldx  tick_ms         ;+4 119
               inx                  ;+1 120    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4 124
               ldab #1              ;+2 126
               stab oci_int_ctr     ;+3 129
oos2_end
               rti                  ;+10 119 / 139
; CPU load with active NCO
;
; EVA9 / 4924600 Hz Xtal
;     -> 1231150 Hz E2 clock
;     -> 154 * 8000 Hz (NCO clock)       CPU load EVA9 = (1* 90,2 % + 7* 77,3 %) / 8 = 78,9 % average
;                                        (reduces effective CPU speed for program to ~260 kHz)
;--------------
; 1 tone signal DAC,
; 1 tone pl DAC
OCI_OSC2_sp                         ;   +19    Ausgabe Stream1 (Bit 0-2)
               ldd  osc1_phase      ;+4  23    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  27    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  31    ; und neuen Phasenwert 1 speichern
               ldx  #sin_64_4_0dB_sig;+3 34    ; Sinustabelle indizieren
               anda #%00111111      ;+2  36    ; filter relevant bits
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
               staa Port6_Data      ;+3  61    ; Store to DAC reg, remember to keep Bit 0 = 0 (PLL Syn Latch)

               ldab TCSR2           ;+3  64    ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  68
               addd #154            ;+3  71     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4  75

               rol  oci_int_ctr     ;+6  81
               bne  oos2pl_end      ;+3  84
               dec  gp_timer        ;+6  90    ; Universaltimer-- / HW Task
; Basis Tick Counter
               ldx  tick_ms         ;+4  94
               inx                  ;+1  95    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  99
               ldab #1              ;+2 101
               stab oci_int_ctr     ;+3 104
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

