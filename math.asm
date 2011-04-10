;****************************************************************************
;
;    MC 70    v1.0.6 - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2010  Felix Erckenbrecht, DG1YFE
;
;
;****************************************************************************
;*********
; M A T H
;*********
;
; mathematische Funktionen, die nicht direkt von der CPU zur Verfügung gestellt werden
;
; last change : 02/2009
;
;***********************
; DIVIDE:
; Parameter:
;           D Dividend (16Bit)
;           X Divisor  (16Bit)
; Ergebnis:
;           D Quotient (16Bit)
;           X Rest     (16Bit)
;***********************
; DIVIDE32:
; Parameter:
;           D     Divisor  (16Bit)
;           Stack Dividend (32Bit)
; Ergebnis:
;           Stack Quotient (32Bit)
;           D Quotient-lo  (16Bit)
;           X Rest         (16Bit)
;***********************
; MULTIPLY:
; Parameter:
;           D Faktor   (16Bit)
;           X Faktor   (16Bit)
; Ergebnis:
;           X:D Produkt(32Bit)
;***********************
; MULTIPLY32:
; Parameter:
;           X:D   Faktor (32Bit)
;           Stack Faktor (32Bit)
; Ergebnis:
;           X:D Produkt  (32Bit)
;***********************
; ADD32:
; Parameter:
;           X:D   Summand (32Bit)
;           Stack Summand (32Bit)
; Ergebnis:
;           Stack Summe   (32Bit)
;***********************
; SUB32:
; Parameter:
;           Stack Minuend    (32Bit)
;           X:D   Subtrahend (32Bit)
; Ergebnis:
;           Stack Differenz  (32Bit)
;
;***********************
; SIG INV32
;
; Vorzeichenumkehr für 32 Bit Zahl
;
; Parameter:
;           X:D   Zahl  (32Bit)
; Ergebnis:
;           Not(Zahl)+1 (Vorzeichenumkehr)
;
;
;
;***********************
; RAISE
;
; Potenziert 2 mit Parameter
;
; Parameter:
;            B - Exponent (0-7)
; Ergebnis:
;            B - Potenz (Bereich 1 - 128 / 2^0 - 2^7 )
;



;************************
; D I V I D E
;************************
; Parameter:
;           D Dividend (16Bit)
;           X Divisor  (16Bit)
; Ergebnis:
;           D Quotient (16Bit)
;           X Rest     (16Bit)
;
; changed Regs: A,B,X
;
divide
               pshb
               psha                        ; Dividend speichern
               pshx                        ; Divisor speichern
               ldx  #$0001
               pshx                        ; Platz für Quotient auf Stack
               ldx  #0
               pshx                        ; Hilfsregister/Rest auf Stack
               tsx
                                           ; 0,1 - Hilfsreg
                                           ; 2,3 - Quotient
                                           ; 4,5 - Divisor
                                           ; 6,7 - Dividend
divide_loop
               lsl  7,x
               rol  6,x                    ; MSB von Dividend (Dividend / 2)
               ldd  0,x
               rolb                        ; in Hilfsregister
               rola                        ; schieben
               bcs  divide_subtract        ; MSB des Hilfsregisters = 1 ?
               subd 4,x                    ; Hilfsreg <= Divisor ? (Ersatz für nicht vorhandenen 'CMPD' Befehl)
               bcc  divide_sec
               addd 4,x                    ; Subtraktion rückgängig machen
               clc                         ; Carryflag löschen
               bra  divide_cont
divide_subtract
               subd 4,x                    ; Divisor von Dividend abziehen
divide_sec
               sec                         ; Carryflag setzen
divide_cont
               std  0,x                    ; Hilfsregister speichern
               rol  3,x                    ; Carry ins Ergebnis
               rol  2,x                    ; einfügen
               bcc  divide_loop            ; Solange bis die "1" als MSB erscheint weitermachen
               pulx                        ; Rest in X
               pula
               pulb                        ; Ergebnis in D
               ins
               ins
               ins
               ins                         ; Divisor und Dividend vom Stack löschen
               rts
