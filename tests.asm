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
;
;
tests
               ldx  #tv_40M
               ldd  #tv_42M
               jsr  cmp32p
               beq  tst_cmp32err        ; result should be non-zero
               bcc  tst_cmp32err        ; carry flag should be set (underflow in unsigned arithmetic)
               bvs  tst_cmp32err        ; overflow clear (no over/underflow in signed arithmetic)
               bpl  tst_cmp32err        ; the result is negative

               ldd  #tv_40M
               ldx  #tv_42M
               jsr  cmp32p
               beq  tst_cmp32err        ; result is non-zero
               bcs  tst_cmp32err        ; no underflow in unsigned artithmetic
               bvs  tst_cmp32err        ; no under/overflow in signed arithmetic
               bmi  tst_cmp32err        ; result is positive

               ldd  #tv_42M
               ldx  #tv_42M
               jsr  cmp32p
               bne  tst_cmp32err
               bcs  tst_cmp32err
               bvs  tst_cmp32err
               bmi  tst_cmp32err

               ldaa #'O'
               ldab #'K'
               bra  tst_mul
tst_cmp32err
               ldx  #$dead
               ldd  #$beef
               rts
tst_mul
               ldd  #tv_0
               ldx  tv_1+2
               pshx
               ldx  tv_1
               pshx
               tsx
               jsr  multiply32p
               ldd  #tv_1
               tsx
               jsr  multiply32p
               pula
               pulb
               pulx
               ldd  #tv_1
               ldx  tv_438500000+2
               pshx
               ldx  tv_438500000
               pshx
               jsr  multiply32p
               pula
               pulb
               pulx
tst_atol
               pshx
               pshx
               ldd  #ts_123
               tsx
               jsr  atol_new
               tsx
               ldd  #tv_123
               jsr  cmp32p
               bne  tst_atol_err
               ldd  #ts_438500000
               tsx
               jsr  atol_new
               ldd  #tv_438500000
               jsr  cmp32p
               bne  tst_atol_err
               pulx
               pulx
               rts
tst_atol_err
               pulx
               pulx
               ldx  #$dead
               ldd  #$beef
               rts

ts_123
               .db "123",0
ts_4385
               .db "4385",0
ts_43850
               .db "43850",0
ts_438500
               .db "438500",0
ts_438500000
               .db "438500000",0
ts_76
               .db "76",0
ts_60000
               .db "60000",0
tv_0
               .dw 0,0
tv_1
               .dw 0,1
tv_42
               .dw 0,42
tv_23
               .dw 0,23

tv_42M
               .dw  42000000>>16,  42000000%65536
tv_40M
               .dw  40000000>>16,  40000000%65536
tv_438500000
               .dw 438500000>>16, 438500000%65536
tv_123
               .dw 0,123

