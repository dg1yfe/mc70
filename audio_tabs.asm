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
 .ORG $A000
#ifdef EVA9
.ORG $F000
; Remark:
; these tables only make sense in EVA9 radios, since they posess a
; 4 Bit R2R DAC (for signalling) and a 3 Bit R2R DAC (for private line / CTCSS)
; tables are 256 Bytes to save CPU cycles (e.g. avoid "and #31")
;------
; Sine tables for DTMF Tone generation
; tones of the high group should be 1-4 dB louder than
; tones of the low group according to ETSI ES 201 235-2
; These tables provide tones different by 3.5 dB
sin_tab_lo
                .db   6, 6, 6, 6, 6, 6, 6, 8, 8, 8, 8, 8, 8, 8, 8, 8,
                .db   8, 8, 8, 8, 8, 8,10,10,10,10,10,10,10,10,10,10,
                .db  10,10,10,10,10,10,10,10,10,12,12,12,12,12,12,12,
                .db  12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
                .db  12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
                .db  12,12,12,12,12,12,12,12,10,10,10,10,10,10,10,10,
                .db  10,10,10,10,10,10,10,10,10,10,10, 8, 8, 8, 8, 8,
                .db   8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 6, 6, 6, 6, 6, 6,
                .db   6, 6, 6, 6, 6, 6, 6, 4, 4, 4, 4, 4, 4, 4, 4, 4,
                .db   4, 4, 4, 4, 4, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
                .db   2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0,
                .db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                .db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                .db   0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
                .db   2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4,
                .db   4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 6, 6, 6, 6, 6, 6
sin_tab_hi
                .db  10,10,10,10,10,10,10,10,10,10,12,12,12,12,12,12,
                .db  12,12,12,14,14,14,14,14,14,14,14,14,14,14,16,16,
                .db  16,16,16,16,16,16,16,16,16,16,16,16,16,18,18,18,
                .db  18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,
                .db  18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,
                .db  18,18,18,18,16,16,16,16,16,16,16,16,16,16,16,16,
                .db  16,16,16,14,14,14,14,14,14,14,14,14,14,14,12,12,
                .db  12,12,12,12,12,12,12,10,10,10,10,10,10,10,10,10,
                .db  10, 8, 8, 8, 8, 8, 8, 8, 8, 8, 6, 6, 6, 6, 6, 6,
                .db   6, 6, 6, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 2, 2,
                .db   2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0,
                .db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                .db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                .db   0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
                .db   2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 6, 6,
                .db   6, 6, 6, 6, 6, 6, 6, 8, 8, 8, 8, 8, 8, 8, 8, 8

; Sine table for second DAC (Port 6 Bit 5-7)
; Values are already shifted to avoid shifting in software and save some CPU cycles
sin_256_3_0dB_pl
                .db  128,128,128,128,128,128,128,128,128,128,128,128,160,160,160,160,
                .db  160,160,160,160,160,160,160,160,160,192,192,192,192,192,192,192,
                .db  192,192,192,192,192,192,192,192,192,192,224,224,224,224,224,224,
                .db  224,224,224,224,224,224,224,224,224,224,224,224,224,224,224,224,
                .db  224,224,224,224,224,224,224,224,224,224,224,224,224,224,224,224,
                .db  224,224,224,224,224,224,224,192,192,192,192,192,192,192,192,192,
                .db  192,192,192,192,192,192,192,192,160,160,160,160,160,160,160,160,
                .db  160,160,160,160,160,128,128,128,128,128,128,128,128,128,128,128,
                .db  128, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 64, 64, 64, 64,
                .db   64, 64, 64, 64, 64, 64, 64, 64, 64, 32, 32, 32, 32, 32, 32, 32,
                .db   32, 32, 32, 32, 32, 32, 32, 32, 32, 32,  0,  0,  0,  0,  0,  0,
                .db    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
                .db    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
                .db    0,  0,  0,  0,  0,  0,  0, 32, 32, 32, 32, 32, 32, 32, 32, 32,
                .db   32, 32, 32, 32, 32, 32, 32, 32, 64, 64, 64, 64, 64, 64, 64, 64,
                .db   64, 64, 64, 64, 64, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96