;
;************************
; D I V I D E 3 2
;************************
; Parameter:
;           D     Divisor  (16Bit)
;           Stack Dividend (32Bit)
; Ergebnis:
;           Stack Quotient (32Bit)
;           D Quotient-lo  (16Bit)
;           X Rest         (16Bit)
;
;
; changed Regs: A,B,X
;
divide32
               tsx
               pshb
               psha                        ; Divisor speichern
               ldd  4,x                    ; Dividend LoWord holen
               pshb
               psha                        ; und speichern
               ldd  2,x                    ; Dividend HiWord holen
               pshb
               psha                        ; und speichern
               ldd  #0                     ; Hilfsregister löschen
               pshb                        ; Hilfsregister auf Stack
               psha

               tsx
               clr  10,x
               clr  11,x
               clr  12,x
               ldab #1
               stab 13,x                   ; Ergebnis kommt auf Stack, Bit0 setzen (Counter)
                                           ; 0,1 = Hilfsregister
                                           ; 2,3,4,5 = Dividend
                                           ; 6,7 = Divisor
                                           ; 8,9 = Return Adresse
                                           ; 10,11,12,13 = Ergebnis
divide32_loop
               lsl  5,x                    ; dividendl+1 - MSB von Dividend
               rol  4,x                    ; dividendl
               rol  3,x                    ; dividendh+1
               rol  2,x                    ; dividendh   - Dividend/2
               ldd  0,x                    ; Hilfsregister/Rest holen,
               rolb                        ; Bit in Hilfsregister/Rest
               rola                        ; schieben
               bcs  divide32_sub           ; MSB des Hilfsregisters = 1 ?
               subd 6,x                    ; Hilfsregister <= Divisor?
               bcc  divide32_sec           ; ja, dann Divisor subtrahieren
               addd 6,x                    ; Subtraktion rückgängig machen
               clc                         ; Carryflag löschen
               bra  divide32_cont
divide32_sub
               subd 6,x                    ; Divisor vom Hilfsregister/Rest abziehen
divide32_sec
               sec                         ; Carryflag setzen
divide32_cont
               std  0,x                    ; neues Hilfsregister speichern
               rol  13,x
               rol  12,x
               rol  11,x                   ; Carry ins Ergebnis
               rol  10,x                   ; einfügen
               bcc  divide32_loop          ; Loop bis '1' herausgeschoben wurde
                                           ; insgesamt 32 Bits verarbeiten
                                           ; Ergebnis auf Stack,
                                           ; Rest in Hilfsregister

               pula
               pulb                        ; Rest holen
               std   6,x                   ; und verschieben
               ldd  12,x                   ; LoWord des Ergebnis nach D
               pulx
               pulx                        ; Stack bereinigen
               pulx                        ; Rest der Division nach X
               rts

;************************
; D I V I D E 3 2 S
;************************
; Parameter:
;           D     Divisor  (16Bit)
;           Stack *Dividend(16Bit)
; Ergebnis:
;           Mem   Quotient (32Bit)
;           D Quotient-lo  (16Bit)
;           X Rest         (16Bit)
;
;
; changed Regs: A,B,X
;
divide32s
               tsx
               pshb
               psha                        ; Divisor speichern
               ldx  0+2,x                  ; Zeiger auf Dividend holen
               ldd  2,x                    ; Dividend LoWord holen
               pshb
               psha                        ; und speichern
               ldd  0,x                    ; Dividend HiWord holen
               pshb
               psha                        ; und speichern
               ldd  #0                     ; Hilfsregister/Rest löschen
               pshb                        ; Hilfsregister/Rest auf Stack
               psha

               tsx
               ldx  0+10,x
               clr  0,x
               clr  1,x
               clr  2,x
               ldab #1
               stab 3,x                    ; Ergebnis kommt auf Stack, Bit0 setzen (Counter)
                                           ; 0,1 = Hilfsregister
                                           ; 2,3,4,5 = Dividend
                                           ; 6,7 = Divisor
                                           ; 8,9 = Return Adresse
                                           ; 10,11,12,13 = Ergebnis
