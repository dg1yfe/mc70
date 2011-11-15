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
;************************************************
; M E M O R Y
;************************************************
;
; Memory related Subroutines
;
; mem_fill - Füllt einen Speicherbereich von maximal 256 Bytes mit dem angegebenen Wert
;            ( B - Füllwert, A - Bytecount, X - Startadresse | nix )
; mem_trans - Kopiert Daten im RAM ( D - Zieladresse, X - Quelladresse, Stack - Bytecount | nix )
;
;
;
;
;
;************************
; M E M   T R A N S
;************************
;
; Kopiert Daten im RAM.
; Speicherbereiche dürfen sich nicht überlappen wenn Zieladresse>Quelladresse!
;
; Parameter : D            - Zieladresse
;             X            - Quelladresse
;             Stack (Word) - Bytecount
;
; Ergebnis     : Nichts
;
; changed Regs : A,B,X
;
;
mem_trans
               pshb
               psha
               pshx

               tsx
               ldx  2+4,x                  ; Bytecount
               beq  mem_trans_ret          ; Wenn 0 Bytes zu kopieren sind -> Ende
mem_trans_loop
               pshx                        ; Bytecount speichern

               tsx
               ldx  2,x                    ; Get source address from stack
               ldab 0,x
               pshb                        ; store byte on stack
               inx                         ; Increment source address
               xgdx
               tsx
               std  2+1,x                  ; store new source address

               ldx  4+1,x                  ; get destination address
               pulb                        ; get byte to transfer from stack
               stab 0,x                    ; store byte to destination
               inx                         ; increment destination address
               xgdx
               tsx
               std  4,x                    ; store destination address

               pulx                        ; get bytecount
               dex                         ; increment bytecount
               bne  mem_trans_loop
mem_trans_ret
               pulx
               pula
               pulb
               rts

