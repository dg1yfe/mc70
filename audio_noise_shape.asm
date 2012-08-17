;
; Audio output using noise shaping
; Optimized CPU usage:
; for 12 kHz Samplerate, all sample processing is done consecutively, stored and put out
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
#DEFCONT      \ lslb
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
#DEFCONT       \ tab
#DEFCONT       \ ldx  #dac_8to3
#DEFCONT       \ abx
#DEFCONT       \ abx
#DEFCONT       \ ldd  0,x
#DEFCONT       \ std  subaudiobuf+nr*2

; 19 cycles
; Input : X      - *Amplitude/Signal
;         B      - Dither LFSR
#DEFINE PUTSABUF1 andb #1
#DEFCONT       \ ldaa 0,x
#DEFCONT       \ suba o2_en_
#DEFCONT       \ staa osc_buf
#DEFCONT       \ aba
#DEFCONT       \ tab
#DEFCONT       \ ldx  #dac_8to3
#DEFCONT       \ abx
#DEFCONT       \ abx

; 10 cycles
; Input : X      - *Amplitude/Signal
#DEFINE PUTSABUF2(nr) ldd  0,x
#DEFCONT       \ std  subaudiobuf+nr*2

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
#DEFCONT     \ suba #48
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
#DEFCONT     \ suba #48
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
#DEFCONT     \ clra
#DEFCONT     \ clra
#DEFCONT     \ staa o2_en_

; 7 cycles
#DEFINE ERRFB2b ldab 0,x
#DEFCONT     \ stab o2_en1

; 9 cycles
#DEFINE SAMPOUT(nr) ldd  subaudiobuf+nr*2
#DEFCONT     \ std  Port6_DDR

;14 cycles
#DEFINE NEXTINT(cycles) ldab TCSR1
#DEFCONT     \ ldd  OCR1
#DEFCONT     \ addd #cycles
#DEFCONT     \ std  OCR1

;7 cycles
#DEFINE SETVEC(vec) ldx #vec
#DEFCONT     \ stx  oci_vec



               ldd  osc1_dither+1   ;+4   4    ; dither-> A, osc_buf -> B
               anda #1              ;+2   6
               addd #err_tab        ;+3   9    ; build index
               xgdx                 ;+2  11
               ldab 0,x             ;+4  16    ; get e(n) from table
               addd o2_en2          ;+3  20    ; add e(n-2)
               ldaa #65             ;+2  20
               mul                  ;+7  27
               ldab o2_en1          ;+3  30
               stab o2_en2          ;+3  33
               lsrb                 ;+1  34
               aba                  ;+1  35
               suba #32             ;+2  37    ; remove offset to get signed value
               staa o2_en_          ;+3  40
               ldab 0,x             ;+4  44    ; get e(n) from table (again)
               stab o2_en1          ;+3  47
                                    ;-------
                                    ;    47
                                    ;+70 117

;******************
; 1
;******************
OCI_OSC1ns                          ;   +19    Ausgabe
                                    ;------
                                    ;    19
               ldd  subaudiobuf+11*2;+5   5    ; output sample 12
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
               lslb                 ;+1   4    ; shift LFSR
               rola                 ;+1   5
               bcc  $+4             ;+3   8    ; do nothing if MSB was 0
               eorb #%010010011     ;+2  12    ; calculate Feedback
               std  osc1_dither     ;+4  16/14 ; store LFSR
                                    ;------
                                    ;    15
                                    ;+26 41

               andb #1              ;+2   2    ; isolate 1 Bit as dither
               ldaa 0,x             ;+4   6    ; DAC Wert holen
               suba o2_en_          ;+3   9    ; e'(n) abziehen
               staa osc_buf         ;+3  12
               aba                  ;+1  13    ; Dither addieren
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
;               suba #32             ;+2  37    ; remove offset to get signed value
               clra
               clra
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
               PUTSABUF(1)
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

;******************
; 1
;******************
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
               lslb                 ;+1   4    ; shift LFSR
               rola                 ;+1   5
               bcc  $+4             ;+3   8    ; do nothing if MSB was 0
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
               aba                  ;+1  13    ; Dither addieren
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
               lslb                 ;+1   4    ; shift LFSR
               rola                 ;+1   5
               bcc  $+4             ;+3   8    ; do nothing if MSB was 0
               eorb #%010010011     ;+2  12    ; calculate Feedback
               std  osc1_dither     ;+4  16/14 ; store LFSR
                                    ;------
                                    ;    15
                                  ;+103 118

               lsrb                 ;+1   1    ; x(n) / 2
               tba                  ;+1   2
               addb o2_en2          ;+3   5    ; add "x(n-2)/2"
               staa o2_en2          ;+3   8    ; store "x(n)/2" for further processing on next sample
               lsrb                 ;+1   9    ; y(n) = (x(n)/2 + x(n-2)/2) / 2
               addb o2_en1          ;+3  12    ; y(n) =  x(n)/4 + x(n-1)/2 + x(n-2)/4 -> binomial filter
               lsrb                 ;+1  13    ;
               lsrb                 ;+1  14    ; decrease Amplitude by 12 dB
               ldaa #255-96         ;+2  16    ; remove DC offset
               sba                  ;+1  17    ; invert amplitude (in every 2nd sample) to invert noise spectrum
                                    ;------
                                    ;    17
                                  ;+118 135

               ldab 0,x             ;+4   6    ; DAC Wert holen
               aba                  ;+1  13    ; Dither addieren
               tab                  ;+1  14    ; nach B
               ldx  #dac_8to3       ;+3  17
               abx                  ;+1  18
               abx                  ;+1  19
               ldd  0,x             ;+5  24    ; get output value for Port and DDR register
               std  subaudiobuf+2   ;+5  29    ; Store to Buf
                                    ;------
                                    ;    29
                                  ;+135 164

               ldab TCSR1           ;+3   3     ; Timer Control / Status Register 2 lesen
;167
               ldd  subaudiobuf     ;+5   8    ; output sample 0
               std  Port6_DDR       ;+4  12

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
