PROJECT = init

$(PROJECT).prg: $(PROJECT).asm bios.inc kernel.inc
	rcasm -l -v -x -d 1802 $(PROJECT) > $(PROJECT).lst
	hextobin $(PROJECT)

clean:
	-rm $(PROJECT).prg
	-rm $(PROJECT).bin