sin_64_4_0dB_sig
                .db  16,16,18,20,20,22,24,24,26,26,28,28,28,30,30,30,
                .db  30,30,30,30,28,28,28,26,26,24,24,22,20,20,18,16,
                .db  16,14,12,10,10, 8, 6, 6, 4, 4, 2, 2, 2, 0, 0, 0,
                .db   0, 0, 0, 0, 2, 2, 2, 4, 4, 6, 6, 8,10,10,12,14
#else

; EVA5 only has two 1 Bit DAC
; if also using tristate one can attain about 3 Bit resolution with increased
; software/CPU requirements
; This requires a matching sine lookup table to account for the unevenly
; spaced output values
dac_out_tab
               .dw $6010 ; 1,00   00  0  1,31  - 0.000
               .dw $4010 ; 1,25   0-  1  1,34  - 0.012
               .dw $2010 ; 1,67   -0  2  1,66  - 0.136
               .dw $6030 ; 2,0    01  3  1,98  - 0.261
               .dw $0010 ; 2,5    --  4  2,48  - 0.455
               .dw $6050 ; 3,0    10  5  2,92  - 0.626
               .dw $2030 ; 3,33   -1  6  3,26  - 0.759
               .dw $4050 ; 3,75   1-  7  3,64  - 0.907
               .dw $6070 ; 4,00   11  8  3,88  - 1.000
               .dw $6070 ; 4,00   11  8  3,88  - 1.000  ; Saturate
               .dw $6070 ; 4,00   11  8  3,88  - 1.000  ; Saturate
               .dw $6070 ; 4,00   11  8  3,88  - 1.000  ; Saturate

dac_out_tab2
               .dw $6000 ; 1,00   00 5  1,31
               .dw $4000 ; 1,00   0- 0  1,34
               .dw $2000 ; 1,00   -0 0  1,66
               .dw $6020 ; 3,33   01 6  1,98
               .dw $0000 ; 1,00   -- 0  2,48
               .dw $6040 ; 3,75   10 7  2,92
               .dw $2020 ; 1,00   -1 0  3,26
               .dw $4040 ; 1,00   1- 0  3,64
               .dw $6060 ; 4,00   11 8  3,88
               .dw $6060 ; 4,00   11 8  3,88
               .dw $6060 ; 4,00   11 8  3,88

sin_256
               .db   8, 8, 8, 8,10,10,10,10,10,10,10,10,10,10,10,10,
               .db  10,12,12,12,12,12,12,12,12,12,12,12,12,12,14,14,
               .db  14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,16,
               .db  16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,
               .db  16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,
               .db  16,16,14,14,14,14,14,14,14,14,14,14,14,14,14,14,
               .db  14,14,14,12,12,12,12,12,12,12,12,12,12,12,12,12,
               .db  10,10,10,10,10,10,10,10,10,10,10,10,10, 8, 8, 8,
               .db   8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 6, 6, 6, 6,
               .db   6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 4, 4, 4, 4, 4,
               .db   4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 2, 2, 2, 2, 2, 2,
               .db   2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0,
               .db   0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2,
               .db   2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4,
               .db   4, 4, 4, 4, 4, 4, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
               .db   6, 6, 6, 6, 6, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,

; Single tone oscillator of EVA5 may use this table directly
; to get DAC value (Port 6 data and DDR) directly
             .dw $0
