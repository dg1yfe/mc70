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
;*****************
; I S R   I N I T
;*****************
;************************
; I N I T   O C I   I N T
;************************
init_OCI
               clr  bus_busy                ; IRQ Routine darf Watchdog zurücksetzen
               ldd  FRC
               addd #SYSCLK/1000                ; Interrupt every millisecond
               std  OCR1
               ldab #%1000
               stab TCSR1                       ; enable Output Compare Interrupt
               ldd  #0
               std  tick_ms
               stab tick_hms
               addb #100
               stab next_hms
;               ldx  #OCI1_WD_RESET
               ldx  #OCI_LCD
               stx  oci_vec
               rts
;************************
; I N I T   S I O   I N T
;************************
;
; SIO Interrupt initialisieren
;
init_SIO
                clr  io_outbuf_w
                clr  io_outbuf_r                  ; Output Ringbuffer initialisieren

                clr  io_inbuf_w
                clr  io_inbuf_r                   ; Input Ringbuffer initialisieren

;                oim  #%10100,TRCSR1               ; SIO Interrupt aktivieren
                oim  #%00010000,TRCSR1           ; SIO Interrupt aktivieren nur für RX

                rts

;************************************
;
;
;*******
; I S R
;*******
NMI_SR               ; no NMI
                jmp  isu_copy
                rti
;************************************
SWI_SR                                     ; use SWI for taskswitching

                ldx  stackbuf              ; get 'other' stackpointer
                sts  stackbuf              ; save current stackpointer
                inx                        ; correct value (TXS implicitely
                                           ; subtracts 1)
                txs                        ; make 'other' stackpointer the
                                           ; current one
                inc  tasksw                ; increase Taskswitch Counter
                ldx  ts_count
                inx
                stx  ts_count
                rti                        ; Taskswitch durchführen
;************************************
IRQ1_SR              ; no IRQ1
                rti
;************************************
ICI_SR               ; no ICI
                rti
;************************************
OCI_SR                                   ; Timer 1 compare interrupt
                ldx  oci_vec             ; entry point, get the vector from
                                         ; RAM to execute the required code
                jmp  0,x
;************************************
OCI_LCD
                                         ; this part should only be active
                                         ; while software timers are not
                                         ; yet running (e.g. after reset)
                                         ; it updates timers required
                                         ; for communication with the
                                         ; control head

                dec  ui_timer            ; This is like the gp_timer but
                                         ; exclusively for the ui_task
                ldaa lcd_timer
                beq  OCI1_WD_RESET       ; we also need to do the WD reset
                deca
                staa lcd_timer
;
; OCI1 ISR (1 ms Interrupt)
;
OCI1_WD_RESET
                tst  bus_busy              ; währen I2C Zugriff,
                bne  OCI1_SR               ; keinen Watchdog Reset durchführen
;***********
; Watchdog Toggle
                ldab Port2_DDR_buf               ; Port2 DDR lesen
                eorb #%10                        ; Bit 1 invertieren
                stab Port2_DDR_buf
                stab Port2_DDR                   ; neuen Status setzen
                aim  #%11111101,Port2_Data       ;Data auf 0
;***********
OCI1_SR
OCI1_MS
                ldab TCSR2                 ; Interruptflag zurücksetzen
                ldd  OCR1H
                addd #SYSCLK/1000          ;
                std  OCR1H                 ; in 1ms wieder einen Int ausführen

OCI_MAIN
; General Purpose Timer
                dec  gp_timer         ; +6  6  ; Universaltimer-- / HW Task
; Basis Tick Counter
                ldx  tick_ms          ; +4 10
                inx                   ; +1 11  ; 1ms Tick-Counter erhöhen
                stx  tick_ms          ; +4 15

                ldab tasksw_en        ; +3 18  ; auf Taskswitch prüfen?
                bne  end_int          ; +3 21  ; Nein? Dann Ende

                ldaa last_tasksw      ; +3 24  ; Letzten Taskswitch Counter holen
                ldab tasksw           ; +3 27  ; Mit aktuellem Zählerstand vergleichen
                stab last_tasksw      ; +3 30  ; und merken
                cba                   ; +1 31  ; Gabs einen Taskswitch innerhalb der letzten Millisekunde?
                bne  end_int          ; +3 34  ; Ja, dann Int beenden
                                               ; ansonsten Taskswitch durchführen
                ldx  stackbuf         ; +4 38  ; anderen Stackpointer holen
                sts  stackbuf         ; +4 42  ; aktuellen Stackpointer sichern
                inx                   ; +1 43  ; X anpassen für Transfer
                txs                   ; +1 44  ; anderen Stackpointer laden
                inc  tasksw           ; +6 50  ; Taskswitch Counter erhöhen
