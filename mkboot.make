#!/bin/make -f
# @file mkboot.make
# @brief Makefile for the os loader and the boot image

CFLAGS+=-ggdb -gstabs+

.PHONY: all run qemu-run bochs-run

all: boot.img

run: qemu-run

qemu-run: boot.img
	qemu-system-i386 -fda $< -boot a -serial stdio

qemu-gdb: boot.img
	qemu-system-i386 -fda $< -boot a -serial stdio -S -gdb tcp::1234

start-gdb: oskernel.elf
	gdb -x gdbinit $<

bochs-run: boot.img
	echo -e 'romimage:    file=$$BXSHARE/BIOS-bochs-latest\n' \
		'vgaromimage: file=$$BXSHARE/VGABIOS-lgpl-latest\n' \
		'boot: a\nfloppya: 1_44="boot.img", status=inserted\n' \
		> /tmp/$$.bochsrc; bochs -qf /tmp/$$.bochsrc

boot.img: boot.com startup.com oskernel.com
	dd if=/dev/zero of=$@ bs=512 count=2880
	dd if=$< of=$@ bs=2048 count=1 conv=notrunc
	-mkdir -p imgdir
	((mount $@ imgdir || \
		(umount imgdir && \
			mount $@ imgdir)) && \
		cat startup.com oskernel.com > imgdir/STARTUP.COM; \
		umount imgdir)

boot.com: boot.asm
	nasm -fbin -o $@ $<

startup.com: startup.asm
	nasm -fbin -o $@ $<

oskernel.com: oskernel.elf
	objcopy -R .note -R .comment -Obinary -S $< $@

OBJS=head.o main.o
oskernel.elf: ${OBJS}
	ld -T oskernel.ld -o $@ $^
