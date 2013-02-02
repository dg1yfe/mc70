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
;*********
; M A T H
;*********
;
; mathematische Funktionen, die nicht direkt von der CPU zur Verfügung gestellt werden
;
; last change : 04/2011
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
; required Stack Space : 10 Byte
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
; required Stack Space : 10 Byte
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
;           Stack *Dividend(32Bit)
; Ergebnis:
;           Mem   Quotient (32Bit)
;           D Quotient-lo  (16Bit)
;           X Rest         (16Bit)
;
;
; changed Regs: A,B,X
;
; required Stack Space : 10 Byte
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
; required Stack Space : 10 Byte
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
; required Stack Space : 10 Byte
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
;
; required Stack Space : 10 Byte
;
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

;************************
; M U L T I P L Y 3 2 P
;************************
; Parameter:
;           X    *Faktor 1 (32Bit)
;           D    *Faktor 2 (32Bit)
; Ergebnis:
;         Mem    *Produkt  (32Bit)
;
; changed Regs: A,B
;
; required Stack Space : 10 Byte
;
multiply32p
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
               pshx
               pshx                 ; allocate temp. memory for product

               pshx                 ; save ptr to factor1
               pshb
               psha                 ; save ptr to factor2
;********
               clra
               clrb
               tsx
               std  4,x             ; clear hi word of temp. memory
                                    ; 0,1 = ptr to factor 2
                                    ; 2,3 = ptr to factor 1 / product
                                    ; 4,5,6,7 = temp. product

               ldx  2,x             ; get pointer to factor 1
               ldab 0,x
               orab 1,x
               orab 2,x
               bne  mul32p_testf2   ; factor 1 is not zero & not 1 -> test factor 2
               ldab 3,x
               beq  mul32p_f1isres  ; factor 1 is zero -> product is zero and already in place
               decb
               bne  mul32p_testf2
               tsx                  ; factor 1 is 1, result is copy of factor 2
               ldx  0,x             ; get ptr to factor 2
               ldd  2,x             ; get factor 2 / lobyte
               tsx
               ldx  2,x             ; get ptr to factor 1 / output
               std  2,x             ; store lobyte directly to output
               pulx                 ; get ptr to factor 2
               ldd  0,x             ; get factor 2 / hibyte
               pulx                 ; get ptr to factor 1 / output
               std  0,x             ; store hibyte
mul32p_cls
               ins                  ; clear stack
               ins
               ins
               ins
               rts                  ; return
               pulx                 ; clean up
               pulx
               bra  mul32p_cls
mul32p_testf2
               tsx
               ldx  0,x             ; get pointer to factor 2
               ldab 0,x
               orab 1,x
               orab 2,x
               bne  mul32p_domult   ; factor 2 is > 255, perform multiplication
               ldab 3,x
               beq  mul32p_zero     ; factor 2 is 0, return with 0 as result
               decb
               bne  mul32p_domult   ; factor 2 is >1, perform multiplication
mul32p_f1isres
               pulx                 ; factor 2 is = 1, do nothing (factor 1 is result and already in-place)
               pulx                 ; get pointer back
               bra  mul32p_cls      ; clear stack and return
mul32p_zero
               pulx
               jmp  mul32p_end
mul32p_domult
;--- b1
               tsx
               ldx  2,x             ; get ptr to factor 2
               ldaa 3,x             ; LoWord/LoByte Faktor1 - a1
               pulx
               ldab 3,x             ; LoWord/LoByte Faktor2 - b1
               pshx
               mul                  ; (b1a1)
               tsx
               std  6,x             ; store b1a1

               ldx  2,x
               ldaa 2,x             ; LoWord/HiByte Faktor1 - a2
               pulx
               pshx
               ldab 3,x             ; LoWord/LoByte Faktor2 - b1
               mul                  ; (b1a2)
               tsx
               addd 5,x             ; add to temp. storage
               std  5,x             ; save in temp. storage

               ldx  2,x
               ldaa 1,x             ; HiWord/LoByte Faktor1 - a3
               pulx
               pshx
               ldab 3,x             ; LoWord/LoByte Faktor2 - b1
               mul                  ; (b1a3)
               tsx
               addd 4,x
               std  4,x             ; store b1a3

               ldx  2,x
               ldaa 0,x             ; HiWord/HiByte Faktor1 - a4
               pulx
               pshx
               ldab 3,x             ; LoWord/LoByte Faktor2 - b1
               mul                  ; (b1a4)
               tsx
               addb 4,x             ; only add & save low-byte of this result
               stab 4,x             ; hi-byte gets truncated
