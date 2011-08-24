
;********************************************************
; Single tone oscillator with noise shaping
;
; Optimized CPU usage:
; For 12 kHz Samplerate, all sample processing is done consecutively, stored and put out
; every 1/12000 s (~166 cycles). When all samples are calculated, the int is only set to
; do output every 166 cycles.
; Instead of 12 (every int a sample is calculated and put out), only 4 Interrupts
; occur every ms. This saves 8*29 = 232 cycles / 10% CPU time which would otherwise be
; wasted for "jump to int"/"vector evaluation"/"return from int"
;

;******************
; 17 cycles
; Input : o2_en_ - Error Feedback
; Output: B      - Amplitude/Signal
#DEFINE OSCILLATOR1 ldd  osc1_phase \
#DEFCONT          \ addd osc1_pd
#DEFCONT          \ std  osc1_phase
#DEFCONT          \ ldx  #dac_sin256
#DEFCONT          \ tab
#DEFCONT          \ abx

#DEFINE DITHER  ldd  osc1_dither
#DEFCONT      \ rolb
#DEFCONT      \ rola
#DEFCONT      \ bcc  $+4
#DEFCONT      \ eorb #%010010011
#DEFCONT      \ std  osc1_dither

; 29 cycles
; Input : X      - *Amplitude/Signal
;         B      - Dither LFSR
#DEFINE PUTSABUF(nr) andb #1
#DEFCONT       \ ldaa 0,x
#DEFCONT       \ suba o2_en_
#DEFCONT       \ staa osc_buf
#DEFCONT       \ aba
;#DEFCONT        \ nop
#DEFCONT       \ tab
#DEFCONT       \ ldx  #dac_8to3
#DEFCONT       \ abx
#DEFCONT       \ abx
#DEFCONT       \ ldd  0,x
#DEFCONT       \ std  subaudiobuf+(nr*2)

; 19 cycles
; Input : X      - *Amplitude/Signal
;         B      - Dither LFSR
#DEFINE PUTSABUF1 andb #1
#DEFCONT       \ ldaa 0,x
#DEFCONT       \ suba o2_en_
#DEFCONT       \ staa osc_buf
#DEFCONT       \ aba
;#DEFCONT        \ nop
#DEFCONT       \ tab
#DEFCONT       \ ldx  #dac_8to3
#DEFCONT       \ abx
#DEFCONT       \ abx

; 10 cycles
; Input : X      - *Amplitude/Signal
#DEFINE PUTSABUF2(nr) ldd  0,x
#DEFCONT       \ std  subaudiobuf+(nr*2)

; 47 cycles
#DEFINE ERRFB  ldd  osc1_dither+1
#DEFCONT     \ anda #1
#DEFCONT     \ addd #err_tab
#DEFCONT     \ xgdx
#DEFCONT     \ ldab 0,x
#DEFCONT     \ addb o2_en2
#DEFCONT     \ ldaa #65
#DEFCONT     \ mul
#DEFCONT     \ ldab o2_en1
#DEFCONT     \ stab o2_en2
#DEFCONT     \ lsrb
#DEFCONT     \ aba
#DEFCONT     \ suba #32
;#DEFCONT     \ nop
;#DEFCONT     \ clra
#DEFCONT     \ staa o2_en_
#DEFCONT     \ ldab 0,x
#DEFCONT     \ stab o2_en1

; 21 cycles
#DEFINE ERRFB1  ldd  osc1_dither+1
#DEFCONT     \ anda #1
#DEFCONT     \ addd #err_tab
#DEFCONT     \ xgdx
#DEFCONT     \ ldab 0,x
#DEFCONT     \ addb o2_en2
#DEFCONT     \ stab o2_en2

; 32 cycles
#DEFINE ERRFB2 ldab o2_en2
#DEFCONT     \ ldaa #65
#DEFCONT     \ mul
#DEFCONT     \ ldab o2_en1
#DEFCONT     \ stab o2_en2
#DEFCONT     \ lsrb
#DEFCONT     \ aba
#DEFCONT     \ suba #32
;#DEFCONT     \ nop
;#DEFCONT     \ clra
#DEFCONT     \ staa o2_en_
#DEFCONT     \ ldab 0,x
#DEFCONT     \ stab o2_en1

; 40 cycles
#DEFINE ERRFB1b ldd  osc1_dither+1
#DEFCONT     \ anda #1
#DEFCONT     \ addd #err_tab
#DEFCONT     \ xgdx
#DEFCONT     \ ldab 0,x
#DEFCONT     \ addb o2_en2
#DEFCONT     \ ldaa #65
#DEFCONT     \ mul
#DEFCONT     \ ldab o2_en1
#DEFCONT     \ stab o2_en2
#DEFCONT     \ lsrb
#DEFCONT     \ aba
#DEFCONT     \ suba #32
;#DEFCONT     \ nop
;#DEFCONT     \ clra
#DEFCONT     \ staa o2_en_

