;****************************************************************************
;
;    MC 70    v2.0.0 - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2008  Felix Erckenbrecht, DG1YFE
;
;
;****************************************************************************
;**************************
; S   T O N E   S T A R T
;**************************
;
; Tonausgabe (single tone) starten
;
; Parameter : X - Frequenz
;             Stack - DauerL
;             Stack - DauerH (0 = unbegrenzt)
;             Stack - Sender tasten (1 = Sender tasten)
;
s_tone_start
               pshb
               psha
               pshx

               ldaa osc_active                ; prüfen ob Tone-Task bereits aktiv
               beq  sts_start                 ; wenn nicht, dann neu starten
               jsr  tcb_expand                ; sonst TCB Adresse berechnen
               pshx
               T_TERMOTHER                    ; und anderen Task freundlich beenden
               pulx                           ; Ziel Ton bei mehrfachem Aufruf durchgehend
sts_start
               tsx
               ldd  1+6,x                     ; Dauer holen
               pshb
               psha                           ; als Parameter auf Stack
               ldx  0,x                       ; Frequenz holen
               pshx                           ; als Parameter auf Stack
               tsx
               ldab 0+6+4,x                   ; PTT Request holen
               pshb                           ; PTT Request auf Stack legen (Parameter)

;T_STARTP(addr,term,size,pcount)
               T_STARTP(s_tone_task,s_tone_term,40,5) ; UI in Taskliste hängen, 30 Byte Stack Speicher, 5 Byte Parameter
               jsr  tcb_shrink
               staa osc_active
               ins
               ins
               ins
               ins
               ins
sts_end
               pulx
               pula
               pulb
               rts

;************************
; S   T O N E   T A S K
;************************
;
; last change: 15.2.08 / 2.0.0
;
; Parameter: Stack - PTT Request   (4)
;                    Dauer [ms]    (2)
;                    Frequenz [Hz] (0)
; Ergebnis:  none
;
;
;Heap variablen
#DEFINE STONE_ptt_req TCBSize+0
;#DEFINE STONE_duration TCBSize+2
;
s_tone_task
               pulb
               stab ui_ptt_req                 ; falls gewünscht, PTT Anforderung setzen
               pula
               pulb                            ; Frequenz holen
               jsr  tone_start                 ; Tonausgabe starten
               pulx                            ; Dauer holen
               cpx  #0                         ; Dauer = 0 ?
               beq  stne_perm                  ; Dann Ton dauerhaft aussenden
               jsr  wait_ms                    ; Zeit in X [ms] abwarten
               jsr  tone_stop                  ; Tonoszillator stoppen
               clrb
               stab ui_ptt_req
stne_end
               clr  osc_active
               rts                             ; Task beenden
s_tone_term
               clr  osc_active
               jmp  task_term_self             ; Task beenden
stne_perm
               swi                             ; Endlosschleife bis Task von außen beendet wird
               bra  stne_perm

;**************************
; D   T O N E   S T A R T
;**************************
;
; Tonausgabe (dual tone) starten
;
; Parameter : X - Frequenz1
;             D - Frequenz2
;             Stack - DauerL
;             Stack - DauerH (0 = unbegrenzt)
;             Stack - Sender tasten (1 = Sender tasten)
;             Stack - Wait Request  ([ms] Stille nach Oszillator Deaktivierung)
d_tone_start
               pshb
               psha
               pshx

;               ldaa osc_active                ; prüfen ob Tone-Task bereits aktiv
;               beq  dts_start                 ; wenn nicht starten
;               jsr  tcb_expand                ; sonst TCB Adresse berechnen
;               pshx
;               T_TERMOTHER                    ; und anderen Task freundlich beenden
;               pulx
dts_termwait
               ldaa osc_active                ; Warten bis Task beendet ist
               bne  dts_termwait              ; Ziel: 50ms Abstand zwischen 2 Tönen
