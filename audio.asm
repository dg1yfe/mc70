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
; Parameter : B - 0 = off
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

               ldd  #32000            ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus

               std  osc1_pd           ; Quotient = delta für phase

               ldab Port6_DDR_buf
               andb #%10011111
               orab #%00010000
               stab Port6_DDR_buf
               stab Port6_DDR

               ldab Port6_Data
               andb #%10001111
               stab Port6_Data

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
#ifdef EVA9
               ldab #1
               stab oci_int_ctr       ; Interrupt counter auf 1
                                      ; (Bit is left shifted during Audio OCI, on zero 1ms OCI will be executed)
#endif
#ifdef EVA5
               ldab TCSR2
               ldd  OCR1
;               std  OCR2
               subd #SYSCLK/1000
               addd #249*5            ; add 5 sample periods to ensure there is enough time
                                      ; before next interrupt occurs even on EVA9
               std  OCR1
#endif
               ldx  #OCI_OSC1
               stx  oci_vec           ; OCI Interrupt Vektor 'verbiegen'
                                      ; Ausgabe startet automatisch beim nächsten OCI
                                      ; 1/8000 s Zeitintervall wird automatisch gesetzt
               stx  subaudiobuf+24

               ldd  #$1
               std  osc1_dither
               clra

               staa o2_en1
               staa o2_en2
               ldaa Port6_DDR_buf
               ldab Port6_Data
               std  subaudiobuf+( 0*2); initialize data buffers to current state
               std  subaudiobuf+( 1*2)
               std  subaudiobuf+( 2*2)
               std  subaudiobuf+( 3*2)
               std  subaudiobuf+( 4*2)
               std  subaudiobuf+( 5*2)
               std  subaudiobuf+( 6*2)
               std  subaudiobuf+( 7*2)
               std  subaudiobuf+( 8*2)
               std  subaudiobuf+( 9*2)
               std  subaudiobuf+(10*2)
               std  subaudiobuf+(11*2)
               clr  tasksw_en         ; re-enable preemptive task switching
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

               ldx  oci_vec
               cpx  #OCI_OSC1
               beq  tstop_toocims
               cpx  #OCI_OSC2
               beq  tstop_toocims
               cpx  #OCI_OSC1d
               beq  tstop_toocims

               ldx  #OCI_OSC1_CLEANUP
               stx  subaudiobuf+24
tstop_loop
               ldx  oci_vec
               cpx  #OCI1_MS
               bne  tstop_loop

tstop_toocims
               ldx  #OCI1_MS
               stx  oci_vec

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
;**********************
; A T O N E   S T A R T
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
atone_start
               pshb
               psha
               pshx

               ldx  #0
               pshx                   ; Lo Word = 0
               pshb                   ; Hi Word sichern
               psha                   ; => f*65536 auf Stack speichern

               ldd  #32000            ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus

               std  osc1_pd           ; Quotient = delta für phase

               ldab Port2_DDR_buf
               orab #%01000000
               stab Port2_DDR_buf
               stab Port2_DDR

               ldab #0
               stab tasksw_en         ; disable preemptive task switching
               sei
               ldab tick_ms+1
ats_intloop
               cli
               nop                    ; don't remove these NOPs
               nop                    ; HD6303 needs at least 2 clock cycles between cli & sei
               sei                    ; otherwise interrupts aren't processed
               cmpb tick_ms+1
               beq  ats_intloop

               ldab TCSR2
               ldd  OCR1
               std  OCR2
               subd #SYSCLK/1000
               addd #249*5            ; add 5 sample periods to ensure there is enough time
                                      ; before next interrupt occurs even on EVA9
               std  OCR1
               ldx  #OCI_OSC_ALERT
               stx  oci_vec           ; OCI Interrupt Vektor 'verbiegen'
                                      ; Ausgabe startet automatisch beim nächsten OCI
                                      ; 1/8000 s Zeitintervall wird automatisch gesetzt
;               clr  tasksw_en         ; re-enable preemptive task switching
               cli
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
atone_stop
               pshb
               psha
               ldd  #OCI1_MS
               std  oci_vec            ; OCI wieder auf Timer Interrupt zurücksetzen
                                       ; Zeitbasis für Timerinterrupt (1/1000 s) wird im Int zurückgestellt
                                       ; DAC wieder auf Mittelwert zurücksetzen
               ldab Port2_DDR_buf
               andb #%10111111
               stab Port2_DDR
               stab Port2_DDR_buf

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
#include "audio_noise_shape.asm"
#endif
