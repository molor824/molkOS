.PHONY: all floppy_image kernel bootloader always

floppy_image: build/main_floppy.img

build/main_floppy.img: bootloader kernel
	dd if=/dev/zero of=build/bootloader.img bs=512 count=2880
	mkfs.fat -F 12 -n "MLOS" build/bootloader.img
	dd if=build/bootloader.bin of=build/bootloader.img conv=notrunc
	mcopy -i build/bootloader.img build/kernel.bin "::kernel.bin"

bootloader: build/bootloader.bin

build/bootloader.bin: always
	nasm src/bootloader/main.asm -f bin -o build/bootloader.bin

kernel: build/kernel.bin

build/kernel.bin: always
	nasm src/kernel/main.asm -f bin -o build/kernel.bin

build/main.bin: src/main.asm
	nasm src/main.asm -f bin -o build/main.bin

always:
	mkdir -p build