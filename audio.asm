;****************************************************************************
;
;    MC 70    v2.0.0 - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2008  Felix Erckenbrecht, DG1YFE
;
;
;****************************************************************************
;**********************
; T O N E   S T A R T
;**********************
;
; Startet Ton Oszillator
;
; Parameter : D - Tonfrequenz in Hz
;
;
; delta phase = f / 8000 * 64 * 256
; wegen Integer rechnung:
; dp = f*256*64 / 8000
; einfacher (da *65536 einem Shift um 2 ganze Bytes entspricht)
; dp = f*256*64*4 / (8000*4)
; dp = f*  65536  /  32000
;
; Frequenzabweichung maximal 8000 / (64 (Schritte in Sinus Tabelle) * 256 (8 Bit 'hinterm Komma')
; = 0,488 Hz
;
tone_start
               pshb
               psha
               pshx

               ldx  #0
;               stx  osc1_phase        ; Phase startet bei 0
               pshx                   ; Lo Word = 0
               pshb                   ; Hi Word sichern
               psha                   ; => f*65536 auf Stack speichern

;               ldd  #32000            ; Divisor  = Samplefrequenz * 4
               ldd  #48000            ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus
               std  osc1_pd           ; Quotient = delta für phase

               ldab Port6_DDR_buf
               andb #%10011111
               stab Port6_DDR_buf
               stab Port6_DDR

               ldab #1
               stab tasksw_en         ; disable preemptive task switching
               sei
               ldab tick_ms+1
tos_intloop
               cli
               nop                    ; don't remove these NOPs
               nop                    ; HD6303 needs at least 2 clock cycles between cli & sei
               sei                    ; otherwise interrupts aren't processed
               cmpb tick_ms+1
               beq  tos_intloop
               ldab #1
               stab oci_int_ctr       ; Interrupt counter auf 1
                                      ; (Bit is left shifted during Audio OCI, on zero 1ms OCI will be executed)
               ldab TCSR2
               ldd  OCR1
               std  OCR2
               subd #SYSCLK/1000
               addd #499              ; add two sample periods to ensure there is enough time
                                      ; before next interrupt occurs even on EVA9
               std  OCR1

               ldx  #OCI_OSC1
               stx  oci_vec           ; OCI Interrupt Vektor 'verbiegen'
                                      ; Ausgabe startet automatisch beim nächsten OCI
                                      ; 1/8000 s Zeitintervall wird automatisch gesetzt
;               clr  tasksw_en         ; re-enable preemptive task switching
               ldab #1
               stab osc3_phase
               ldd  #dac_sin_tab
               std  osc3_pd
               cli
               pulx
               pula
               pulb
               rts

;**********************
; D T O N E   S T A R T
;**********************
;
; Startet Dual-Ton Oszillator
;
; Parameter : D - Tonfrequenz 1 in Hz
;             X - Tonfrequenz 2 in Hz
;
;
dtone_start
               pshb
               psha
               pshx

               ldx  #0
;               stx  osc1_phase
;               stx  osc2_phase        ; Phase startet bei 0
               pshx                   ; Lo Word = 0
               pshb                   ; Hi Word Freq Y auf Stack
               psha                   ; => f*65536 auf Stack speichern

               ldd  #44000            ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus
               std  osc1_pd           ; Quotient = delta für phase

               ldx  #0
               pshx
               tsx
               ldx  2,x               ; Tonfrequenz 2/X holen
               pshx                   ; und auf Stack legen
               ldd  #40000            ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus
               subd #31
               std  osc2_pd           ; Quotient = delta für phase

               clr  oci_int_ctr       ; Interrupt counter auf 0
                                      ; (wird jeweils um 32 erhöht, bei 0 wird normaler Timer Int ausgeführt)
               ldd  #1
               std  osc3_phase
               clrb
               stab o2_en1
               stab o2_en2
               stab o2_en_

               ldx  #OCI_OSC2ns
               stx  oci_vec           ; OCI Interrupt Vektor 'verbiegen'
                                      ; Ausgabe startet automatisch beim nächsten OCI
                                      ; 1/8000 s Zeitintervall wird automatisch gesetzt
               ldab #1
               stab Port7_Data

               pulx
               pula
               pulb
               rts
;**********************
; T O N E   S T O P
;**********************
;
; Stoppt Ton Oszillator
;
tone_stop
               pshb
               psha
               pshx
               ldx  #OCI1_MS
               stx  oci_vec            ; OCI wieder auf Timer Interrupt zurücksetzen
                                       ; Zeitbasis für Timerinterrupt (1/1000 s) wird im Int zurückgestellt
                                       ; DAC wieder auf Mittelwert zurücksetzen
               ldab Port6_DDR_buf
               andb #%10011111
               stab Port6_DDR
               stab Port6_DDR_buf

               ldaa Port6_Data
               anda #%10011111
               staa Port6_Data

               pulx
               pula
               pulb
               rts

; 
; **********************
; D A   S T A R T
; **********************
; 
; Startet Ausgabe eines Samples
; 
; Parameter : Stack - Start Adresse
;             Stack - End Adresse
;             X     - Repeat Count
;             A     - Spur/Track (0/1/2)
; 
; Ergebnis : None
; 
; changed Regs : None
; 
; da_start
;                 pshb
;                 psha
;                 pshx
; 
;                 tsx
;                 ldd  6,x
;                 std  smp_start
;                 std  smp_addr
;                 ldd  8,x
;                 std  smp_end
; 
;                 pulx
;                 pshx
;                 std  smp_rpt
; 
;                 tsx
;                 ldaa 2,x
;                 beq  das_play_zero
;                 deca
;                 beq  das_play_one
;                 ldx  #OCI_DAC_S2
;                 stx  oci_vec
;                 bra  das_end
; das_play_zero
;                 ldx  #OCI_DAC_S0
;                 stx  oci_vec
;                 bra  das_end
; das_play_one
;                 ldx  #OCI_DAC_S1
;                 stx  oci_vec
; das_end
;                 pulx
;                 pula
;                 pulb
;                 rts
; 
; ********************
; D A   S T O P
; ********************
; 
; 
; 
; da_stop
;                 sei
;                 ldx  smp_end
;                 stx  smp_addr
; 
;                 addd #1194                 ; in einer ms wieder OCI ausführen
;                 std  OCR1
;                 oim  #%00001000, TCSR1     ; Timer compare Interrupt aktivieren
;                 aim  #%10011111, Port6_Data; Pin auf 0 setzen
;                 rts
;**************************
; D T M F  K E Y 2 F R E Q
;**************************
;
;
; Parameter : B - Tastencode oder hexadezimaler Wert ($E=*, $F=#)
;
; Ergebnis :  X - Frequenz 1
;             D - Frequenz 2
;
; changed Regs : X, D
;
dtmf_key2freq
               ldx  #dtmf_ind_tab              ; Taste 0-9
               lslb
               abx
               ldd  0,x                        ; DTMF Index Tabelle indizieren
               lsld                            ; *2
               psha                            ; Y Index auf Stack
               ldx  #dtmf_tab_x
               abx                             ; X Tabelle indizieren
               ldx  0,x                        ; Frequenz auslesen
               pulb                            ; Y Index holen
               pshx                            ; X Frequenz auf Stack
               ldx  #dtmf_tab_y
               abx                             ; Y Tabelle indizieren
               ldd  0,x                        ; Y Frequenz auslesen
               pulx                            ; X Frequenz wiederholen
               rts

; DTMF Frequenztabelle
;
;     1209  1336  1477  1633
;
; 697   1     2     3     A
;
; 770   4     5     6     B
;
; 852   7     8     9     C
;
; 941   *     0     #     D
;
;
dtmf_ind_tab   ;      0     1    2      3     4     5    6     7     8     9
               .dw $0301,$0000,$0001,$0002,$0100,$0101,$0102,$0200,$0201,$0202
               ;      A     B    C      D     *    #     *
               .dw $0003,$0103,$0203,$0303,$0300,$0302,$0300
               ;    D1    D2    D3/D  D4/C  D5    D6    D7/A  D8/B   #
               .dw $0000,$0000,$0303,$0203,$0000,$0000,$0003,$0103,$0302
dtmf_tab_x
               .dw 1209,1336,1477,1633
dtmf_tab_y
               .dw  697, 770, 852, 941
;****************
; x^8 + x^4 + x^3 + x^2 + 1
dither_loop
               ldab oci_int_ctr        ; +3
               rolb                    ; +1
               bcc  dither_end         ; +3
               eorb #%00011101         ; +2
dither_end
               stab oci_int_ctr        ; +3
               rts

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
#ifdef EVA9
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

#else
OCI_OSC1                            ;   +19
               ldd  osc1_phase      ;+4  23    Phase holen (16 Bit)
               addd osc1_pd         ;+4  27    phasen delta addieren
               std  osc1_phase      ;+4  31    phase speichern

               anda #%00111111      ;+2  33    nur Bits 0-5 berücksichtigen (0-63)
               ldx  #dac_sin_tab    ;+3  36    Start der Sinus-outputtabelle holen
               ldx  osc3_pd         ;+3  36    Start der Sinus-outputtabelle holen

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
;               addd #166            ;+3  65    ; ca 8000 mal pro sek Int auslösen
               std  OCR1H           ;+4  69

;               rol  oci_int_ctr     ;+6  75     ; Interrupt counter lesen
;               bcc  oos1_end        ;+3  78     ; wenn Ergebnis <> 0, dann Ende
;               ldab #1
;               stab oci_int_ctr
;               jmp  OCI_MAIN        ;+3  81     ; bei 0 (jeden 8. Int) den Timer Int aufrufen

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
               ldd  osc3_phase         ; +3
               rolb                    ; +1
               rola
               bcc  oos1_dither_end    ; +3
               eora #%00010000         ; +2
               eorb #%00100001         ; +2
oos1_dither_end
               std  osc3_phase         ; +3
               andb #6
               ldx  #dac_sin_tab_sel
               abx
               ldx  0,x
               stx  osc3_pd
               rti                 ;+10  88 / 112/125/141

dac_sin_tab_sel
                .dw dac_sin_tab3
                .dw dac_sin_tab3
                .dw dac_sin_tab4
                .dw dac_sin_tab4

; CPU load with active NCO
;
; EVA5 / 7977600 Hz Xtal
;     -> 1994400 Hz E2 clock
;     -> 249 * 8000 Hz (NCO clock)       CPU load EVA5 = (1* 56,6 % + 7* 35,3 %) / 8 = 38,0 % average
;                                        (reduces effective CPU speed for program to ~1237 kHz)
#endif
;*****************
;digital double tone Oscillator
;
#ifdef EVA9
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
#else
;
; TODO: Sinn von Dither untersuchen, 16 Bit LFSR (z.B. x^16 + x^12 + x^5 + 1) addieren
;
OCI_OSC2                            ;   +19    Ausgabe Stream1 (Bit 0-2)
               ldd  osc1_phase      ;+4  23    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  27    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  31    ; und neuen Phasenwert 1 speichern
;               ldx  #sin_64_3_1dB   ;+3  34    ; Sinustabelle indizieren
               ldx  #dac_sin256     ;+3  34    ; Sinustabelle indizieren
               tab                  ;+1  35
;               andb #%00111111      ;+2  37
               abx                  ;+1  38

               ldd  osc2_phase      ;+4  42    ; 16 Bit Phase 2 holen
;               addd osc2_pd         ;+4  46    ; 16 Bit delta Phase 2 addieren
               addd #1
               anda #%00001111
               std  osc2_phase      ;+4  50    ; neuen Phasenwert 2 speichern
               addd #noise
;               tab                  ;+1  51
               ldx  0,x             ;+4  55    ; Tabelleneintrag 1 holen
               xgdx
;               ldx  #dac_sin256n     ;+3  58    ; Sinustabelle (Wertebereich 0-7)
;               andb #%00111111      ;+2  60
;               abx                  ;+1  61
               adda 0,x             ;+4  65    ; Tabelleneintrag 2 holen
;               aba                  ;+1  66    ; Tabelleneintrag 1 addieren
               lsra
               lsla
;               ldab osc3_phase
;               andb #1
;               aba
               ldx  #dac_8to3
               tab
               abx
; TODO hier ggf. dither noise einfügen
;               anda #%11110         ;+2  68    ; Bits 3-1 filtern
;               ldx  #dac_out_tab    ;+3  71    ; DAC Werte ausgeben
;               tab                  ;+1  72
;               abx                  ;+1  73    ; Table entry address in X

               ldaa Port6_DDR_buf   ;+3  76
               ldab Port6_Data      ;+3  79
               andb #%10011111      ;+2  81
               addd 0,x             ;+5  86    ; use ADD as OR
               std  Port6_DDR       ;+4  90    ; Store to DDR & Data

               ldab TCSR1           ;+3  93     ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  97
               addd #166            ;+3 100     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4 104
               rol  oci_int_ctr     ;+6 106
               bne  oos2_end        ;+3 109
               ldab #1              ;+2 101
               stab oci_int_ctr     ;+3 104
               dec  gp_timer        ;+6  77    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4  81
               inx                  ;+1  82    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  86
oos2_end
               ldd  osc3_phase         ; +3
               rolb                    ; +1
               rola
               bcc  oos2_dither_end    ; +3
               eora #%00010000         ; +2
               eorb #%00100001         ; +2
oos2_dither_end
               std  osc3_phase         ; +3
               andb #63
               clra
               std  osc3_pd

               rti                  ;+10 119 / 143/156/172
; CPU load with active NCO
;
; EVA5 / 7977600 Hz Xtal
;     -> 1994400 Hz E2 clock
;     -> 249 * 8000 Hz (NCO clock)       CPU load EVA5 = (1* 69,1 % + 7* 47,8 %) / 8 = 50,5 % average
;                                        (reduces effective CPU speed for program to ~988 kHz)

OCI_OSC2ns                          ;   +19    Ausgabe Stream1 (Bit 0-2)
               ldd  osc1_phase      ;+4  23    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  27    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  31    ; und neuen Phasenwert 1 speichern
;               ldx  #dac_sin256_12dB     ;+3  34    ; Sinustabelle indizieren
               ldx  #dac_sin256     ;+3  34    ; Sinustabelle indizieren
               tab                  ;+1  35
               abx                  ;+1  36
;               clrb
               ldab 0,x             ;+4  40    ; DAC Wert holen
;               lsrb
;               lsrb
               addb o2_en_          ;+3  43    ; e'(n) addieren

               addb o2_dither       ;+3  46
               ldx  #dac_8to3       ;+3  49
               abx                  ;+1  50
               abx                  ;+1  57
               ldaa Port6_DDR_buf   ;+3  53
               ldab Port6_Data      ;+3  56
               andb #%10011111      ;+2  58
               addd 0,x             ;+5  63    ; use ADD as OR
               std  Port6_DDR       ;+4  67    ; Store to DDR & Data

               xgdx                 ;+2   2    ;
               subb o2_dither       ;+3   5
               sbca #-1             ;+2   7    ; move pointer from dac_8to3 to dac_8to3_err
               xgdx                 ;+2   9
               ldab 1,x             ;+4  13    ; get e(n) from table

               addb o2_en2          ;+3  16    ; add e(n-2)
               ldaa #65             ;+2  18
               mul                  ;+7  25
               ldab o2_en1          ;+3  28
               stab o2_en2          ;+3  31
               lsrb                 ;+1  32
               aba                  ;+1  33
               staa o2_en_          ;+3  36
               ldab 0,x             ;+4  40
               stab o2_en1          ;+3  44
                                    ;-------
                                    ;+67 111

               ldab TCSR1           ;+3   3     ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4   7
               addd #181            ;+3  10     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4  14
               dec  oci_int_ctr     ;+6  16
               bne  o2ns_dither     ;+3  19
               ldab #12             ;+2  21
               stab oci_int_ctr     ;+3  24
               dec  gp_timer        ;+6  30    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4  34
               inx                  ;+1  35    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  39
                                    ;-------
               rti                  ;+10 150
o2ns_dither
               ldd  osc3_phase      ;+3   3
               rolb                 ;+1   4
               rola                 ;+1   5
               bcc  o2ns_dither_end ;+3   8
               eora #%00010000      ;+2  10
               eorb #%00100001      ;+2  12
o2ns_dither_end
               std  osc3_phase      ;+3  15
               andb #1              ;+2  17
               stab o2_dither       ;+3  20

               rti                  ;+10 146 / 150 / 150

#endif

;*****************
;digital double tone Oscillator
;
OCI_OSC3                            ;   +19
#ifdef EVA9
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
#else
; EVA5
               ldd  osc1_phase      ;+4  23    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  27    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  31    ; und neuen Phasenwert 1 speichern
               ldx  #sin_64_3_0dB   ;+3  34    ; Sinustabelle indizieren
               tab                  ;+1  35
               andb #%00111111      ;+2  37
               abx                  ;+1  38
               ldd  osc2_phase      ;+4  42    ; 16 Bit Phase 2 holen
               addd osc2_pd         ;+4  46    ; 16 Bit delta Phase 2 addieren
               std  osc2_phase      ;+4  50    ; neuen Phasenwert 2 speichern
               tab                  ;+1  51
               ldaa 0,x             ;+4  55    ; Tabelleneintrag 1 holen
               ldx  #sin_64_3_0dB   ;+3  58    ; Sinustabelle (Wertebereich 0-7)
               andb #%00111111      ;+2  60    ; stay within 64 byte (makes table smaller)
               abx                  ;+1  61
               ldab 0,x             ;+4  65    ; Tabelleneintrag 2 holen
               aba                  ;+1  67    ; Tabelleneintrag 1 addieren
               lsra                 ;+1  68    ; result/2
               xgdx                 ;+2  70
               ldd  osc3_phase      ;+4  74    ; 16 Bit Phase 1 holen
               addd osc3_pd         ;+4  78    ; 16 Bit delta phase 1 addieren
               std  osc3_phase      ;+4  82    ; und neuen Phasenwert 1 speichern
               tab                  ;+1  83
               andb #%00111111      ;+2  85
               clra                 ;+1  86
               addd #sin_64_3_0dB   ;+3  89    ; Sinustabelle indizieren
               xgdx                 ;+2  91
               adda 0,x             ;+4  95    ; combine results to new DAC1 & DAC2 output
               anda #%00011110      ;+2  97
               ldx  #dac_out_tab    ;+3 100    ; DAC Werte ausgeben
               tab                  ;+1 101
               abx                  ;+1 102    ; Table entry address in X
               ldaa Port6_DDR_buf   ;+3 105
               ldab Port6_Data      ;+3 108
               andb #%10011111      ;+2 110
               addd 0,x             ;+5 115    ; use ADD as OR
               std  Port6_DDR       ;+4 119    ; Store to DDR & Data

               ldab TCSR2           ;+3 122     ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4 126
               addd #249            ;+3 129     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4 133
                                    ;-------
#endif
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
; EVA5 / 7977600 Hz Xtal
;     -> 1994400 Hz E2 clock
;     -> 249 * 8000 Hz (NCO clock)       CPU load EVA5 = (1* 69,1 % + 7* 61,0 %) / 8 = 62,0 % average
;                                        (reduces effective CPU speed for program to ~758 kHz)
;
; EVA9 / 4924600 Hz Xtal
;     -> 1231150 Hz E2 clock
;     -> 154 * 8000 Hz (NCO clock)       CPU load EVA9 = (1* 94,1 % + 7* 81,2 %) / 8 = 82,8 % average
;                                        (reduces effective CPU speed for program to ~212 kHz)

