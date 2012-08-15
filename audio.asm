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
;
;
;****************************************************************************
#IFDEF EVA5
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
#ENDIF
;**********************
; T O N E   S T A R T
;**********************
;
; Startet Ton Oszillator
;
; Parameter : D - Tonfrequenz in 1 Hz
;
;
; delta phase = f / 8000 * 256 * 256
; wegen Integer rechnung:
; dp = f*256*256 / 8000
; einfacher (da *65536 einem Shift um 2 ganze Bytes entspricht)
; dp = f*  65536  /  8000
;
; Frequenzabweichung maximal 8000 / (256 (Schritte in Sinus Tabelle) * 256 (8 Bit 'hinterm Komma')
; = 0,122 Hz
;
tone_start
               pshb
               psha
               pshx

               pshx                   ; Lo Word = 0
               pshb                   ; Hi Word sichern
               psha                   ; => f*65536 auf Stack speichern

               ldd  #8000             ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus

               std  osc1_pd           ; Quotient = delta für phase

               ldx  oci_vec           ; check if CTCSS/PL tone generator is active
               cpx  #OCI_OSC1_sig
               beq  tos_end           ; correct vector is already set, goto exit
               cpx  #OCI_OSC1_pl
               beq  tos_oscvec2sp     ; signalling & CTCSS
               cpx  #OCI_OSC2_sp
               beq  tos_oscvec2sp     ; signalling & CTCSS
               cpx  #OCI_OSC2
               beq  tos_oscvec3      ; dual tone signalling & CTCSS
               cpx  #OCI_OSC3
               beq  tos_oscvec3      ; dual tone signalling & CTCSS

#ifdef EVA5
               ldab Port6_DDR_buf
               andb #%10011111
               stab Port6_DDR_buf
               stab Port6_DDR
#endif
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
               std  OCR2
               subd #SYSCLK/1000
               addd #SYSCLK/1600      ; add 5 sample periods to ensure there is enough time
                                      ; before next interrupt occurs even on EVA9
               std  OCR1
#endif
               ldx  #OCI_OSC1_sig     ; signalling NCO
               bra  tos_setvec
tos_oscvec2sp
               ldx  #OCI_OSC2_sp      ; signalling NCO & CTCSS NCO
               bra  tos_setvec
tos_oscvec3
               ldx  #OCI_OSC3         ; dual tone signalling NCO & CTCSS NCO
tos_setvec
               stx  oci_vec           ; set new OCI interrupt vector
                                      ; output starts autonmatically with next 1 ms interrupt
                                      ; 1/8000 s interval is then set automatically
               cli
tos_end
               pulx
               pula
               pulb
               rts
#IFDEF EVA9
;**************************
; T O N E   S T A R T  P L
;**************************
;
; Starts CTCSS tone oscillator
;
; Parameter : D - frequency in 1/10 Hz (e.g. 1230 for 123.0 Hz)
;
; f_max is 312.4 Hz due to 8.8 phase increment (255.99609375 / 65536 * 80000)
; Since highest CTCSS tone is around 250 Hz, this is sufficient.
; Furthermore the low-pass filter has a cutoff frequency around 300 Hz...
;
; delta phase = f/10 / 8000 * 256 * 256
; due to integer arithmetic:
; dp = f*256*256 /(10* 8000)
; simple because *65536 corresponds to a 2 byte (16 bit) left-shift
; dp = f*  65536  /  80000
; Because divide32 uses only 16 Bit divisor, divide by 40000 and then do
; a right shift by 1 bit (/2)
; dp = (f*  65536  /  40000) / 2
;
; frequency resolution is :
; 80000 / (256 (Schritte in Sinus Tabelle) * 256 (8 Bit fractional)
; = 0,122 Hz
; so maximum frequency error due to 8.8 integer arithmetic will be 0,061 Hz
;

tone_start_pl
               pshb
               psha
               pshx
tosp_entry
               ldx  #0
               pshx                   ; Lo Word = 0
               pshb                   ; Hi Word sichern
               psha                   ; => f*65536 auf Stack speichern

               ldd  #40000            ; Divisor  = sample frequency * 5
               jsr  divide32          ;
               pula
               pulb                   ; Divide Quotient by 2
               lsrd                   ; resulting in division by 80000 (fs * 10)
               pula
               rora
               pulb
               rorb

               std  osc3_pd           ; Quotient = delta für phase

               ldx  oci_vec           ; check if CTCSS/PL tone generator is active
               cpx  #OCI_OSC1_pl
               beq  tosp_end          ; correct vector is already set, goto exit
               cpx  #OCI_OSC1_sig
               beq  tosp_oscvec2sp    ; signalling & CTCSS
               cpx  #OCI_OSC2_sp
               beq  tosp_oscvec2sp    ; signalling & CTCSS
               cpx  #OCI_OSC2
               beq  tosp_oscvec3      ; dual tone signalling & CTCSS
               cpx  #OCI_OSC3
               beq  tosp_oscvec3      ; dual tone signalling & CTCSS

               sei
               ldab #0
               stab tasksw_en         ; disable preemptive task switching
               ldab tick_ms+1
tosp_intloop
               cli
               nop                    ; don't remove these NOPs
               nop                    ; HD6303 needs at least 2 clock cycles between cli & sei
               sei                    ; otherwise interrupts aren't processed
               cmpb tick_ms+1
               beq  tosp_intloop
               ldab #1
               stab oci_int_ctr       ; Interrupt counter auf 1
                                      ; (Bit is left shifted during Audio OCI, on zero 1ms OCI will be executed)

               ldx  #OCI_OSC1_pl
               stx  oci_vec           ; OCI Interrupt Vektor 'verbiegen'
                                      ; Ausgabe startet automatisch beim nächsten OCI
                                      ; 1/8000 s Zeitintervall wird automatisch gesetzt
;               clr  tasksw_en         ; re-enable preemptive task switching

               ldx  #OCI_OSC1_pl      ; CTCSS NCO
               bra  tosp_setvec
tosp_oscvec2sp
               ldx  #OCI_OSC2_sp      ; signalling NCO & CTCSS NCO
               bra  tosp_setvec
tosp_oscvec3
               ldx  #OCI_OSC3         ; dual tone signalling NCO & CTCSS NCO
tosp_setvec
               stx  oci_vec           ; set new OCI interrupt vector
                                      ; output starts autonmatically with next 1 ms interrupt
                                      ; 1/8000 s interval is then set automatically
               cli
tosp_end
               pulx
               pula
               pulb
               rts

#ENDIF
;***********************
; C T C S S   S T A R T
;***********************
;
; Starts CTCSS tone oscillator
;
; calculates frequency from 'ctcss_index' and calls tone_start_pl
; preserve registers and save some stack memory by saving
; the regs ourselves and using jmp instead of jsr
;
ctcss_start
               pshb
               ldab ctcss_index        ; get CTCSS index
               beq  ctst_end           ; if frequency = 0, end here
               psha
               pshx
               lslb                    ; double index because to address 2 Byte table entries
               ldx  #ctcss_tab         ; get pointer to CTCSS frequency table
               abx                     ; add index
               ldd  0,x                ; get tone entry
               jmp  tosp_entry         ; else start output with selected frequency
ctst_end
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

               ldab Port5_DDR_buf
               orab #%00001000
               stab Port5_DDR_buf
               stab Port5_DDR

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

               ldd  #8000             ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus
               std  osc1_pd           ; Quotient = delta für phase

               ldx  #0
               pshx
               tsx
               ldx  2,x               ; Tonfrequenz 2/X holen
               pshx                   ; und auf Stack legen
               ldd  #8000             ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus
               std  osc2_pd           ; Quotient = delta für phase

               ldx  oci_vec           ; check if CTCSS/PL tone generator is active
               cpx  #OCI_OSC2
               beq  dts_end           ; correct vector is already set, goto exit
               cpx  #OCI_OSC1_sig
               beq  dts_oscvec2       ; dual tone signalling
               cpx  #OCI_OSC1_pl
               beq  dts_oscvec3       ; dual tone signalling & CTCSS
               cpx  #OCI_OSC2_sp
               beq  dts_oscvec3       ; dual tone signalling & CTCSS
               cpx  #OCI_OSC3
               beq  dts_oscvec3       ; dual tone signalling & CTCSS

#ifdef EVA5
               ldab Port6_DDR_buf
               andb #%10011111
               stab Port6_DDR_buf
               stab Port6_DDR
#endif
               ldab #0
               stab tasksw_en         ; disable preemptive task switching
               sei
               ldab tick_ms+1
dts_intloop
               cli
               nop                    ; don't remove these NOPs
               nop                    ; HD6303 needs at least 2 clock cycles between cli & sei
               sei                    ; otherwise interrupts aren't processed
               cmpb tick_ms+1
               beq  dts_intloop

#ifdef EVA9
               ldab #1
               stab oci_int_ctr       ; Interrupt counter auf 1
                                      ; (Bit is left shifted during Audio OCI, on zero 1ms OCI will be executed)
#endif
#ifdef EVA5
               ldab TCSR2
               ldd  OCR1
               std  OCR2
               subd #SYSCLK/1000
               addd #SYSCLK/1600      ; add 5 sample periods to ensure there is enough time
                                      ; before next interrupt occurs even on EVA9
               std  OCR1
#endif
               ldx  #OCI_OSC2         ; dual tone signalling NCO
               bra  dts_setvec
dts_oscvec2
               ldx  #OCI_OSC2         ; CTCSS/PL tone are to be generated, use triple tone nco
               bra  dts_setvec
dts_oscvec3
               ldx  #OCI_OSC3
dts_setvec
               stx  oci_vec           ; set new OCI interrupt vector
                                      ; output starts autonmatically with next 1 ms interrupt
                                      ; 1/8000 s interval is then set automatically
               cli
#ifdef EVA5
               ldab #1
               stab Port7_Data
#endif
dts_end
               pulx
               pula
               pulb
               rts
;***************************
; T O N E   S T O P   S I G
;***************************
;
; Disable signalling NCO (single and dual tone signalling)
; CTCSS NCO is not affected
;
tone_stop_sig
               pshb
               psha
               pshx

               ldx  oci_vec
               cpx  #OCI_OSC1_sig      ; check if only the signalling NCO was active
               beq  tsts_disable       ; and deactivate sound output completely
               cpx  #OCI_OSC2          ; check if only the signalling NCO was active
               beq  tsts_disable       ; and deactivate sound output completely
               cpx  #OCI_OSC2_sp       ; single tone signalling & CTCSS is active
               beq  tsts_osc1pl        ; keep CTCSS running
               cpx  #OCI_OSC3          ; dual tone signalling & CTCSS is active
               beq  tsts_osc1pl        ; keep CTCSS running
               bra  tsts_end           ; signalling NCO is not active, exit
tsts_osc1pl
               ldx  #OCI_OSC1_pl       ; otherwise CTCSS must be active, keep this one running
               bra  tsts_setvec
tsts_disable
               ldx  #OCI1_MS
tsts_setvec
               stx  oci_vec            ; OCI wieder auf Timer Interrupt zurücksetzen
                                       ; Zeitbasis für Timerinterrupt (1/1000 s) wird im Int zurückgestellt
                                       ; DAC wieder auf Mittelwert zurücksetzen
#ifdef EVA5
               ldab Port5_DDR_buf
               andb #%11110111
               stab Port5_DDR
               stab Port5_DDR_buf

               ldab Port6_DDR_buf
               andb #%10011111
               stab Port6_DDR
               stab Port6_DDR_buf

               ldaa Port6_Data
               anda #%10011111
               staa Port6_Data
#endif
#ifdef EVA9
               ldaa Port6_Data
               anda #%11110000
               oraa #%00001000
               staa Port6_Data
#endif
tsts_end
               pulx
               pula
               pulb
               rts

;*************************
; T O N E   S T O P   P L
;*************************
;
; Disables CTCSS NCO
; Signalling NCO(s) is/are not affected
;
tone_stop_pl
               pshb
               psha
               pshx

               ldx  oci_vec
               cpx  #OCI_OSC1_pl       ; check if only the signalling NCO was active
               beq  tstp_disable       ; and deactivate sound output completely
               cpx  #OCI_OSC2_sp       ; single tone signalling & CTCSS is active
               beq  tstp_osc1sig       ; keep single tone running
               cpx  #OCI_OSC3          ; dual-tone signalling & CTCSS is active
               beq  tstp_osc2          ; keep dual tone output running
               bra  tstp_end           ; CTCSS NCO is not active, exit
tstp_osc1sig
               ldx  #OCI_OSC1_sig
               bra  tstp_setvec        ; single tone signalling NCO
tstp_osc2
               ldx  #OCI_OSC2          ; dual-tone signalling NCO
               bra  tstp_setvec
tstp_disable
               ldx  #OCI1_MS
tstp_setvec
               stx  oci_vec            ; OCI wieder auf Timer Interrupt zurücksetzen
                                       ; Zeitbasis für Timerinterrupt (1/1000 s) wird im Int zurückgestellt
                                       ; DAC wieder auf Mittelwert zurücksetzen
#ifdef EVA5
               ldab Port5_DDR_buf
               andb #%11110111
               stab Port5_DDR
               stab Port5_DDR_buf

               ldab Port6_DDR_buf
               andb #%10011111
               stab Port6_DDR
               stab Port6_DDR_buf

               ldaa Port6_Data
               anda #%10011111
               staa Port6_Data
#endif
#ifdef EVA9
               ldaa Port6_Data
               anda #%11110000
               oraa #%00001000
               staa Port6_Data
#endif
tstp_end
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
               ;      A     B    C      D     *    #
               .dw $0003,$0103,$0203,$0303,$0300,$0302
               ;      * ,  D1    D2    D3/D  D4/C  D5    D6    D7/A  D8/B   #
               .dw $0300, $0000,$0000,$0303,$0203,$0000,$0000,$0003,$0103,$0302
dtmf_tab_x
               .dw 1209,1336,1477,1633
dtmf_tab_y
               .dw  697, 770, 852, 941
ctcss_tab
               .dw     0,  670,  694,  719,  744,  770,  797,  825,
               .dw 	 854,  885,  915,  948,  974, 1000, 1035, 1072,
               .dw 	1109, 1148, 1188, 1230, 1273, 1318, 1365, 1413,
               .dw 	1462, 1514, 1567, 1598, 1622, 1655, 1679, 1713,
               .dw 	1738, 1773, 1799, 1835, 1862, 1899, 1928, 1966,
               .dw 	1995, 2035, 2065, 2107, 2138, 2181, 2213, 2257,
               .dw 	2291, 2336, 2371, 2418, 2455, 2503, 2541

#ifdef EVA9
#include "audio_e9.asm"
#else
#include "audio_e5.asm"
#endif
