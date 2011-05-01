TASMTABS := d:\stuff2\tasm
export TASMTABS

all:    hex bin

prog:   
		peps3 firmware.bin
bin:
	d:\stuff2\tasm\tasm -68 -xb -fff -b firmware.asm firmware.bin
hex:
	d:\stuff2\tasm\tasm -68 -xb -fff -g0 -y firmware.asm firmware.hex