divide32s_loop
               tsx
               lsl  5,x                    ; dividendl+1 - MSB von Dividend
               rol  4,x                    ; dividendl
               rol  3,x                    ; dividendh+1
               rol  2,x                    ; dividendh   - Dividend/2
               ldd  0,x                    ; Hilfsregister/Rest holen,
               rolb                        ; Bit in Hilfsregister/Rest
               rola                        ; schieben
               bcs  divide32s_sub          ; MSB des Hilfsregisters = 1 ?
               subd 6,x                    ; Hilfsregister <= Divisor?
               bcc  divide32s_sec          ; ja, dann Divisor subtrahieren
               addd 6,x                    ; Subtraktion rückgängig machen
               clc                         ; Carryflag löschen
               bra  divide32s_cont
divide32s_sub
               subd 6,x                    ; Divisor vom Hilfsregister/Rest abziehen
divide32s_sec
               sec                         ; Carryflag setzen
divide32s_cont
               std  0,x                    ; neues Hilfsregister speichern
               ldx  0+10,x                 ; Zeiger auf Quotient holen
               rol  3,x
               rol  2,x
               rol  1,x                    ; Carry ins Ergebnis
               rol  0,x                    ; einfügen
               bcc  divide32s_loop         ; Loop bis '1' herausgeschoben wurde
                                           ; insgesamt 32 Bits verarbeiten
                                           ; Ergebnis auf Stack,
                                           ; Rest in Hilfsregister
               tsx
               pula
               pulb                        ; Rest holen
               std   6,x                   ; und verschieben
               ldx  0+10,x
               ldd  2,x                    ; LoWord des Ergebnis nach D
               pulx
               pulx                        ; Stack bereinigen
               pulx                        ; Rest der Division nach X
               rts
;************************
; D I V I D E 3 2 3 2
;************************
;
; Division mit 32 Bit Dividend UND 32 Bit Divisor
;
; Parameter:
;           Stack *Dividend(16Bit) (Zeiger auf Dividend)
;           Stack Divisor  (32Bit)
; Ergebnis:
;           Mem Quotient   (32Bit)
;           Stack Rest     (32Bit)
;           D Quotient Lo  (16Bit)
;           X Rest Lo      (16Bit)
;
;
; changed Regs: A,B,X
;
divide3232
               tsx
               ldx  4+2,x                  ; Zeiger auf Dividend holen
               ldd    2,x                  ; Dividend LoWord holen
               pshb
               psha                        ; und speichern
               ldd    0,x                  ; Dividend HiWord holen
               pshb
               psha                        ; und speichern

               ldx  #0                     ; Hilfsregister/Rest auf 0
               pshx
               pshx                        ; Hilfsregister/Rest auf Stack

               tsx
               ldx  4+10,x                 ; Zeiger auf Dividen (nun Quotient) holen
               clr  0,x
               clr  1,x
               clr  2,x
               ldab #1
               stab 3,x                    ; Ergebnis Bit0 setzen (Counter)
                                           ; 0,1,2,3 = Hilfsregister/Rest
                                           ; 4,5,6,7 = Dividend
                                           ; 8,9 = Return Adresse
                                           ; 10,11,12,13 = Divisor
                                           ; 14,15 = Zeiger auf Ergebnis
div3232_loop
               tsx
               lsl  7,x                    ; dividendl+1 - MSB von Dividend
               rol  6,x                    ; dividendl
               rol  5,x                    ; dividendh+1
               rol  4,x                    ; dividendh   - Dividend/2

               rol  3,x                    ; Bit in
               rol  2,x                    ; Hilfsregister/Rest
               rol  1,x                    ; schieben
               rol  0,x

               bcs  div3232_sub            ; MSB des Hilfsregisters/Rest = 1 ?

               ldd  2,x
               subd 12,x                   ; Rest <= Divisor?
               std  2,x

               ldab 1,x
               sbcb 11,x
               stab 1,x

               ldab 0,x
               sbcb 10,x
               stab 0,x

               bcc  div3232_sec            ; ja, dann Divisor subtrahieren
               ldd  2,x
               addd 12,x
               std  2,x

               ldab 1,x
               adcb 11,x
               stab 1,x

               ldab 0,x
               adcb 10,x
               stab 0,x                    ; Subtraktion rückgängig machen
               clc                         ; Carryflag löschen
               bra  div3232_cont