dac_sin_tab
;                .dw $0000, $4060, $4060, $4060, $2020, $2020, $2020, $4040,
;                .dw $4040, $6060, $6060, $6060, $6060, $6060, $6060, $6060,
;                .dw $6060, $6060, $6060, $6060, $6060, $6060, $6060, $6060,
;                .dw $4040, $4040, $2020, $2020, $2020, $4060, $4060, $4060,
;                .dw $0000, $0000, $0000, $2060, $2060, $2060, $0020, $0020,
;                .dw $0020, $0040, $0040, $0040, $0040, $0040, $0040, $0040,
;                .dw $0040, $0040, $0040, $0040, $0040, $0040, $0040, $0040,
;                .dw $0020, $0020, $0020, $2060, $2060, $2060, $0000, $0000
                .dw  $0000, $0000, $0000, $6040, $6040, $6040, $6040, $6040,
                .dw  $2020, $2020, $2020, $2020, $2020, $2020, $2020, $2020,
                .dw  $2020, $2020, $2020, $2020, $2020, $2020, $2020, $2020,
                .dw  $2020, $6040, $6040, $6040, $6040, $6040, $0000, $0000,
                .dw  $0000, $0000, $6020, $6020, $6020, $6020, $6020, $2000,
                .dw  $2000, $2000, $2000, $4000, $4000, $4000, $4000, $4000,
                .dw  $4000, $4000, $4000, $4000, $4000, $4000, $2000, $2000,
                .dw  $2000, $2000, $6020, $6020, $6020, $6020, $6020, $0000
                .dw  $0000

                .dw  $6c00, $6c00
dac_8to3
                .dw  $6c00, $6c00, $4c00, $4c00, $4c00, $4c00, $4c00, $4c00,
                .dw  $4c00, $4c00, $4c00, $4c00, $4c00, $4c00, $4c00, $4c00,
                .dw  $4c00, $4c00, $4c00, $2c00, $2c00, $2c00, $2c00, $2c00,
                .dw  $2c00, $2c00, $2c00, $2c00, $2c00, $2c00, $2c00, $2c00,
                .dw  $2c00, $2c00, $2c00, $2c00, $2c00, $2c00, $2c00, $2c00,
                .dw  $2c00, $2c00, $2c00, $2c00, $2c00, $2c00, $2c00, $2c00,
                .dw  $2c00, $2c00, $2c00, $6c20, $6c20, $6c20, $6c20, $6c20,
                .dw  $6c20, $6c20, $6c20, $6c20, $6c20, $6c20, $6c20, $6c20,
                .dw  $6c20, $6c20, $6c20, $6c20, $6c20, $6c20, $6c20, $6c20,
                .dw  $6c20, $6c20, $6c20, $6c20, $6c20, $6c20, $6c20, $6c20,
                .dw  $6c20, $6c20, $6c20, $6c20, $6c20, $6c20, $6c20, $6c20,
                .dw  $6c20, $6c20, $6c20, $6c20, $0c00, $0c00, $0c00, $0c00,
                .dw  $0c00, $0c00, $0c00, $0c00, $0c00, $0c00, $0c00, $0c00,
                .dw  $0c00, $0c00, $0c00, $0c00, $0c00, $0c00, $0c00, $0c00,
                .dw  $0c00, $0c00, $0c00, $0c00, $0c00, $0c00, $0c00, $0c00,
                .dw  $0c00, $0c00, $0c00, $0c00, $0c00, $0c00, $0c00, $0c00,
                .dw  $0c00, $0c00, $0c00, $0c00, $0c00, $0c00, $0c00, $0c00,
                .dw  $0c00, $0c00, $0c00, $6c40, $6c40, $6c40, $6c40, $6c40,
                .dw  $6c40, $6c40, $6c40, $6c40, $6c40, $6c40, $6c40, $6c40,
                .dw  $6c40, $6c40, $6c40, $6c40, $6c40, $6c40, $6c40, $6c40,
                .dw  $6c40, $6c40, $6c40, $6c40, $6c40, $6c40, $6c40, $6c40,
                .dw  $6c40, $6c40, $6c40, $6c40, $6c40, $6c40, $6c40, $6c40,
                .dw  $6c40, $6c40, $2c20, $2c20, $2c20, $2c20, $2c20, $2c20,
                .dw  $2c20, $2c20, $2c20, $2c20, $2c20, $2c20, $2c20, $2c20,
                .dw  $2c20, $2c20, $2c20, $2c20, $2c20, $2c20, $2c20, $2c20,
                .dw  $2c20, $2c20, $2c20, $2c20, $2c20, $2c20, $2c20, $2c20,
                .dw  $2c20, $2c20, $2c20, $2c20, $2c20, $2c20, $4c40, $4c40,
                .dw  $4c40, $4c40, $4c40, $4c40, $4c40, $4c40, $4c40, $4c40,
                .dw  $4c40, $4c40, $4c40, $4c40, $4c40, $4c40, $4c40, $4c40,
                .dw  $4c40, $4c40, $4c40, $4c40, $4c40, $4c40, $4c40, $4c40,
                .dw  $4c40, $4c40, $4c40, $4c40, $4c40, $6c60, $6c60, $6c60,
                .dw  $6c60, $6c60, $6c60, $6c60, $6c60, $6c60, $6c60, $6c60
                .dw  $6c60, $6c60

