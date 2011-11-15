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
                                           ; Sinn des folgenden Konstrukts:
                                           ; Ohne das Flash ROM löschen zu müssen, eine andere Startadresse
                                           ; für das Hauptprogramm vorgeben zu können.
                                           ; Vorgabewert ist Vektor 8 mit Adresse "Start"
                                           ; Die anderen Vektoren und der Selektor werden auf $FFFF bzw. $FF
                                           ; belassen.
                                           ; Benötigt man eine andere Startadresse, so programmiert (löscht) man
                                           ; Bit 0 im Selektor und programmiert die Adresse in Vektor 7
                ldaa #8
                ldx  #Start_vec-2          ; Adresse vom 1. Startvektor (-2) holen
                ldab start_vec_sel         ; Selektor holen
start_sel_lp
                inx
                inx                        ; Startvektoradresse+2
                deca                       ; Wenn alle 8 Bit geprüft wurden
                beq  Start                 ; mit Standardadresse fortfahren.
                lslb                       ; Selektor nach links schieben
                bcs  start_sel_lp          ; Bit noch gesetzt? Dann zum nächsten Vektor gehen

                ldx  0,x                   ; Startadresse aus Startvektor lesen
                jmp  0,x                   ; und ausführen
Start_bank2
                clrb
start_loop

                ldx  #Start                ; Adresse von 'Start' holen
                pshx
                jmp  bank1                 ; Bankumschaltung durchführen