div3232_sub
                                            ; Divisor von Hilfsregister/Rest abziehen
               ldd  2,x
               subd 12,x
               std  2,x

               ldab 1,x
               sbcb 11,x
               stab 1,x

               ldab 0,x
               sbcb 10,x
               stab 0,x                     ; neues Hilfsregister/neuen Rest speichern
div3232_sec
               sec                         ; Carryflag setzen
div3232_cont
               ldx  4+10,x
               rol  3,x
               rol  2,x
               rol  1,x                    ; Carry ins Ergebnis
               rol  0,x                    ; einfügen
               bcc  div3232_loop           ; Loop bis '1' herausgeschoben wurde
                                           ; insgesamt 32 Bits verarbeiten
                                           ; Ergebnis auf Stack,
                                           ; Rest in Hilfsregister
               tsx
               pula
               pulb                        ; Rest holen
               std  0+10,x                 ; und anstelle des Divisors
               pula
               pulb
               std  2+10,x                 ; speichern

               ldx  4+10,x
               ldd  2,x                    ; LoWord des Ergebnis nach D
               tsx
               ldx  2+6,x                  ; LoWord vom Rest nach X
               ins
               ins
               ins
               ins                         ; Stack bereinigen
               rts

;************************
; M U L T I P L Y
;************************
; Parameter:
;           D Faktor   (16Bit)
;           X Faktor   (16Bit)
; Ergebnis:
;           X:D Produkt(32Bit)
;
; changed Regs: A,B,X
;
;
multiply
               pshb                 ; Faktor 1 LoByte auf Stack
               psha                 ; Faktor 1 HiByte auf Stack
               pshx                 ; Faktor 2 auf Stack
               ldx  #0
               pshx
               pshx                 ; Produkt

                                    ; 0,1,2,3 = Produkt
                                    ; 4,5 = Faktor 2
                                    ; 6,7 = Faktor 1
               tsx
               ldaa 5,x             ; F2L
               mul                  ; F1L*F2L
               std  2,x

               ldab 6,x             ; HiByte Faktor1
               ldaa 5,x             ; LoByte Faktor2
               mul
               addd 1,x
               std  1,x
               rol  0,x
               ldab 7,x             ; LoByte Faktor1
               ldaa 4,x             ; HiByte Faktor2
               mul
               addd 1,x
               std  1,x
               ldaa 0,x
               adca #0              ; Add Carry
               staa 0,x

               ldab 6,x             ; HiByte Faktor1
               ldaa 4,x             ; HiByte Faktor2
               mul
               addd 0,x
               std  0,x
multiply_end
               ldd  2,x             ; Ergebnis LoWord verschieben
               std  6,x
               ldd  0,x             ; Ergebnis HiWord verschieben
               std  4,x
               pulx
               pulx
               pulx                 ; Hi Word holen
               pula
               pulb                 ; Lo Word holen
               rts
;************************
; M U L T I P L Y 3 2
;************************
; Parameter:
;           X:D   Faktor (32Bit)
;           Stack Faktor (32Bit)
; Ergebnis:
;           X:D Produkt  (32Bit)
;           Stack Produkt(32Bit)
;
; changed Regs: A,B,X
multiply32
;        a4  a3  a2  a1 *b4  b3  b2  b1
;   ------------------------------------
;        8   7   6   5 | 4   3   2   1
;                      |        b 1 a 1
;                      |    b 1 a 2
;                      |b 1 a 3
;                   b 1|a 4
;                      |    b 2 a 1
;                      |b 2 a 2
;                   b 2|a 3
;                      |b 3 a 1
;                   b 3|a 2
;                   b 4|a 1
;
;
               pshb
               psha
               pshx                 ; save factor2
;********
               ldx  #0
               pshx
               pshx                 ; Platz für Produkt

                                    ; 0,1,2,3 = Produkt
                                    ; 4,5,6,7 = Faktor 2
                                    ; 8,9 = Ret Adr
                                    ; 10,11,12,13 = Faktor 1
               tsx
;--- b1
               ldaa 13,x            ; LoWord/LoByte Faktor1 - a1
                                    ; LoWord/LoByte Faktor2 - b1
               mul                  ; (b1a1)
               std  2,x

               ldaa 12,x            ; LoWord/HiByte Faktor1 - a2
               ldab 7,x             ; LoWord/LoByte Faktor2 - b1
               mul                  ; (b1a2)
               addd 1,x             ; zum Zwischenergebnis addieren
               std  1,x             ; und speichern
