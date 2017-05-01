;!/usr/bin/nasm -fbin
; @file boot.asm
; @brief system boot sector

%macro org2 2
	times	(%1)-($-$$) %2
%endmacro

%macro puts	1
	lea	si, [%%1]
	push	%%2
	jmp	print
%%1	db	%1, 0
%%2:
%endmacro
%macro putl	1
	lea	si, [%%1]
	push	%%2
	jmp	print
%%1	db	%1, 13, 10, 0
%%2:
%endmacro
%macro putnl	0
	lea	si, [__crlf]
	call	print
%endmacro
%macro putdot	0
	mov	ax, 0x0E2E
	int	0x10
%endmacro
%macro putfail	0
	lea	si, [__failmsg]
	call	print
%endmacro
%macro putok	0
	lea	si, [__okmsg]
	call	print
%endmacro
%macro putinf	1
	lea	si, [__infmsg]
	call	print
	puts	%1
%endmacro


[org 0x7C00]
[bits 16]
StackTop:
_start:	jmp	short entry
	org2	3, nop

OEMIentifier		db	"YYOS    "
BiosParameterBlock:
bpbBytesPerSector	dw	512
bpbSectorsPerCluster	db	1
bpbReservedSectors	dw	1 + setup_len
bpbNumberOfFATs		db	2
bpbRootEntries		dw	224
bpbTotalSectors		dw	2880
bpbMedia		db	0xF8;0xF1
bpbSectorsPerFAT	dw	9
bpbSectorsPerTrack	dw	18
bpbHeadsPerCylinder	dw	2
bpbHiddenSectors	dd	0
bpbTotalSectorsBig	dd	0
bsDriveNumber		db	0x00
bsUnused		db	0
bsExtBootSignature	db	0x29
bsSerialNumber		dd	0xA0A1A2A3
bsVolumeLabel		db	"YYOS FLOPPY"
bsFileSystem		db	"FAT12   "

entry:	xor	ax, ax
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, StackTop
	push	ax
	push	word go
	retf
go:	xor	dx, dx	;movzx	dx, byte [bsDriveNumber]
	mov	cx, 0x0002
	mov	bx, _setup
	mov	ax, 0x0200 + setup_len
	int	0x13
	jnc	ok
	xor	ax, ax
	int	0x13
	jmp	go
ok:	jmp	_setup

halt:	hlt
	jmp	halt

	org2	510, db 0
	dw	0xAA55

_setup:	lea	si, [boot_msg]
	call	print

	putl	"Loading System..."

	putinf	"Load Root Directory"
	xor	dx, dx
	mov	es, dx
	mov	ax, 32
	mul	word [bpbRootEntries]
	div	word [bpbBytesPerSector]
	mov	cx, ax
	movzx	ax, byte [bpbNumberOfFATs]
	mul	word [bpbSectorsPerFAT]
	add	ax, word [bpbReservedSectors]
	mov	word [RootBegin], ax
	add	word [RootBegin], cx
RootBuffer	equ	0xD000
FATBuffer	equ	0xD000
ImgBufSeg	equ	0x0F60
	lea	bx, [RootBuffer]
	call	ReadDisk
	putok

	putinf	"Browse Root Directory..."
	mov	dx, word [bpbRootEntries]
	lea	di, [RootBuffer]
.scan	mov	cx, 11
	lea	si, [ImageName]
	push	di
	cld
	repz
	cmpsb
	pop	di
	je	.found
	add	di, 32
	dec	dx
	jnz	.scan
	jmp	error
.found	putok

	putinf	"Load FAT"
	mov	dx, word [di + 0x1A]
	mov	word [ImgCluster], dx
	movzx	ax, byte [bpbNumberOfFATs]
	mul	word [bpbSectorsPerFAT]
	mov	cx, ax
	mov	ax, word [bpbReservedSectors]
	lea	bx, [FATBuffer]
	call	ReadDisk
	putok

	putinf	"Load Image"
	push	es
	mov	ax, ImgBufSeg
	mov	es, ax
.read	mov	ax, word [ImgCluster]
	sub	ax, 2
	movzx	cx, byte [bpbSectorsPerCluster]
	mul	cx
	add	ax, word [RootBegin]
	xor	bx, bx
	call	ReadDisk
	mov	ax, word [ImgCluster]
	mov	cx, ax
	shr	ax, 1
	add	ax, cx
	lea	bx, [FATBuffer]
	add	bx, ax
	mov	dx, word [bx]
	test	word [ImgCluster], 1
	jnz	.odd
	and	dx, 0xFFF
	jmp	.cont
.odd	shr	dx, 4
.cont	mov	word [ImgCluster], dx
	mov	ax, es
	add	ax, 0x20
	mov	es, ax
	cmp	dx, 0xFF0
	jb	.read
	pop	es
	putok

	putl	"Now, Entering Stage 2..."
	call	word ImgBufSeg : 0
	puts	"WARNING: Stage 2 Returns!"
	jmp	error

	align	2
ImgCluster	dw	0
RootBegin	dw	0
ImageName	db	"STARTUP COM"

error:	putfail
	putnl
	putnl
	putl	"An Error occurred during the boot stage."
	puts	"Press any key to restart"
	mov	ah, 0
	int	0x16
	putnl
	int	0x19
	jmp	word 0xF000 : 0xFFF0

ReadDisk:
	push	es
.next	push	cx
	push	bx
	push	ax
.read	xor	dx, dx
	div	word [bpbSectorsPerTrack]
	inc	dl
	mov	cl, dl	; sector
	xor	dx, dx
	div	word [bpbHeadsPerCylinder]
	mov	dh, dl	; head
	mov	ch, al	; cylinder
	mov	dl, byte [bsDriveNumber]	; drive
	mov	ax, 0x0201	; read one sector once
	int	0x13
	pop	ax
	pop	bx
	jc	.bad
	mov	cx, es
	add	cx, 0x20
	mov	es, cx
	inc	ax
	pop	cx
	push	ax;;;
	putdot
	pop	ax;;;
	loop	.next
	pop	es
	;push	ax;;;
	;push	si
	;puts	"done"
	;pop	si
	;pop	ax;;;
	ret
.bad	dec	byte [.toleration]
	jz	error
	xor	ax, ax
	int	0x13
	jmp	.read

.toleration	db	5

print:	mov	ah, 14
.loop	lodsb
	test	al, al
	jz	.done
	int	0x10
	jmp	.loop
.done	ret

__infmsg	db	13, "[      ] ", 0
__failmsg	db	13, "[ FAIL ] ", 13, 10, 0
__okmsg		db	13, "[  OK  ] "
__crlf		db	13, 10, 0
boot_msg	db	13, 10, "==> Boot Stage 1", 13, 10, 10, 0

	org2	2048, db 0

setup_len	equ	($ - _setup + 511) / 512

%if 0
	sar str aas fild jno into rol
%endif