; Sine table containing translated amplitude values as port values
dac_sin256pv
                .dw  $6040, $6040, $6040, $6040, $6040, $6040, $6040, $6040,
                .dw  $6040, $6040, $6040, $6040, $6040, $2020, $2020, $2020,
                .dw  $2020, $2020, $2020, $2020, $2020, $2020, $2020, $2020,
                .dw  $2020, $2020, $2020, $2020, $2020, $4040, $4040, $4040,
                .dw  $4040, $4040, $4040, $4040, $4040, $4040, $4040, $4040,
                .dw  $4040, $4040, $4040, $4040, $4040, $4040, $4040, $4040,
                .dw  $4040, $4040, $4040, $6060, $6060, $6060, $6060, $6060,
                .dw  $6060, $6060, $6060, $6060, $6060, $6060, $6060, $6060,
                .dw  $6060, $6060, $6060, $6060, $6060, $6060, $6060, $6060,
                .dw  $6060, $6060, $6060, $6060, $6060, $6060, $4040, $4040,
                .dw  $4040, $4040, $4040, $4040, $4040, $4040, $4040, $4040,
                .dw  $4040, $4040, $4040, $4040, $4040, $4040, $4040, $4040,
                .dw  $4040, $4040, $4040, $4040, $2020, $2020, $2020, $2020,
                .dw  $2020, $2020, $2020, $2020, $2020, $2020, $2020, $2020,
                .dw  $2020, $2020, $2020, $2020, $6040, $6040, $6040, $6040,
                .dw  $6040, $6040, $6040, $6040, $6040, $6040, $6040, $6040,
                .dw  $6040, $6040, $6040, $6040, $0000, $0000, $0000, $0000,
                .dw  $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000,
                .dw  $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000,
                .dw  $6020, $6020, $6020, $6020, $6020, $6020, $6020, $6020,
                .dw  $6020, $6020, $6020, $6020, $6020, $6020, $6020, $6020,
                .dw  $6020, $6020, $6020, $6020, $6020, $6020, $6020, $6020,
                .dw  $6020, $6020, $2000, $2000, $2000, $2000, $2000, $2000,
                .dw  $2000, $2000, $2000, $2000, $2000, $2000, $2000, $2000,
                .dw  $2000, $2000, $2000, $2000, $2000, $2000, $2000, $2000,
                .dw  $2000, $2000, $2000, $2000, $2000, $2000, $2000, $6020,
                .dw  $6020, $6020, $6020, $6020, $6020, $6020, $6020, $6020,
                .dw  $6020, $6020, $6020, $6020, $6020, $6020, $6020, $6020,
                .dw  $6020, $6020, $6020, $6020, $6020, $6020, $6020, $6020,
                .dw  $6020, $0000, $0000, $0000, $0000, $0000, $0000, $0000,
                .dw  $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000,
                .dw  $0000, $0000, $0000, $0000, $0000, $6040, $6040, $6040,
err_tab
dac_8to3_err
                .db   32, 31, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19,
                .db   18, 17, 16, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35,
                .db   34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19,
                .db   18, 17, 16, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35,
                .db   34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19,
                .db   18, 17, 16, 15, 14, 13, 12, 11, 10,  9,  8,  7, 56, 55, 54, 53,
                .db   52, 51, 50, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37,
                .db   36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21,
                .db   20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 53, 52, 51, 50, 49,
                .db   48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
                .db   32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
                .db   16, 15, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35,
                .db   34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19,
                .db   18, 17, 16, 15, 14, 13, 50, 49, 48, 47, 46, 45, 44, 43, 42, 41,
                .db   40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25,
                .db   24, 23, 22, 21, 20, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33
