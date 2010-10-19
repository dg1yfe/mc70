                                           ; Sinn des folgenden Konstrukts:
                                           ; Ohne das Flash ROM l�schen zu m�ssen, eine andere Startadresse
                                           ; f�r das Hauptprogramm vorgeben zu k�nnen.
                                           ; Vorgabewert ist Vektor 8 mit Adresse "Start"
                                           ; Die anderen Vektoren und der Selektor werden auf $FFFF bzw. $FF
                                           ; belassen.
                                           ; Ben�tigt man eine andere Startadresse, so programmiert (l�scht) man
                                           ; Bit 0 im Selektor und programmiert die Adresse in Vektor 7
                ldaa #8
                ldx  #Start_vec-2          ; Adresse vom 1. Startvektor (-2) holen
                ldab start_vec_sel         ; Selektor holen
start_sel_lp
                inx
                inx                        ; Startvektoradresse+2
                deca                       ; Wenn alle 8 Bit gepr�ft wurden
                beq  Start                 ; mit Standardadresse fortfahren.
                lslb                       ; Selektor nach links schieben
                bcs  start_sel_lp          ; Bit noch gesetzt? Dann zum n�chsten Vektor gehen

                ldx  0,x                   ; Startadresse aus Startvektor lesen
                jmp  0,x                   ; und ausf�hren
Start_bank2
                clrb
start_loop

                ldx  #Start                ; Adresse von 'Start' holen
                pshx
                jmp  bank1                 ; Bankumschaltung durchf�hren

