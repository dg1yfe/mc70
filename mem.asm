;****************************************************************************
;
;    MC 70    v1.0.1 - Firmware for Motorola mc micro trunking radio
;                      for use as an Amateur-Radio transceiver
;
;    Copyright (C) 2004 - 2007  Felix Erckenbrecht, DG1YFE
;
;    This program is free software; you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation; either version 2 of the License, or
;    any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program; if not, write to the Free Software
;    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
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
               std  mem_tr_des
               stx  mem_tr_src
               tsx
               ldx  2,x                  ; Bytecount
               beq  mem_trans_ret        ; Wenn 0 Bytes zu kopieren sind -> Ende
mem_trans_loop
               pshx                      ; Bytecount speichern

               ldx  mem_tr_src
               ldab 0,x
               inx
               stx  mem_tr_src

               ldx  mem_tr_des
               stab 0,x
               inx
               stx  mem_tr_des

               pulx
               dex
               bne  mem_trans_loop
mem_trans_ret
               rts