; 7 cycles
#DEFINE ERRFB2b ldab 0,x
#DEFCONT     \ stab o2_en1

; 9 cycles
#DEFINE SAMPOUT(nr) ldd  subaudiobuf+(nr*2)
;#DEFINE SAMPOUT(nr) ldd  subaudiobuf
#DEFCONT     \ std  Port6_DDR
;#DEFCONT     \ std  osc2_phase

;14 cycles
#DEFINE NEXTINT(cycles) ldab TCSR1
#DEFCONT     \ ldd  OCR1H
#DEFCONT     \ addd #cycles
#DEFCONT     \ std  OCR1H

;7 cycles
#DEFINE SETVEC(vec) ldx #vec
#DEFCONT     \ stx  oci_vec

;******************
; 1
;******************
OCI_OSC1ns                          ;   +19    Ausgabe
                                    ;------
                                    ;    19

               ldd  subaudiobuf+(11*2);+5   5    ; output sample 12
               std  Port6_DDR       ;+4   9
                                    ;------
                                    ;     9

               ldd  osc1_phase      ;+4   4    ; 16 Bit Phase 1 holen (8.8)
               addd osc1_pd         ;+4   8    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  12    ; und neuen Phasenwert 1 speichern
               ldx  #dac_sin256     ;+3  15    ; Sinustabelle indizieren
               tab                  ;+1  16    ; Phasenwert (int)
               abx                  ;+1  17    ; addieren
                                    ;------
                                    ;    17
                                    ;+ 9 26

               ldd  osc1_dither     ;+4   4    ; get LFSR
               rolb                 ;+1   4    ; shift LFSR
               rola                 ;+1   5
               bcc  $+4             ;+3   8    ; do nothing if MSB was 0
               eorb #%010010011     ;+2  12    ; calculate Feedback
               std  osc1_dither     ;+4  16/14 ; store LFSR
                                    ;------
                                    ;    15
                                    ;+26 41

               andb #1              ;+2   2    ; isolate 1 Bit as dither
               ldaa 0,x             ;+4   6    ; DAC Wert holen
               aba
               suba o2_en_          ;+3   9    ; e'(n) abziehen
               staa osc_buf         ;+3  12
;               aba                  ;+1  13    ; Dither addieren
;                nop
               tab                  ;+1  14    ; nach B
               ldx  #dac_8to3       ;+3  17
               abx                  ;+1  18
               abx                  ;+1  19
               ldd  0,x             ;+5  24    ; get output value for Port and DDR register
               std  subaudiobuf     ;+5  29    ; Store to Buf
                                    ;------
                                    ;    29
                                    ;+41 70

               ldd  osc1_dither+1   ;+4   4    ; dither-> A, osc_buf -> B
               anda #1              ;+2   6
               addd #err_tab        ;+3   9    ; build index
               xgdx                 ;+2  11
               ldab 0,x             ;+4  15    ; get e(n) from table
               addb o2_en2          ;+3  18    ; add e(n-2)
               ldaa #65             ;+2  20
               mul                  ;+7  27
               ldab o2_en1          ;+3  30
               stab o2_en2          ;+3  33
               lsrb                 ;+1  34
               aba                  ;+1  35
               suba #32             ;+2  37    ; remove offset to get signed value
;              nop
;              clra
               staa o2_en_          ;+3  40
               ldab 0,x             ;+4  44    ; get e(n) from table (again)
               stab o2_en1          ;+3  47
                                    ;-------
                                    ;    47
                                    ;+70 117
;******************
; 2 - calc sample 2
;******************
               OSCILLATOR1
;+17
               DITHER
;+15
               PUTSABUF1
;+19
;168
               SAMPOUT(0)
;+9
               PUTSABUF2(1)
;+10
               ERRFB
;+47
;234
;******************
; 3
;******************
               OSCILLATOR1
;+17
               DITHER
;+15
               PUTSABUF(2)
;+29
               ERRFB1b
;+40
;335
               SAMPOUT(1)
;+9
               ERRFB2b
;+7
;351
;******************
; 4
;******************
               OSCILLATOR1
;+17
               DITHER
;+15
               PUTSABUF(3)
;+29
               ERRFB
;+47
;459
;******************
; 5
;******************
               OSCILLATOR1
;+17
               DITHER