err_tab1
                .db   32, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19,
                .db   18, 17, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35,
                .db   34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19,
                .db   18, 17, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35,
                .db   34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19,
                .db   18, 17, 16, 15, 14, 13, 12, 11, 10,  9,  8, 57, 56, 55, 54, 53,
                .db   52, 51, 50, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37,
                .db   36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21,
                .db   20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 54, 53, 52, 51, 50, 49,
                .db   48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
                .db   32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
                .db   16, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35,
                .db   34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19,
                .db   18, 17, 16, 15, 14, 51, 50, 49, 48, 47, 46, 45, 44, 43, 42, 41,
                .db   40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25,
                .db   24, 23, 22, 21, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 23
dac_sin256
                .db  $80, $81, $83, $84, $86, $87, $89, $8a, $8c, $8d, $8f, $90, $92, $93, $95, $96,
                .db  $98, $99, $9b, $9c, $9d, $9f, $a0, $a1, $a3, $a4, $a5, $a7, $a8, $a9, $aa, $ab,
                .db  $ac, $ad, $af, $b0, $b1, $b2, $b3, $b3, $b4, $b5, $b6, $b7, $b8, $b8, $b9, $ba,
                .db  $ba, $bb, $bb, $bc, $bc, $bd, $bd, $bd, $be, $be, $be, $bf, $bf, $bf, $bf, $bf,
                .db  $bf, $bf, $bf, $bf, $bf, $bf, $be, $be, $be, $bd, $bd, $bd, $bc, $bc, $bb, $bb,
                .db  $ba, $ba, $b9, $b8, $b8, $b7, $b6, $b5, $b4, $b3, $b3, $b2, $b1, $b0, $af, $ad,
                .db  $ac, $ab, $aa, $a9, $a8, $a7, $a5, $a4, $a3, $a1, $a0, $9f, $9d, $9c, $9b, $99,
                .db  $98, $96, $95, $93, $92, $90, $8f, $8d, $8c, $8a, $89, $87, $86, $84, $83, $81,
                .db  $80, $7e, $7c, $7b, $79, $78, $76, $75, $73, $72, $70, $6f, $6d, $6c, $6a, $69,
                .db  $67, $66, $64, $63, $62, $60, $5f, $5e, $5c, $5b, $5a, $58, $57, $56, $55, $54,
                .db  $53, $52, $50, $4f, $4e, $4d, $4c, $4c, $4b, $4a, $49, $48, $47, $47, $46, $45,
                .db  $45, $44, $44, $43, $43, $42, $42, $42, $41, $41, $41, $40, $40, $40, $40, $40,
                .db  $40, $40, $40, $40, $40, $40, $41, $41, $41, $42, $42, $42, $43, $43, $44, $44,
                .db  $45, $45, $46, $47, $47, $48, $49, $4a, $4b, $4c, $4c, $4d, $4e, $4f, $50, $52,
                .db  $53, $54, $55, $56, $57, $58, $5a, $5b, $5c, $5e, $5f, $60, $62, $63, $64, $66,
                .db  $67, $69, $6a, $6c, $6d, $6f, $70, $72, $73, $75, $76, $78, $79, $7b, $7c, $7e

sin_64_3_0dB   ;    1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
                .db   4, 5, 5, 5, 5, 6, 6, 6, 7, 7, 7, 7, 8, 8, 8, 8,
                .db   8, 8, 8, 8, 8, 7, 7, 7, 7, 6, 6, 6, 5, 5, 5, 5,
                .db   4, 4, 4, 3, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 0,
                .db   0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4

sin_64_3_1dB
                .db   4, 4, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 7,
                .db   7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 6, 6, 5, 5, 5, 4,
                .db   4, 4, 4, 4, 4, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2,
                .db   2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4

sin_64_3_0dB_ls ;    1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
               .db   8, 8,10,10,10,12,12,12,14,14,14,14,16,16,16,16,
               .db  16,16,16,16,16,14,14,14,14,12,12,12,10,10,10, 8,
               .db   8, 8, 6, 6, 6, 4, 4, 4, 2, 2, 2, 2, 0, 0, 0, 0,
               .db   0, 0, 0, 0, 0, 2, 2, 2, 2, 4, 4, 4, 6, 6, 6, 8

#endif
