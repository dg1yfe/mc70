#
# File:         makefile
# Description:  Make mc70 firmware
#
# Felix Erckenbrecht / dg1yfe
#
#
# For debug
#CFLAGS+=-ggdb
AS=tasm
RM=rm -f


AFILES= firmware.asm debug.asm display.asm eeprom.asm int.asm io.asm isu.asm macros.asm math.asm mem.asm menu.asm menu_input.asm menu_mem.asm menu_top.asm pll_freq.asm regmem.asm subs.asm ui.asm

SOURCES=$(AFILES)

CPU= -68 -xb
FILL= -fff
BINARY= -b
OPTIONS=$(CPU) $(FILL) $(BINARY) -y -s 

#DOCS=

OFILES=$(AFILES:%.asm=%.bin)

all: mc70

4m: $(AFILES)
	$(AS) $(OPTIONS) -dBAND4M $< firmware.bin

2m: $(AFILES)
	$(AS) $(OPTIONS) -dBAND2M $< firmware.bin

70cm: $(AFILES)
	$(AS) $(OPTIONS) -dBAND70CM $< firmware.bin

mc70: $(AFILES)
	$(AS) $(OPTIONS) $< firmware.bin

sim: $(AFILES)
	$(AS) $(OPTIONS) -dSIM $< firmware.bin
	srec_cat firmware.bin -binary -Output firmware.s -Motorola --Data_Only

test: $(AFILES)
	$(AS) $(OPTIONS) -dTESTUNIT $< firmware.bin
	srec_cat firmware.bin -binary -Output firmware.s -Motorola --Data_Only

clean:
	rm -rf *.bin
	rm -rf *.sym