;--- b2
               ldx  2,x             ;
               ldaa 3,x             ; LoWord/LoByte Faktor1 - a1
               pulx
               pshx
               ldab 2,x             ; LoWord/HiByte Faktor2 - b2
               mul                  ; (b2a1)
               tsx
               addd 5,x             ; add to temporary storage
               std  5,x             ; and store
               ldaa #0
               adca 4,x             ; add carry
               staa 4,x             ; and store

               ldx  2,x
               ldaa 2,x             ; LoWord/HiByte Faktor1 - a2
               pulx
               pshx
               ldab 2,x             ; LoWord/HiByte Faktor2 - b2
               mul                  ; (b2a2)
               tsx
               addd 4,x             ; add to intermediate result
               std  4,x             ; and store

               ldx  2,x
               ldaa 1,x             ; HiWord/LoByte Faktor1 - a3
               pulx
               pshx
               ldab 2,x             ; LoWord/HiByte Faktor2 - b2
               mul                  ; (b2a3)
               tsx
               addb 4,x             ; Nur noch Low Byte addieren
               stab 4,x             ; und speichern

;--- b3
               ldx  2,x
               ldaa 3,x             ; LoWord/LoByte Faktor1 - a1
               pulx
               pshx
               ldab 1,x             ; HiWord/LoByte Faktor2 - b3
               mul                  ; (b3a1)
               tsx
               addd 4,x             ; zum Zwischenergebnis addieren
               std  4,x             ; und speichern

               ldx  2,x
               ldaa 2,x             ; LoWord/HiByte Faktor1 - a2
               pulx
               pshx
               ldab 1,x             ; HiWord/LoByte Faktor2 - b3
               mul                  ; (b3a2)
               tsx
               addb 4,x             ; Nur noch Low Byte addieren
               stab 4,x             ; und speichern
;--- b4
               ldx  2,x
               ldaa 3,x             ; LoWord/LoByte Faktor1 - a1
               pulx
               ldab 0,x             ; HiWord/HiByte Faktor2 - b4
               mul                  ; (b4a1)
               tsx
               addb 2,x             ; Nur noch Low Byte addieren
               stab 2,x             ; und speichern
mul32p_end
               pulx                 ; get pointer to factor1 / result
               pula
               pulb                 ; get result HiWord
               std  0,x             ; write to memory
               pula
               pulb                 ; get result / LoWord
               std  2,x             ; write to target memory
               rts


exp10a
exp10a_0       .dw     0,1      ;10^0
exp10a_1       .dw     0,10     ;10^1
exp10a_2       .dw     0,100    ;10^2
               .dw     0,1000   ;10^3
               .dw     0,10000  ;10^4
               .dw $0001,$86a0  ;10^5
               .dw $000F,$4240  ;10^6
               .dw $0098,$9680  ;10^7
               .dw $05f5,$e100  ;10^8
exp10_9
               .dw $3b9a,$ca00
exp10          ; Tabelle um 10 zu potenzieren - 32Bit Einträge
               .dw $05f5,$e100  ;10^8