;+15
;491
               SAMPOUT(2)
;+9
               PUTSABUF(4)
;+29
               ERRFB
;+47
;576
;******************
; 6
;******************
               OSCILLATOR1
;+17
               DITHER
;+15
               PUTSABUF(5)
;+29
               ERRFB1
;+21
;658
               SAMPOUT(3)
;+9
               ERRFB
;+47
;714
;******************
; 7
;******************
               OSCILLATOR1
;+17
               DITHER
;+15
               PUTSABUF(6)
;+29
               ERRFB
;+47
;822
               SAMPOUT(4)
;+9
;831
;******************
; 8
;******************
               OSCILLATOR1
;+17
               DITHER
;+15
               PUTSABUF(7)
;+29
               ERRFB
;+47
;939
;******************
; 9
;******************
               OSCILLATOR1
;+17
               DITHER
;+15
               PUTSABUF(8)
;+29
;1000
               SAMPOUT(5)
;+9
               ERRFB
;+47
;1056
;******************
; 10
;******************
               OSCILLATOR1
;+17
               DITHER
;+15
               PUTSABUF(9)
;+29
               ERRFB
;+47
;1164
               SAMPOUT(6)
;+9
;1173
;******************
; 11
;******************
               OSCILLATOR1
;+17
               DITHER
;+15
               PUTSABUF(10)
;+29
               ERRFB
;+47
;1281
;******************
; 12
;******************
               OSCILLATOR1
;+17
               DITHER
;+15
               PUTSABUF1
;+19
;1332
               SAMPOUT(7)
;+9
               PUTSABUF2(11)
;+10
               ERRFB
;+47
;1398
               NEXTINT(1496)
;+14
               SETVEC(OCI_OSC1S8)
;+7
               rti
;+10
;1429 -> 67 Takte für Programm

OCI_OSC1S8
;Ausgabe Sample 8
;+19
               SAMPOUT(8)
;+9
;
               NEXTINT(166)
;+14
               SETVEC(OCI_OSC1S9)
;+7
               rti
;+10
;1555 -> 107 Takte für Programm
OCI_OSC1S9
;Ausgabe Sample 8
;+19
               SAMPOUT(9)
;+9
;
               NEXTINT(166)
;+14
; int bei 1828
               SETVEC(OCI_OSC1S10)
;+7
               rti
;+10
;1721 -> 107 Takte für Programm

OCI_OSC1S10
;Ausgabe Sample 8
;+19
               SAMPOUT(10)
;+9
;
               NEXTINT(166)
;+14
; int bei 1828
               SETVEC(OCI_OSC1ns)
;+7
;1877
               dec  gp_timer        ;+6   6    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4  10
               inx                  ;+1  11    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  15
               rti                  ;+10 25
                                    ;-------
                                    ;    25
;1902 -> 92 Takte für Programm
;
; 92+107+107+67 = 373/1994 = 18,7%
; CPU Last durch Interrupt/Soundausgabe: (1994-373)/1994 = 81,3 %

OCI_OSC1ns2                         ;   +19    Ausgabe
                                    ;------
                                    ;    19
               ldd  subaudiobuf+2   ;+5   5    ; output sample 1
               std  Port6_DDR       ;+4   9
                                    ;------
                                    ;     9

               ldd  osc1_phase      ;+4   4    ; 16 Bit Phase 1 holen (8.8)
               addd osc1_pd         ;+4   8    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  12    ; und neuen Phasenwert 1 speichern
               ldx  #dac_sin256     ;+3  15    ; Sinustabelle indizieren
               tab                  ;+1  16    ; Phasenwert (int)
               abx                  ;+1  17    ; addieren
                                    ;------
                                    ;    17
                                    ;+ 9 26

               ldd  osc1_dither     ;+4   4    ; get LFSR
               rolb                 ;+1   4    ; shift LFSR
               rola                 ;+1   5
               bcc  $+2             ;+3   8    ; do nothing if MSB was 0
               eorb #%010010011     ;+2  12    ; calculate Feedback
               std  osc1_dither     ;+4  16/14 ; store LFSR
                                    ;------
                                    ;    15
                                    ;+26 41

               lsrb                 ;+1   1    ; x(n) / 2
               tba                  ;+1   2
               adda o2_en2          ;+3   5    ; add "x(n-2)/2"
               stab o2_en2          ;+3   8    ; store "x(n)/2" for further processing on next sample
               lsra                 ;+1   9    ; y(n) = (x(n)/2 + x(n-2)/2) / 2
               adda o2_en1          ;+3  12    ; y(n) =  x(n)/4 + x(n-1)/2 + x(n-2)/4 -> binomial filter
               lsra                 ;+1  13    ;
               lsra                 ;+1  14    ; decrease Amplitude by 12 dB
               adda #96             ;+2  16    ; remove DC offset
                                    ;------
                                    ;    16
                                    ;+41 57

               ldab 0,x             ;+4   6    ; DAC Wert holen
               tab                  ;+1  13    ; Dither addieren
               tab                  ;+1  14    ; nach B
               ldx  #dac_8to3       ;+3  17
               abx                  ;+1  18
               abx                  ;+1  19
               ldd  0,x             ;+5  24    ; get output value for Port and DDR register
               std  subaudiobuf     ;+5  29    ; Store to Buf
                                    ;------
                                    ;    29
                                    ;+57 86