dts_start
               tsx
               ldd  2+6,x                     ; Dauer holen
               pshb
               psha                           ; als Parameter auf Stack
               ldd  0,x                       ; Frequenz1 holen
               pshb
               psha                           ; als Parameter auf Stack
               ldx  2,x                       ; Frequenz 2 holen
               pshx                           ; als Parameter auf Stack
               tsx
               ldd  0+6+6,x                   ; PTT & Wait Request holen
               pshb                           ; PTT Request auf Stack legen (Parameter)
               psha                           ; Wait Request auf Stack
;T_STARTP(addr,term,size,pcount)
               T_STARTP(d_tone_task,d_tone_term,40,8) ; UI in Taskliste hängen, 30 Byte Stack Speicher, 5 Byte Parameter
               jsr  tcb_shrink
               staa osc_active
               tsx
               xgdx
               addd #8
               xgdx
               txs
dts_end
               pulx
               pula
               pulb
               rts

;************************
; D   T O N E   T A S K
;************************
;
; last change: 15.2.08 / 2.0.0
;
; Parameter: Stack - Dauer [ms]     (6)
;                    Frequenz2 [Hz] (5)
;                    Frequenz1 [Hz] (3)
;                    PTT Request    (2)
;                    Wait Request   (1)
; Ergebnis:  none
;
;
;
#DEFINE DttPttReq    0 + TCBSize
#DEFINE DttWaitTime  0 + TCBSize
#DEFINE DTT_HEAP_END 2 + TCBSize
d_tone_task
               pulb
               stab DttWaitTime,x
               pulb
               stab DttPttReq,x
               beq  dtt_no_ptt
               stab ui_ptt_req                 ; falls gewünscht, PTT Anforderung setzen
dtt_no_ptt
               pula
               pulb                            ; Frequenz1 holen
               pulx                            ; Frequenz2 holen
               jsr  dtone_start                ; Tonausgabe starten
               pulx
               cpx  #0                         ; Dauer = 0 ?
               beq  dtt_end                    ; Dann Ton dauerhaft aussenden
               jsr  wait_ms                    ; Zeit in X [ms] abwarten
               jsr  tone_stop                  ; Tonoszillator stoppen
               ldx  current_task
               ldab DttPttReq,x
               beq  dtt_end
               clrb
               stab ui_ptt_req
dtt_end
               ldx  current_task
               ldab DttWaitTime,x
               beq  dtt_dont_wait
               clra
               xgdx
               jsr  wait_ms
dtt_dont_wait
               clr  osc_active
               rts                             ; Task beenden
d_tone_term
               clr  osc_active
               jmp  task_term_self             ; Task beenden
dtne_perm
               swi                             ; Endlosschleife bis Task von außen beendet wird
               bra  dtne_perm
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

               clr  oci_int_ctr       ; Interrupt counter auf 0
                                      ; (wird jeweils um 32 erhöht, bei 0 wird normaler Timer Int ausgeführt)
               ldx  #OCI_OSC1
               stx  oci_vec           ; OCI Interrupt Vektor 'verbiegen'
                                      ; Ausgabe startet automatisch beim nächsten OCI
                                      ; 1/8000 s Zeitintervall wird automatisch gesetzt
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

               clr  oci_int_ctr       ; Interrupt counter auf 0
                                      ; (wird jeweils um 32 erhöht, bei 0 wird normaler Timer Int ausgeführt)

               ldx  #OCI_OSC2
               stx  oci_vec           ; OCI Interrupt Vektor 'verbiegen'
                                      ; Ausgabe startet automatisch beim nächsten OCI
                                      ; 1/8000 s Zeitintervall wird automatisch gesetzt
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
               ldx  #OCI_MS
               stx  oci_vec            ; OCI wieder auf Timer Interrupt zurücksetzen
                                       ; Zeitbasis für Timerinterrupt (1/1000 s) wird im Int zurückgestellt
               ldab #4
               ldx  #dac_out_tab
               abx                     ; DAC wieder auf Mittelwert zurücksetzen
               ldd  0,x
               orab Port6_DDR_buf
               stab Port6_DDR
               andb #%10011111
               stab Port6_DDR_buf
               tab
               ldaa Port6_Data
               anda #%10011111
               aba
               staa Port6_Data

               pulx
               pula
               pulb
               rts