exp10_7        .dw $0098,$9680  ;10^7
exp10_6        .dw $000F,$4240  ;10^6
exp10_5        .dw $0001,$86a0  ;10^5
exp10_4        .dw     0,10000  ;10^4
exp10_3        .dw     0,1000   ;10^3
exp10_2        .dw     0,100    ;10^2
exp10_1        .dw     0,10     ;10^1
exp10_0        .dw     0,1      ;10^0

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
; required Stack Space : 4 Byte
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
; required Stack Space : 4 Byte
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
; required Stack Space : 6 Byte
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

;*************
; S U B 3 2 S
;*************
; Parameter:
;           X     *Minuend   (32Bit)
;           Stack Subtrahend (32Bit)
; Ergebnis:
;           X     *Differenz (32Bit)
;
; required Stack Space : 4 Byte
;
; 4 - Subtrahend2
; 2 - *Return
; 0 - *Minuend1
sub32s
               pshx                 ; Pointer auf Minuenden sichern
               ldd  2,x             ; LoWord/Minuend
               tsx                  ; Stackpointer nach X
               subd 6,x             ; LoWord / Minuend - LoWord / Subtrahend
               ldx  0,x             ; Pointer auf Minuend/Differenz holen
               std  2,x             ; LoWord speichern
               ldd  0,x             ; HiWord Minuend holen
               tsx
               sbcb 5,x             ; - HiWord/LoByte Subtrahend
               ldx  0,x             ; Pointer auf Minuend/Differenz holen
               stab 1,x             ; HiWord/LoByte speichern
               tsx
                                    ; HiWord/HiByte Minuend
               sbca 4,x             ; - HiWord/HiByte Subtrahend
               ldx  0,x             ; Pointer auf Minuend/Differenz holen
               staa 0,x             ; HiWord/HiByte speichern
               pulx
               rts
;*************
; C M P 3 2 P
;*************
;
; 32 Bit comparison, sets the condition codes (Flags) like "cmp"
; performs a subtraction internally, but does NOT store the result
; Except for 7 Byte of stack space, this routine is transparent
; (all registers are restored, no values from memory altered - except stack)
;
; Parameter:
;           X     *Minuend    (32Bit)   (ptr to what is to be compared)
;           D     *Subtrahend (32Bit)   (ptr to the value which *X is compared to)
; Ergebnis:
;           P     CPU Flags according to comparison
;
; required Stack Space : 7 Byte
;
; 2 - *minuend
; 0 - *subtrahend
cmp32p
               pshx                 ; save pointer to minuend
               pshb
               psha                 ; save pointer to subtrahend
               ldd  2,x             ; get LoWord/Minuend
               tsx                  ; Stackpointer nach X
               ldx  0,x
               subd 2,x             ; LoWord / Minuend - LoWord / Subtrahend
               tpa
               psha
               tsx
               ldx  3,x
               ldaa 1,x             ; get HiWord / LoByte / Minuend
               ldab 0,x             ; get HiWord / HiByte / Minuend
                                    ; we cannot use LDD here because LoByte needs to be in Reg A
                                    ; Reason: TAB resets the Z flag, thus we cannot use TAB to move
                                    ; the highbyte to B before saving the result of the subtraction (using TPA).
                                    ; But the CC can only be transferred to A (TPA, there is no TPB)
               tsx
               ldx  1,x
               sbca 1,x             ; - HiWord/LoByte Subtrahend
               tpa                  ; save CC regs in A
               tsx
               anda 0,x             ; combine flags (Zero flag)
               oraa #~4             ; set all bits to 1 except Bit of Z flag
               staa 0,x             ; store intermediate result
               ldx  1,x             ;
               sbcb 0,x             ; HiWord/HiByte Minuend - HiWord/HiByte Subtrahend
               tpa                  ; save flags
               tsx
               anda 0,x             ; Perform "AND" of Z-flags of all subtractions/comparisons
               tap                  ; transfer result back to CC reg
                                    ; for remaining flags: The flags of the last subtraction are used
               ins
               pula
               pulb
               pulx                 ; clear stack
               rts