;               rol  0,x             ; eventuellen Übertrag einfügen (beim ersten Mal tritt noch kein Überlauf auf)
               ldaa 11,x            ; HiWord/LoByte Faktor1 - a3
               ldab 7,x             ; LoWord/LoByte Faktor2 - b1
               mul                  ; (b1a3)
               addd 0,x
               std  0,x

               ldaa 10,x            ; HiWord/HiByte Faktor1 - a4
               ldab 7,x             ; LoWord/LoByte Faktor2 - b1
               mul                  ; (b1a4)
               addb 0,x             ; Nur noch Low Byte speichern
               stab 0,x
;--- b2
               ldaa 13,x            ; LoWord/LoByte Faktor1 - a1
               ldab 6,x             ; LoWord/HiByte Faktor2 - b2
               mul                  ; (b2a1)
               addd 1,x             ; zum Zwischenergebnis addieren
               std  1,x             ; und speichern
               ldaa #0
               adca 0,x             ; Übertrag
               staa 0,x             ; berücksichtigen

               ldaa 12,x            ; LoWord/LoByte Faktor1 - a2
               ldab 6,x             ; LoWord/HiByte Faktor2 - b2
               mul                  ; (b2a2)
               addd 0,x             ; addiere Zwischenergebnis
               std  0,x             ; speichern

               ldaa 11,x            ; LoWord/LoByte Faktor1 - a3
               ldab 6,x             ; HiWord/HiByte Faktor2 - b2
               mul                  ; (b2a3)
               addb 0,x             ; Nur noch Low Byte addieren
               stab 0,x             ; und speichern

;--- b3
               ldaa 13,x            ; LoWord/HiByte Faktor1 - a1
               ldab 5,x             ; LoWord/HiByte Faktor2 - b3
               mul                  ; (b3a1)
               addd 0,x             ; zum Zwischenergebnis addieren
               std  0,x             ; und speichern

               ldaa 12,x            ; LoWord/HiByte Faktor1 - a2
               ldab 5,x             ; HiWord/LoByte Faktor2 - b3
               mul                  ; (b3a2)
               addb 0,x             ; Nur noch Low Byte addieren
               stab 0,x             ; und speichern
;--- b4
               ldaa 13,x            ; LoWord/LoByte Faktor1 - a1
               ldab 4,x             ; HiWord/HiByte Faktor2 - b4
               mul                  ; (b2a3)
               addb 0,x             ; Nur noch Low Byte addieren
               stab 0,x             ; und speichern
multiply32_end
               tsx
               pula
               pulb                 ; get result HiWord
               std  10,x            ; write to Stack
               pula
               pulb                 ; get result / LoWord
               std  12,x            ; write to Stack
               ins                  ; clear temporary storage
               ins
               ins
               ins
               ldx  10,x            ; load result / HiWord to X
               rts

exp10_9
               .dw $3b9a,$ca00
exp10          ; Tabelle um 10 zu potenzieren - 32Bit Einträge
               .dw $05f5,$e100  ;10^8
               .dw $0098,$9680  ;10^7
               .dw $000F,$4240  ;10^6
               .dw $0001,$86a0  ;10^5
               .dw     0,10000  ;10^4
               .dw     0,1000   ;10^3
               .dw     0,100    ;10^2
               .dw     0,10     ;10^1
               .dw     0,1      ;10^0

;***********
; A D D 3 2
;***********
; Parameter:
;           X:D   Summand (32Bit)
;           Stack Summand (32Bit)
; Ergebnis:
;           Stack Summe   (32Bit)
;
; changed Regs: A,B,X
;
add32
               pshx                 ; HiWord des 1. Summanden sichern
               tsx                  ; Stackpointer nach X
               addd 6,x             ; LoWord / 1.Summand + LoWord / 2.Summand
               std  6,x             ; LoWord speichern

               pula                 ; HiWord/HiByte 1. Summand holen
               pulb                 ; HiWord/LoByte 1. Summand holen
               adcb 5,x             ; + HiWord/LoByte 2. Summand
               stab 5,x             ; HiWord/LoByte speichern

                                    ; HiWord/HiByte 1. Summand
               adca 4,x             ; + HiWord/HiByte 2. Summand
               staa 4,x             ; HiWord/HiByte speichern

               rts
