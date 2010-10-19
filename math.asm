;****************************************************************************
;
;    MC 70    v1.0.5 - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2008  Felix Erckenbrecht, DG1YFE
;
;
;****************************************************************************
;*********
; M A T H
;*********
;
; mathematische Funktionen, die nicht direkt von der CPU zur Verf�gung gestellt werden
;
; last change : 22.05.2008
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
; Vorzeichenumkehr f�r 32 Bit Zahl
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
               pshx                        ; Platz f�r Quotient auf Stack
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
               subd 4,x                    ; Hilfsreg <= Divisor ? (Ersatz f�r nicht vorhandenen 'CMPD' Befehl)
               bcc  divide_sec
               addd 4,x                    ; Subtraktion r�ckg�ngig machen
               clc                         ; Carryflag l�schen
               bra  divide_cont
divide_subtract
               subd 4,x                    ; Divisor von Dividend abziehen
divide_sec
               sec                         ; Carryflag setzen
divide_cont
               std  0,x                    ; Hilfsregister speichern
               rol  3,x                    ; Carry ins Ergebnis
               rol  2,x                    ; einf�gen
               bcc  divide_loop            ; Solange bis die "1" als MSB erscheint weitermachen
               pulx                        ; Rest in X
               pula
               pulb                        ; Ergebnis in D
               ins
               ins
               ins
               ins                         ; Divisor und Dividend vom Stack l�schen
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
               ldd  #0                     ; Hilfsregister l�schen
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
               ldd  0,x                    ; Hilfsregister holen,
               rolb                        ; Bit in Hilfsregister
               rola                        ; schieben
               bcs  divide32_sub           ; MSB des Hilfsregisters = 1 ?
               subd 6,x                    ; Hilfsregister <= Divisor?
               bcc  divide32_sec           ; ja, dann Divisor subtrahieren
               addd 6,x                    ; Subtraktion r�ckg�ngig machen
               clc                         ; Carryflag l�schen
               bra  divide32_cont
divide32_sub
               subd 6,x                    ; Divisor von Dividend abziehen
divide32_sec
               sec                         ; Carryflag setzen
divide32_cont
               std  0,x                    ; neues Hilfsregister speichern
               rol  13,x
               rol  12,x
               rol  11,x                   ; Carry ins Ergebnis
               rol  10,x                   ; einf�gen
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
;
;
; changed Regs: A,B,X
multiply32
               pshb
               psha
               pshx                 ; save factor2
               tsx
               ldx  8,x             ; LoWord Faktor1
                                    ; D = LoWord Faktor2
               jsr  multiply        ; multiply
               pshb
               psha
               pshx                 ; Store Result in temporary space

;               jmp  multiply32_end

               tsx
               ldd   4,x            ; HiWord Faktor1
               ldx  12,x            ; LoWord Faktor2
               jsr  multiply
               tsx
               addd  0,x            ; add result up
               std   0,x
               ldd   6,x            ; LoWord Faktor1
               ldx  10,x            ; HiWord Faktor2
               jsr  multiply
               tsx
               addd  0,x            ; add result up
               xgdx
multiply32_end
               ins
               ins
               pula
               pulb                 ; get result
               ins
               ins
               ins
               ins
               rts


exp10          ; Tabelle um 10 zu potenzieren - 32Bit Eintr�ge
               .dw $05F5,$E100  ;10^8
               .dw $0098,$9680  ;10^7
               .dw $000F,$4240  ;10^6
               .dw $0001,$86A0  ;10^5
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
               pula
               pulb                 ; Ergebnis holen

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