;
;**********************
; D A   S T A R T
;**********************
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
da_start
                pshb
                psha
                pshx

                tsx
                ldd  6,x
                std  smp_start
                std  smp_addr
                ldd  8,x
                std  smp_end

                pulx
                pshx
                std  smp_rpt

                tsx
                ldaa 2,x
                beq  das_play_zero
                deca
                beq  das_play_one
                ldx  #OCI_DAC_S2
                stx  oci_vec
                bra  das_end
das_play_zero
                ldx  #OCI_DAC_S0
                stx  oci_vec
                bra  das_end
das_play_one
                ldx  #OCI_DAC_S1
                stx  oci_vec
das_end
                pulx
                pula
                pulb
                rts

;********************
; D A   S T O P
;********************
;
;
;
da_stop
                sei
                ldx  smp_end
                stx  smp_addr

                addd #1194                 ; in einer ms wieder OCI ausführen
                std  OCR1
                oim  #%00001000, TCSR1     ; Timer compare Interrupt aktivieren
                aim  #%10011111, Port6_Data; Pin auf 0 setzen
                rts
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
OCI_OSC1                            ;   +19
               ldd  osc1_phase      ;+3  22    Phase holen (16 Bit)
               addd osc1_pd         ;+4  26    phasen delta addieren
               std  osc1_phase      ;+4  30    phase speichern
               anda #$3F            ;+2  32    nur Bits 0-5 berücksichtigen (0-63)

;               ldx  #sin_tab8       ;+3  35    Start der Sinustabelle holen (min=0, max=7)
;               tab                  ;+1  36
;               abx                  ;+1  37    Index addieren
;               ldab 0,x             ;+4  41    Sinuswert holen
;               lslb                 ;+1  42    *2
;               andb #%00001110      ;+2  46    ; Bits 3-1 filtern
;               ldx  #dac_out_tab    ;+3  49    ; DAC output Tabelle
;               abx                  ;+1  50    ; indizieren
;               ldd  0,x             ;+5  55    ; um Werte für die Ports zu holen

               ldx  #dac_sin_tab    ;+3  35    Start der Sinus-outputtabelle holen
               tab                  ;+1  36
               abx                  ;+1  37    Index addieren
               ldd  0,x             ;+5  42    Sinus-Ausgabewert holen

               orab Port6_DDR_buf   ;+3  58 45 ; DAC Wert ausgeben
               stab Port6_DDR       ;+3  61 48
               andb #%10011111      ;+2  63 50
;              stab Port6_DDR_buf   ;+3  66
               tab                  ;+1  67 51
               ldaa Port6_Data      ;+3  70
               anda #%10011111      ;+2  72
               aba                  ;+1  73
               staa Port6_Data      ;+3  76
               ldab TCSR2           ;+3  79    ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  83
               addd #249            ;+3  86    ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4  90
               rol  oci_int_ctr     ;+6  96 80  ; Interrupt counter lesen
               bne  oos1_end        ;+3  99 83  ; wenn Ergebnis <> 0, dann Ende
               jmp  OCI_MAIN        ;+3 102 86  ; bei 0 (jeden 8. Int) den Timer Int aufrufen
oos1_end
               rti                 ;+10 109 93
