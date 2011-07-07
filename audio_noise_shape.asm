;
; Audio output using noise shaping
; Optimized CPU usage:
; Every 12th int is called, this saves 12*20 cycles (jump to int/return from int)
; Several values (Port output data, Dithering) are calculated in advance
;
;
;
;
OCI_OSC2ns                          ;   +19    Ausgabe Stream1 (Bit 0-2)
OCI_OSC1ns                          ;   +19    Ausgabe Stream1 (Bit 0-2)
               ldd  osc1_phase      ;+4  23    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  27    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  31    ; und neuen Phasenwert 1 speichern
               ldx  #dac_sin256     ;+3  34    ; Sinustabelle indizieren
               tab                  ;+1  35
               abx                  ;+1  36
;               clrb
               ldab 0,x             ;+4  40    ; DAC Wert holen
;               lsrb
;               lsrb
               addb o2_en_          ;+3  43    ; e'(n) addieren

;               subb #1              ;+2  46    ; no dither / dither=0
               ldx  #dac_8to3       ;+3  49
               abx                  ;+1  50
               abx                  ;+1  57
               ldaa Port6_DDR_buf   ;+3  53
               ldab Port6_Data      ;+3  56
               andb #%10011111      ;+2  58
               addd 0,x             ;+5  63    ; use ADD as OR
               std  Port6_DDR       ;+4  67    ; Store to DDR & Data

               xgdx                 ;+2   2    ;
               inca                 ;+1   3    ; move pointer from dac_8to3 to dac_8to3_err
               xgdx                 ;+2   5
               ldab 0,x             ;+4   9    ; get e(n) from table

               addb o2_en2          ;+3  12    ; add e(n-2)
               ldaa #65             ;+2  14
               mul                  ;+7  21
               ldab o2_en1          ;+3  24
               stab o2_en2          ;+3  27
               lsrb                 ;+1  28
               aba                  ;+1  29
               suba #48             ;+2  31    ; remove offset to get signed value
               staa o2_en_          ;+3  34
               ldab 0,x             ;+4  38
               stab o2_en1          ;+3  41
                                    ;-------
                                    ;+67 108

               ldab TCSR1           ;+3   3     ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4   7
               addd #1994           ;+3  10     ; ca 1000 mal pro sek Int auslösen
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
               ldx  osc1_dither
               ldaa 0,x

               ldd  osc3_phase      ;+3   3
               rolb                 ;+1   4
               rola                 ;+1   5
               bcc  o2ns_dither_end ;+3   8
               eora #%00010000      ;+2  10
               eorb #%00100001      ;+2  12
o2ns_dither_end
               std  osc3_phase      ;+3  15
               lsrb
               bcc  o2ns_dp
               ldx  #o2ns
               andb #1              ;+2  17
               stab o2_dither       ;+3  20

               rti                  ;+10 146 / 150 / 150

;******************
; 27 cycles
; Input : o2_en_ - Error Feedback
; Output: B      - Amplitude/Signal
#DEFINE OSCILLATOR1 ldd  osc1_phase
#DEFCONT          \ addd osc1_pd
#DEFCONT          \ std  osc1_phase
#DEFCONT          \ ldx  #dac_sin256
#DEFCONT          \ tab
#DEFCONT          \ abx
#DEFCONT          \ ldab 0,x
#DEFCONT          \ stab osc_buf
#DEFCONT          \ subb o2_en_

; 15 cycles
; Input : B      - Amplitude/Signal
#DEFINE PUTSABUF(adr) ldx  #dac_8to3
#DEFCONT       \ abx
#DEFCONT       \ abx
#DEFCONT       \ ldd  0,x
#DEFCONT       \ std  adr

; 45 cycles
#DEFINE ERRFB  ldd  #err_tab
#DEFCONT     \ addd o2_en_
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

;******************
; 1
;******************
               ldd  osc1_phase      ;+4   4    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4   8    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  12    ; und neuen Phasenwert 1 speichern
               ldx  #dac_sin256     ;+3  15    ; Sinustabelle indizieren
               tab                  ;+1  16
               abx                  ;+1  17

               ldd  osc1_dither     ;+3   3
               rolb                 ;+1   4
               rola                 ;+1   5
               bcc  +2              ;+3   8
               eorb #%010010011     ;+2  12
               std  osc1_dither     ;+3  15/13, avg=14
                                    ;------
                                    ;    14

               andb #1              ;+2
               addb 0,x             ;+4  21    ; DAC Wert holen
               stab osc_buf         ;+3  24
               subb o2_en_          ;+3  27    ; e'(n) addieren


               ldx  #dac_8to3       ;+3  30
               abx                  ;+1  31
               abx                  ;+1  32
               ldd  0,x             ;+5  37    ; use ADD as OR
               std  subaudiobuf     ;+5  42    ; Store to Buf



               ldd  #err_tab        ;+3   3
               addd o2_en_          ;+4   7    ; o2_en_ + osc_buf
               xgdx                 ;+2   9
               ldab 0,x             ;+4  13    ; get e(n) from table
               addb o2_en2          ;+3  16    ; add e(n-2)
               ldaa #65             ;+2  18
               mul                  ;+7  25
               ldab o2_en1          ;+3  28
               stab o2_en2          ;+3  31
               lsrb                 ;+1  32
               aba                  ;+1  33
               suba #48             ;+2  35    ; remove offset to get signed value
               staa o2_en_          ;+3  38
               ldab 0,x             ;+4  42
               stab o2_en1          ;+3  45
                                    ;-------
                                    ;+42 87
;******************
; 2
;******************
               OSCILLATOR1
               PUTSABUF(subaudiobuf+2)
               ERRFB
;******************
; 3
;******************
               OSCILLATOR1
               PUTSABUF(subaudiobuf+4)
               ERRFB
;******************
; 4
;******************
               OSCILLATOR1
               PUTSABUF(subaudiobuf+6)
               ERRFB
;******************
; 5
;******************
               OSCILLATOR1
               PUTSABUF(subaudiobuf+8)
               ERRFB
;******************
; 6
;******************
               OSCILLATOR1
               PUTSABUF(subaudiobuf+10)
               ERRFB
;******************
; 7
;******************
               OSCILLATOR1
               PUTSABUF(subaudiobuf+12)
               ERRFB
;******************
; 8
;******************
               OSCILLATOR1
               PUTSABUF(subaudiobuf+14)
               ERRFB
;******************
; 9
;******************
               OSCILLATOR1
               PUTSABUF(subaudiobuf+16)
               ERRFB
;******************
; 10
;******************
               OSCILLATOR1
               PUTSABUF(subaudiobuf+18)
               ERRFB
;******************
; 11
;******************
               OSCILLATOR1
               PUTSABUF(subaudiobuf+20)
               ERRFB
;******************
; 12
;******************
               OSCILLATOR1
               PUTSABUF(subaudiobuf+22)
               ERRFB

               ldab TCSR1           ;+3   3     ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4   7
               addd #1994           ;+3  10     ; ca 1000 mal pro sek Int auslösen
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
               ldx  osc1_dither
               ldaa 0,x

               ldd  osc3_phase      ;+3   3
               rolb                 ;+1   4
               rola                 ;+1   5
               bcc  o2ns_dither_end ;+3   8
               eorb #%00101101      ;+2  12
o2ns_dither_end
               std  osc3_phase      ;+3  15
               lsrb
               bcc  o2ns_dp
               ldx  #o2ns
               andb #1              ;+2  17
               stab o2_dither       ;+3  20

               rti                  ;+10 146 / 150 / 150