end_int
                rti                   ;+10 31 / 44 / 60

;************************************
;************************************
ocf2
;                ldx  #tone_tab
;                ldab TCSR2                 ; Timer Sontrol / Status Register 2 lesen

                ldab tone_index
                bne  ocf2_tonelo
                oim  #%01100000, Port6_Data
                eim  #1,tone_index
                rts
ocf2_tonelo
                aim  #%10011111, Port6_Data
                eim  #1,tone_index
                rts

;Pin 30 & 31
;    P65 P66
tone_tab

;sin_tab
                .db %00000000
                .db %01000000
;************************************

TOI_SR               ; no TOI
                rti


;************************************
;
; SIO INT Service Routine
;
; Datenbytes von Schnittstelle abholen - falls vorhanden - und in Puffer speichern
; Datenbytes aus Puffer abholen - falls vorhanden - und über Schnittstelle senden
;
SIO_SR                                     ;+10 10
                ldaa TRCSR1                ; +3 13 ; Status lesen
                tab                        ; +1 14
                andb #%01000000            ; +2 16
                bne  sio_orfe              ; +3 19 ; Overrun / Framing Error
                ldab TRCSR2                ; +3 21
                andb #%00010000            ; +2 23 ; Auf Parity Error prüfen
                bne  sio_per               ; +3 26
                tab                        ; +1 27
                andb #%10000000            ; +2 29
                bne  sio_rdrf              ; +3 32 Receive Data Register Full
                tab                        ; +1 33
                andb #%00100000            ; +2 35
                bne  sio_tdre              ; +3 38 Transmit Data Register Empty Int
                rti                        ;+10 48 Interrupt beenden
;
;******************
;
sio_orfe
sio_per
                ldab RDR                   ; Datenregister lesen -> ORFE oder PER Bit löschen
                                           ; Daten sind ungültig, daher verwerfen
                rti
sio_rdrf
                ldaa RDR                   ; Datenregister lesen
                cli
                ldab io_inbuf_w            ; Zeiger auf Schreibadresse holen
                incb                       ; prüfen ob Puffer schon voll
                andb #io_inbuf_mask        ; maximal 15 Einträge
                cmpb io_inbuf_r            ; Lesezeiger schon erreicht?
                beq  sio_ib_over           ; Overrun Error
                ldab io_inbuf_w            ; Zeiger erneut holen
                ldx  #io_inbuf             ; Basisadresse holen
                abx                        ; beides addieren -> Schreibadresse bestimmen
                staa 0,x                   ; Datenbyte schreiben
                incb                       ; Zeiger++
                andb #io_inbuf_mask        ;
                stab io_inbuf_w            ; und speichern
                rti
sio_ib_over
                ldab io_inbuf_er           ; Errorzähler holen
                incb
                bne  sio_ibo_stor          ; Maxval (255) schon erreicht?
                decb                       ; dann nicht weiterzählen
sio_ibo_stor
                stab io_inbuf_er           ; Neue Zahl der Buffer Overruns speichern
                ldab io_inbuf_w            ; Zeiger auf Puffer holen
                ldx  #io_inbuf             ; Basisadresse holen
                abx                        ; beides addieren -> Schreibadresse bestimmen
                staa 0,x                   ; Datenbyte schreiben, Zeiger nicht erhöhen
                rti
;
;******************
;******************
;
sio_tdre
                ldab io_outbuf_r           ; Zeiger auf Leseposition holen
                cmpb io_outbuf_w           ; Befinden sich noch Zeichen im Output Buffer?
                beq  sio_ob_empty          ; Sprung wenn es keine Daten gibt
                ldx  #io_outbuf            ; Basisadresse holen
                abx                        ; Zeiger addieren, Leseadresse berechnen
                ldaa 0,x                   ; Daten aus Puffer lesen
                incb                       ; Leseposition++
                andb #io_outbuf_mask       ; Im gültigen Rahmen bleiben (0-15)
                stab io_outbuf_r           ; Neue Zeigerposition speichern
                staa TDR                   ; Datenbyte ins Transmit Data Register schreiben
                bmi  sio_tdre_end          ; MSB gesetzt -> nächstes Byte darf sofort gesendet werden (2 Byte Kommando)
;                ldab #LCDDELAY             ; Wartezeit holen
;                stab lcd_timer             ; und Timer entsprechend setzen
sio_ob_empty
                aim  #%11111011,TRCSR1     ; "Transmit Data Register Empty"-Interrupt deaktivieren
sio_tdre_end
                rti

;************************************
CMI_SR               ; no CMI
                rti
;************************************
IRQ2_SR              ; no IRQ2
                rti
;************************************
TRAP_SR              ; no TRAP stuff
                rti
;************************************


