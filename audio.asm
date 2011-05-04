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

               ldaa osc_active                ; pr�fen ob Tone-Task bereits aktiv
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
               T_STARTP(s_tone_task,s_tone_term,40,5) ; UI in Taskliste h�ngen, 30 Byte Stack Speicher, 5 Byte Parameter
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
               stab ui_ptt_req                 ; falls gew�nscht, PTT Anforderung setzen
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
               swi                             ; Endlosschleife bis Task von au�en beendet wird
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

;               ldaa osc_active                ; pr�fen ob Tone-Task bereits aktiv
;               beq  dts_start                 ; wenn nicht starten
;               jsr  tcb_expand                ; sonst TCB Adresse berechnen
;               pshx
;               T_TERMOTHER                    ; und anderen Task freundlich beenden
;               pulx
dts_termwait
               ldaa osc_active                ; Warten bis Task beendet ist
               bne  dts_termwait              ; Ziel: 50ms Abstand zwischen 2 T�nen
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
               T_STARTP(d_tone_task,d_tone_term,40,8) ; UI in Taskliste h�ngen, 30 Byte Stack Speicher, 5 Byte Parameter
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
               stab ui_ptt_req                 ; falls gew�nscht, PTT Anforderung setzen
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
               swi                             ; Endlosschleife bis Task von au�en beendet wird
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
               std  osc1_pd           ; Quotient = delta f�r phase

               clr  oci_int_ctr       ; Interrupt counter auf 0
                                      ; (wird jeweils um 32 erh�ht, bei 0 wird normaler Timer Int ausgef�hrt)
               ldx  #OCI_OSC1
               stx  oci_vec           ; OCI Interrupt Vektor 'verbiegen'
                                      ; Ausgabe startet automatisch beim n�chsten OCI
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
               std  osc1_pd           ; Quotient = delta f�r phase

               ldx  #0
               pshx
               tsx
               ldx  2,x               ; Tonfrequenz 2/X holen
               pshx                   ; und auf Stack legen
               ldd  #32000            ; Divisor  = Samplefrequenz * 4
               jsr  divide32          ; equivalent (Frequenz*256) / 16
               pulx
               pulx                   ; 'kleiner' (16 Bit) Quotient reicht aus
               std  osc2_pd           ; Quotient = delta f�r phase

               clr  oci_int_ctr       ; Interrupt counter auf 0
                                      ; (wird jeweils um 32 erh�ht, bei 0 wird normaler Timer Int ausgef�hrt)

               ldx  #OCI_OSC2
               stx  oci_vec           ; OCI Interrupt Vektor 'verbiegen'
                                      ; Ausgabe startet automatisch beim n�chsten OCI
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
               stx  oci_vec            ; OCI wieder auf Timer Interrupt zur�cksetzen
                                       ; Zeitbasis f�r Timerinterrupt (1/1000 s) wird im Int zur�ckgestellt
               ldab #4
               ldx  #dac_out_tab
               abx                     ; DAC wieder auf Mittelwert zur�cksetzen
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

                addd #1194                 ; in einer ms wieder OCI ausf�hren
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