;---------------
               ldd  osc1_phase      ;+4   4    ; 16 Bit Phase 1 holen (8.8)
               addd osc1_pd         ;+4   8    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  12    ; und neuen Phasenwert 1 speichern
               ldx  #dac_sin256     ;+3  15    ; Sinustabelle indizieren
               tab                  ;+1  16    ; Phasenwert (int)
               abx                  ;+1  17    ; addieren
                                    ;------
                                    ;    17
                                   ;+86 103

               ldd  osc1_dither     ;+4   4    ; get LFSR
               rolb                 ;+1   4    ; shift LFSR
               rola                 ;+1   5
               bcc  $+2             ;+3   8    ; do nothing if MSB was 0
               eorb #%010010011     ;+2  12    ; calculate Feedback
               std  osc1_dither     ;+4  16/14 ; store LFSR
                                    ;------
                                    ;    15
                                  ;+103 118

               lsrb                 ;+1   1    ; x(n) / 2
               tba                  ;+1   2
               addb o2_en1          ;+3   5    ; add "x(n-2)/2"
               staa o2_en1          ;+3   8    ; store "x(n)/2" for further processing on next sample
               lsrb                 ;+1   9    ; y(n) = (x(n)/2 + x(n-2)/2) / 2
               addb o2_en2          ;+3  12    ; y(n) =  x(n)/4 + x(n-1)/2 + x(n-2)/4 -> binomial filter
               lsrb                 ;+1  13    ;
               lsrb                 ;+1  14    ; decrease Amplitude by 12 dB
               ldaa #255-96         ;+2  16    ; remove DC offset
               sba                  ;+1  17    ; invert amplitude (in every 2nd sample) to invert noise spectrum
                                    ;------
                                    ;    17
                                  ;+118 135

               ldab 0,x             ;+4   6    ; DAC Wert holen
               tab                  ;+1  13    ; Dither addieren
               tab                  ;+1  14    ; nach B
               ldx  #dac_8to3       ;+3  17
               abx                  ;+1  18
               abx                  ;+1  19
               ldd  0,x             ;+5  24    ; get output value for Port and DDR register
               std  subaudiobuf+2   ;+5  29    ; Store to Buf
                                    ;------
                                    ;    29
                                  ;+135 164

;167
               ldd  subaudiobuf     ;+5   8    ; output sample 0
               std  Port6_DDR       ;+4  12

               ldab TCSR1           ;+3   3     ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  16
               addd #332            ;+3  19     ; ca 6000 mal pro sek Int auslösen
               std  OCR1            ;+4  23
                                    ;------
                                    ;    23
                                  ;+164 187

               dec  gp_timer        ;+6   6    ; Universaltimer-- / HW Task
               ldx  tick_ms         ;+4  10
               inx                  ;+1  11    ; 1ms Tick-Counter erhöhen
               stx  tick_ms         ;+4  15
               rti                  ;+10 25
                                    ;-------
                                    ;    25
                                  ;+187 212
                                  ;+19  231    ; Int entry
; CPU load with active NCO
;
; EVA5 / 7977600 Hz Xtal
;     -> 1994400 Hz E2 clock
;     -> 166 * 12000 Hz (NCO clock)       CPU load EVA5 = 231/(2*166) = 69,6 %
;                                         (reduces effective CPU speed for program to ~1388 kHz)
;*****************

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
;*****************
;digital double tone Oscillator
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
               tab                  ;+1  51

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


;*****************
;digital triple tone Oscillator
;
OCI_OSC3                            ;   +19
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
; CPU load with active NCO
;
; EVA5 / 7977600 Hz Xtal
;     -> 1994400 Hz E2 clock
;     -> 249 * 8000 Hz (NCO clock)       CPU load EVA5 = (1* 69,1 % + 7* 61,0 %) / 8 = 62,0 % average
;                                        (reduces effective CPU speed for program to ~758 kHz)
;
