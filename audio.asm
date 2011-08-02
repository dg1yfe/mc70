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
;               ldab TCSR2
;               ldd  OCR1
;               std  OCR2
;               subd #SYSCLK/1000
;               addd #499              ; add two sample periods to ensure there is enough time
                                      ; before next interrupt occurs even on EVA9
;               std  OCR1

               ldd  dac_8to3+128
               std  subaudiobuf
               std  subaudiobuf+(1*2 )
               std  subaudiobuf+(2*2 )
               std  subaudiobuf+(3*2 )
               std  subaudiobuf+(4*2 )
               std  subaudiobuf+(5*2 )
               std  subaudiobuf+(6*2 )
               std  subaudiobuf+(7*2 )
               std  subaudiobuf+(8*2 )
               std  subaudiobuf+(9*2 )
               std  subaudiobuf+(10*2)
               std  subaudiobuf+(11*2)

;               ldx  #OCI_OSC1
               ldx  #OCI_OSC1ns
               stx  oci_vec           ; OCI Interrupt Vektor 'verbiegen'
                                      ; Ausgabe startet automatisch beim nächsten OCI
                                      ; 1/8000 s Zeitintervall wird automatisch gesetzt
;               clr  tasksw_en         ; re-enable preemptive task switching
               ldd  #$AA55
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

               ldd  #48000            ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus
               std  osc1_pd           ; Quotient = delta für phase

               ldx  #0
               pshx
               tsx
               ldx  2,x               ; Tonfrequenz 2/X holen
               pshx                   ; und auf Stack legen
               ldd  #48000            ; Divisor  = Samplefrequenz * 4
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

               ldx  #OCI_OSC1ns
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

#ifdef EVA9
#include "audio_e9.asm"
#else
#include "audio_e5.asm"
#endif