;*****************
;digital double tone Oscillator
;
OCI_OSC2                            ;   +19    Ausgabe Stream1 (Bit 0-2)
               ldd  osc1_phase      ;+4  23    ; 16 Bit Phase 1 holen
               addd osc1_pd         ;+4  27    ; 16 Bit delta phase 1 addieren
               std  osc1_phase      ;+4  31    ; und neuen Phasenwert 1 speichern
               ldx  #sin_tab8       ;+3  34    ; Sinustabelle indizieren
               tab                  ;+1  35
               abx                  ;+1  36

               ldd  osc2_phase      ;+4  40    ; 16 Bit Phase 2 holen
               addd osc2_pd         ;+4  44    ; 16 Bit delta Phase 2 addieren
               std  osc2_phase      ;+4  48    ; neuen Phasenwert 2 speichern
               tab                  ;+1  49

               ldaa 0,x             ;+4  53    ; Tabelleneintrag 1 holen

               ldx  #sin_tab8       ;+3  56    ; Sinustabelle (Wertebereich 0-7)
               abx                  ;+1  57
               ldab 0,x             ;+4  61    ; Tabelleneintrag 2 holen

               aba                  ;+1  62    ; Tabelleneintrag 1 addieren
               anda #%1110          ;+2  64    ; Bits 3-1 filtern
               ldx  #dac_out_tab_rev;+3  67    ; DAC Werte ausgeben
               tba                  ;+1  68
               abx                  ;+1  69    ; Table entry address in X

               ldaa Port6_DDR_buf   ;+3  72
               ldab Port6_Data      ;+3  75
               andb #%10011111      ;+2  77
               addd 0,x             ;+5  82    ; use ADD as OR
               std  Port6_DDR       ;+4  86    ; Store to DDR & Data

               ldab TCSR2           ;+3  89     ; Timer Control / Status Register 2 lesen
               ldd  OCR1            ;+4  93
               addd #249            ;+3  96     ; ca 8000 mal pro sek Int auslösen
               std  OCR1            ;+4 100
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
; EVA5 / 7977600 Hz Xtal
;     -> 1994400 Hz E2 clock
;     -> 249 * 8000 Hz (NCO clock)       CPU load EVA5 = (1* 55,8 % + 7* 47,8 %) / 8 = 48,7 % average
;                                        (reduces effective CPU speed for program to ~971 kHz)
;
; EVA9 / 4924600 Hz Xtal
;     -> 1231150 Hz E2 clock
;     -> 154 * 8000 Hz (NCO clock)       CPU load EVA9 = (1* 90,2 % + 7* 77,3 %) / 8 = 78,9 % average
;                                        (reduces effective CPU speed for program to ~260 kHz)


dac_out_tab
               .dw $0040 ; 1,25   0-  0
               .dw $0020 ; 1,67   -0  1
               .dw $2060 ; 2,0    01  2
               .dw $0000 ; 2,5    --  3
               .dw $4060 ; 3,0    10  4
               .dw $2020 ; 3,33   -1  5
               .dw $4040 ; 3,75   1-  6
               .dw $6060 ; 4,00   11  7
dac_out_tab_rev
               .dw $4000 ; 1,25   0-  0
               .dw $2000 ; 1,67   -0  1
               .dw $6020 ; 2,0    01  2
               .dw $0000 ; 2,5    --  3
               .dw $6040 ; 3,0    10  4
               .dw $2020 ; 3,33   -1  5
               .dw $4040 ; 3,75   1-  6
               .dw $6060 ; 4,00   11  7

dac_sin_tab
               .dw $0000, $4060, $4060, $4060, $2020, $2020, $2020, $4040,
               .dw $4040, $6060, $6060, $6060, $6060, $6060, $6060, $6060,
               .dw $6060, $6060, $6060, $6060, $6060, $6060, $6060, $6060,
               .dw $4040, $4040, $2020, $2020, $2020, $4060, $4060, $4060,
               .dw $0000, $0000, $0000, $2060, $2060, $2060, $0020, $0020,
               .dw $0020, $0040, $0040, $0040, $0040, $0040, $0040, $0040,
               .dw $0040, $0040, $0040, $0040, $0040, $0040, $0040, $0040,
               .dw $0020, $0020, $0020, $2060, $2060, $2060, $0000, $0000

sin_tab8       ;    1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
               .db  3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 7, 7, 7, 7, 7
               .db  7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 5, 5, 5, 4, 4, 4
               .db  3, 3, 3, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0
               .db  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3

               .db  3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 7, 7, 7, 7, 7
               .db  7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 5, 5, 5, 4, 4, 4
               .db  3, 3, 3, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0
               .db  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3

               .db  3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 7, 7, 7, 7, 7
               .db  7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 5, 5, 5, 4, 4, 4
               .db  3, 3, 3, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0
               .db  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3

               .db  3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 7, 7, 7, 7, 7
               .db  7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 5, 5, 5, 4, 4, 4
               .db  3, 3, 3, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0
               .db  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3