;*************
; A D D 3 2 S
;*************
; Parameter:
;           X     *Summand (32Bit)
;           Stack  Summand (32Bit)
; Ergebnis:
;           X     *Summe   (32Bit)
;
; changed Regs: A,B
;
; changed Mem : X
;
;
; 4 - Summand2
; 2 - *Return
; 0 - *Summand1
add32s
               pshx                 ; Pointer auf 1. Summanden sichern
               ldd  2,x             ; LoWord/1. Summand
               tsx                  ; Stackpointer nach X
               addd 6,x             ; LoWord / 1.Summand + LoWord / 2.Summand
               ldx  0,x             ; Pointer auf 1. Summanden holen
               std  2,x             ; LoWord speichern
               ldd  0,x             ; HiWord 1. Summand holen
               tsx
               adcb 5,x             ; + HiWord/LoByte 2. Summand
               ldx  0,x             ; Pointer auf 1. Summanden holen
               stab 1,x             ; HiWord/LoByte speichern
               tsx
                                    ; HiWord/HiByte 1. Summand
               adca 4,x             ; + HiWord/HiByte 2. Summand
               ldx  0,x             ; Pointer auf 1. Summanden holen
               staa 0,x             ; HiWord/HiByte speichern
               pulx
               rts

;***********
; S U B 3 2
;***********
; Parameter:
;           Stack Minuend    (32Bit)
;           X:D   Subtrahend (32Bit)
; Ergebnis:
;           Stack Differenz  (32Bit)
;
sub32
               pshb
               psha                 ; LoWord des Subtrahenden sichern
               pshx                 ; HiWord des Subtrahenden sichern
               tsx                  ; Stackpointer nach X
               ldd  8,x             ; LoWord / Minuend holen
               subd 2,x             ; LoWord / Minuend - LoWord / Subtrahend
               std  8,x             ; LoWord speichern

               ldd  6,x             ; HiWord / Minuend holen

               sbcb 1,x             ; - HiWord/LoByte Subtrahend
               stab 7,x             ; HiWord / LoByte speichern

               sbca 0,x             ; - HiWord/HiByte Subtrahend
               staa 6,x             ; HiWord / HiByte speichern

               pulx
               pula
               pulb
               rts

;*******************
; S I G   I N V 3 2
;*******************
;
; Vorzeichenumkehr
;
; Parameter:
;           X:D   Zahl  (32Bit)
; Ergebnis:
;           Not(Zahl)+1 (Vorzeichenumkehr)
;
sig_inv32
               coma
               comb                 ; LoWord invertieren
               xgdx
               pshx                 ; und auf Stack schieben
               coma
               comb                 ; HiWord invertieren
               xgdx
               pshx                 ; und auf Stack schieben
               ldd  #1
               ldx  #0              ; 1 addieren
               jsr  add32
               pulx
               pula                 ; Ergebnis holen
               pulb

               rts
;*********************
; S I G   I N V 3 2 S
;*********************
;
; Vorzeichenumkehr
;
; Parameter:
;           X   Pointer to int32_t
; Ergebnis:
;           -1*(*X)
;
; changed Regs: A,B
;
; changed Mem : *X
sig_inv32s
               pshx
               ldd  2,x
               coma
               comb                 ; LoWord invertieren
               std  2,x
               ldd  0,x
               coma
               comb                 ; HiWord invertieren
               std  0,x
               ldab  #1
               pshb
               clrb
               pshb
               pshb
               pshb
               jsr  add32s
               pulx
               pula
               pulb
               pulx
               rts
;************
; R A I S E
;************
;
; Potenziert 2 mit Parameter
;
; Parameter: B - Exponent (0-7)
;
; Ergebnis:  B - Potenz (Bereich 1 - 128, 2^0 - 2^7 )
;
;
raise
               psha

               clra
               sec                  ; Carry setzen
rse_loop
               rola                 ; Bit in A schieben (*2)
               decb                 ; Exponent--
               bpl  rse_loop        ; Wenn $FF erreicht -> Ende

               tab
               pula
               rts
