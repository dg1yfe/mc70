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
; mem_fill - F�llt einen Speicherbereich von maximal 256 Bytes mit dem angegebenen Wert
;            ( B - F�llwert, A - Bytecount, X - Startadresse | nix )
; mem_trans - Kopiert Daten im RAM ( D - Zieladresse, X - Quelladresse, Stack - Bytecount | nix )
;
;
;
;
;