;*******************
; S I G   I N V 3 2
;*******************
;
; Vorzeichenumkehr / Two's complement
;
; Parameter:
;           X:D   Zahl  (32Bit)
; Ergebnis:
;           Not(Zahl)+1 (Vorzeichenumkehr)
;
; required Stack Space : 7 Byte
;
sig_inv32
               pshx
               coma
               comb                 ; LoWord invertieren
               addd #1              ; add 1
               xgdx
               pshx
               tpa
               psha                 ; save Status
               tsx
               ldab 4,x             ; get 3rd Byte
               comb                 ; invert it
               pula
               tap                  ; Get status (Carry) back
               adcb #0              ; add carry
               tpa
               psha                 ; save status
               stab 4,x             ; save 3rd byte
               ldab 3,x             ; get 4th byte
               comb                 ; invert it
               pula
               tap
               adcb #0              ; add carry
               stab 3,x             ; save 4th byte

               pula                 ; Ergebnis holen
               pulb
               pulx

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
;
; required Stack Space : 5 Byte
;
sig_inv32s
               pshx
               ldd  2,x
               coma
               comb                 ; LoWord invertieren
               addd #1              ; add #1
               std  2,x
               tpa
               psha                 ; save Status
               ldab 1,x             ; get 3rd Byte
               comb                 ; invert it
               pula
               tap                  ; Get status (Carry) back
               adcb #0              ; add carry
               tpa
               psha                 ; save status
               stab 1,x             ; save 3rd byte
               ldab 0,x             ; get 4th byte
               comb                 ; invert it
               pula
               tap
               adcb #0              ; add carry
               stab 0,x             ; save 4th byte

               pulx                 ; get x back
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
; required Stack Space : 3 Byte
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
;*************
; S I N
;*************
;
; Liefert 127*sin(x)
;
; Parameter: B - argument ( B= angle[rad]/pi * 32 or B= angle[deg]/360 * 64)
;
; Ergebnis : B - 127*sin(x)
;
sin
               psha                    ;+2  2
               pshx                    ;+3  5
               andb #63                ;+2  7  Argument >63 -> Argument-64
               ldx  #sin_tab           ;+3 10
               abx                     ;+1 11
               ldab 0,x                ;+4 15  Tabelleneintrag holen
sin_end
               pulx                    ;+4 19
               pulb                    ;+3 22
               rts                     ;+5 27

sin_tab
               .db 134,147,159,171,183,194,204,214,222,230,237,243,248,252,254,255
               .db 255,254,252,248,243,237,230,222,214,204,194,183,171,159,147,134
               .db 122,109,97,85,73,62,52,42,34,26,19,13,8,4,2,1
               .db 1,2,4,8,13,19,26,34,42,52,62,73,85,97,109,122
sin_tab32      ;    1  2  3  4  5  6  7  8  9 10 11 12 13 14 15  0
               .db 16,17,19,20,22,23,24,26,27,28,29,30,30,31,31,31
               .db 31,31,31,31,30,30,29,28,27,26,24,23,22,20,19,17
               .db 16,14,13,11,10, 8, 7, 6, 5, 4, 3, 2, 1, 1, 0, 0
               .db  0, 0, 0, 1, 1, 2, 3, 4, 5, 6, 7, 8,10,11,13,14
sin_tab8       ;    1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
               .db  3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 7, 7, 7, 7, 7
               .db  7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 5, 5, 5, 4, 4, 4
               .db  3, 3, 3, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0
               .db  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3
sin_tab8l      ;    1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
               .db  3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 6
               .db  6, 6, 6, 6, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4, 3
               .db  3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1
               .db  1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3
rect_tab8
               .db  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
               .db  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
               .db  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
               .db  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
saw_tab32
               .db  0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15
               .db 16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
               .db  0, 0, 0, 0, 0, 0, 0,16, 4, 4, 4, 4, 5, 5, 5,16
               .db  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8
