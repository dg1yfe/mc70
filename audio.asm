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
; D A C   F I L T E R
;**********************
;
; Set DAC output filter
;
; If active, additional Attenuation 10-12 dB
; cutoff frequency lowered to ~700 Hz
;
dac_filter
               pshb
               pshx
               ldab Port6_DDR_buf
               orab #%00010000
               stab Port6_DDR
               stab Port6_DDR_buf

               tsx
               ldab 2,x
               bne  dfi_active
               ldab Port6_Data
               andb #%11101111
               stab Port6_Data
               bra  dfi_end
dfi_active
               ldab Port6_Data
               orab #%00010000
               stab Port6_Data
dfi_end
               pulx
               pulb
               rts
;**********************
; T O N E   S T A R T
;**********************
;
; Startet Ton Oszillator
;
; Parameter : D - Tonfrequenz in 1/10 Hz
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

               ldd  #32000            ; Divisor  = Samplefrequenz * 4
;               ldd  #48000            ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus

               std  osc1_pd           ; Quotient = delta für phase

               ldab Port6_DDR_buf
               andb #%10011111
               stab Port6_DDR_buf
               stab Port6_DDR

               ldab #0
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
               addd #249*5            ; add 5 sample periods to ensure there is enough time
                                      ; before next interrupt occurs even on EVA9
               std  OCR1

               clra
               staa o2_en1
               staa o2_en2
               ldx  #OCI_OSC1
               stx  oci_vec           ; OCI Interrupt Vektor 'verbiegen'
                                      ; Ausgabe startet automatisch beim nächsten OCI
                                      ; 1/8000 s Zeitintervall wird automatisch gesetzt
;               clr  tasksw_en         ; re-enable preemptive task switching
               ldd  #$1
               std  osc1_dither
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

               ldd  #32000            ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus
               std  osc1_pd           ; Quotient = delta für phase

               ldx  #0
               pshx
               tsx
               ldx  2,x               ; Tonfrequenz 2/X holen
               pshx                   ; und auf Stack legen
               ldd  #32000            ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus
               std  osc2_pd           ; Quotient = delta für phase
               sei
               ldab TCSR2
               ldd  OCR1
               std  OCR2
               subd #SYSCLK/1000
               addd #249*5            ; add 5 sample periods to ensure there is enough time
                                      ; before next interrupt occurs even on EVA9
               std  OCR1

               ldx  #OCI_OSC2
               stx  oci_vec           ; OCI Interrupt Vektor 'verbiegen'
                                      ; Ausgabe startet automatisch beim nächsten OCI
                                      ; 1/8000 s Zeitintervall wird automatisch gesetzt
               cli
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
dkf_end
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

#ifdef EVA9
#include "audio_e9.asm"
#else
#include "audio_e5.asm"
#endif
