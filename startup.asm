;!/usr/bin/nasm -fbin
; @file startup.asm
; @brief os startup module

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

%macro jmnop	0
	jmp	$+3
%endmacro

SA_STORAGE equ 1 << 4
SA_CODE equ 1 << 3
SA_CONFORM equ 1 << 2
SA_EXPANDOWN equ 1 << 2
SA_READ equ 1 << 1
SA_WRITE equ 1 << 1
SA_ACCESSED equ 1 << 0
SA_LIM4K equ 1 << 15
SA_32BIT equ 1 << 14
SA_VALID equ 1 << 7
SA_DPL_1 equ 1 << 5
SA_DPL_2 equ 2 << 5
SA_DPL_3 equ 3 << 5

struc Desc
.LimitLow resw 1
.BaseLow resw 1
.BaseMid resb 1
.Attributes resb 1
.LimitHigh resb 1
.BaseHigh resb 1
endstruc

%macro Descriptor	3
	dw	(%2) & 0xFFFF
	dw	(%1) & 0xFFFF
	db	((%1) >> 16) & 0xFF
	dw	(((%2) >> 8) & 0xF00) | (%3)
	db	((%1) >> 24) & 0xFF
%endmacro

[org 0xF600]
[bits 16]
_start:
	jmp	short SuMain
	nop

SuMain:
	jmp	0x0000 : .go
.go	xor	ax, ax
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, SuStackTop
	push	dword 0
	popfd

	lea	si, [startup_msg]
	call	print

;%macro ENTRY_FRAME 1
;%1:
;[bits 32]
;	mov	dword [SuExitStackPtr], esp
;	mov	ax, SuGdt.data16 - SuGdt
;	mov	ds, ax
;	mov	es, ax
;	mov	fs, ax
;	mov	gs, ax
;	mov	ss, ax
;	mov	esp, SuStackTop
;	push	dword SuGdt.code16 - SuGdt
;	push	dword %%1
;	retf
;%%1:
;[bits 16]
;	push	ebp
;	push	ebx
;	push	esi
;	push	edi
;%endmacro
;
;%macro EXIT_FRAME 0
;[bits 16]
;	pop	edi
;	pop	esi
;	pop	ebx
;	pop	ebp
;	mov	dx, SuGdt.data32 - SuGdt
;	mov	ds, dx
;	mov	es, dx
;	mov	fs, dx
;	mov	gs, dx
;	mov	ss, dx
;	mov	esp, dword [SuExitStackPtr]
;	mov	esp, KeTempStackTop
;	jmp	KeStartUpEntry
;	mov	edx, dword [esp]
;	mov	dword [esp], SuGdt.code32 - SuGdt
;	sub	esp, 4
;	mov	dword [esp], edx
;	db	0x66
;	retf
;%endmacro

;	ENTRY_FRAME	SuEnterRealMode
;	call	RealMode
;SuLeaveRealMode:
;	call	EnableProtect
;	EXIT_FRAME

SuDoSomeRubbishWorks:
	push	ds
	push	es
	call	SetupVideo
	mov	edi, dword [video_ram]
	;cli
	;hlt
	;;;
	;;mov	edi, 0xA0000
	;mov	eax, edi
	;shr	eax, 4
	;test	eax, 0xFFF0000
	;jnz	$
	;mov	es, ax
	;and	di, 0xF
	;mov	ax, word [screen_x]
	;mov	cx, word [screen_y]
	;mul	cx
	;mov	dl, byte [bits_per_pixel]
	;mul	dl
	;mov	cx, ax
	;mov	cx, 1238
	;mov	al, 0xFF
	;cld
	;rep
	;stosb
	;;;
	;mov	ax, 0xA000
	;mov	es, ax
	;mov	dword [es:0x124], 12345678
	;sub	di, di
	;mov	eax, 12345678
;.1	mov	cx, (1024 * 768 * 3 / 4) / 123
	;cld
	;rep
	;stosd
	;dec	word [.tmp]
	;jnz	.1
	;jmp	.2
;.tmp	dw	123
;.2	nop;;
	pop	es
	pop	ds
	;mov	ax, 0x0E2E
	;int	0x10
	;mov	ax, 0x0E2E
	;int	0x10
	;mov	ax, 0x0E00 + 'O'
	;int	0x10
	;mov	ax, 0x0E00 + 'k'
	;int	0x10

TransferToKernel:
	call	EnableProtect
	mov	ax, SuGdt.data32 - SuGdt
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	mov	esp, KeTempStackTop
	xor	eax, eax
	mov	ebx, eax
	mov	edx, SuRealModeServiceCallEntry
	push	dword SuGdt.code32 - SuGdt
	push	dword KeStartUpEntry
	db	0x66
	retf

;	ENTRY_FRAME	SuRealModeServiceCall
;	call	RealMode
;	puts	"RealModeService called"
;	lea	si, [test_msg]
;	call	print
;	mov	eax, 1
;	push	eax
;	call	EnableProtect
;	pop	eax
;	EXIT_FRAME
;SuExitStackPtr	dd	0

;again	push	eax
;	call	EnableProtect
;	pop	eax
;	EXIT_FRAME
;	ENTRY_FRAME	SuRealModeServiceCall
;	call	RealMode
;	lea	si, [test_msg]
;	call	print
;	mov	eax, SuRealModeServiceCall
;	jmp	again

RealMode:
	push	dword 0
	popfd
	sgdt	[GdtRegister]
	sidt	[IdtRegister]
	mov	eax, cr0
	btc	eax, 0
	mov	cr0, eax
	mov	eax, cr3
	mov	cr3, eax
	push	word 0
	push	word .goon
	retf
.goon	xor	ax, ax
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	lidt	[OldIdtRegister]
	lgdt	[OldGdtRegister]
	ret

EnableProtect:
	push	dword 0
	popfd
	sidt	[OldIdtRegister]
	sgdt	[OldGdtRegister]
	lidt	[IdtRegister]
	lgdt	[GdtRegister]
	mov	eax, cr0
	bts	eax, 0
	mov	cr0, eax
	;push	word SuGdt.code32 - SuGdt
	;push	word .goon
	;retf
	;db	0x66, 0xEA
	;dd	.goon
	;dw	SuGdt.code16 - SuGdt
	jmp	dword SuGdt.code16 - SuGdt : .goon
.goon	mov	ax, SuGdt.data16 - SuGdt
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	xor	ax, ax
	lldt	ax
	ret

VideoInfoBuf	equ	VideoInfoBuffer

SetupVideo:
	lea	di, [VideoInfoBuf]
	;jmp	.novbe
.check_vbe:
	mov	ax, 0x4F00
	int	0x10
	cmp	ax, 0x004F
	jne	.novbe
	cmp	word [di + 0x04], 0x0200
	jb	.novbe
.check_vbe_mode:
	mov	cx, 0x118
	mov	ax, 0x4F01
	int	0x10
	cmp	ax, 0x004F
	jne	.novbe
	mov	ax, word [di]
	test	ax, 0x0080
	jz	.novbe
.save_vbe0x118mode_info:
	mov	word [video_mode], 0x0118
	mov	ax, word [di + 0x12]
	mov	word [screen_x], ax
	mov	ax, word [di + 0x14]
	mov	word [screen_y], ax
	mov	al, byte [di + 0x19]
	mov	byte [bits_per_pixel], al
	mov	ax, word [di + 0x28]
	mov	word [video_ram], ax
	mov	ax, word [di + 0x2A]
	mov	word [video_ram + 2], ax
	int	0x10
.set_vbe0x118_mode:
	mov	bx, 0x4118
	mov	ax, 0x4F02
	int	0x10
	ret
.novbe:
.set_vga0x13_mode:
	mov	ax, 0x0013
	int	0x10
	mov	word [video_mode], 0x13
	mov	word [screen_x], 320
	mov	word [screen_x], 200
	mov	byte [bits_per_pixel], 8
	mov	ax, word [di + 0x28]
	mov	word [video_ram], ax
	mov	ax, word [di + 0x2A]
	mov	word [video_ram + 2], ax
	ret

	align	4
video_mode	dw	0
screen_x	dw	0
screen_y	dw	0
bits_per_pixel	db	0
memory_model	db	0
video_ram	dd	0

	align	2
GdtRegister:
	dw	SuGdtEnd - SuGdt - 1
	dd	SuGdt
IdtRegister:
	dw	0
	dd	0
OldGdtRegister:
	dw	0
	dd	0
OldIdtRegister:
	dw	0
	dd	0

EnableA20:
	call	empty_8042
	mov	al, 0xD1
	out	0x64, al
	call	empty_8042
	mov	al, 0xDF
	out	0x60, al
	call	empty_8042
	ret
empty_8042:
	jmnop
	jmnop
	in	al, 0x64
	test	al, 0x02
	jnz	empty_8042
	ret

halt:	cli
spin:	hlt
	jmp	spin
shutdown:
	mov	ax, 0x5301
	xor	bx, bx
	int	0x15
	mov	ax, 0x530E
	mov	cx, 0x0102
	int	0x15
	mov	ax, 0x5307
	mov	bl, 0x01
	mov	cx, 0x0003
	int	0x15

print:	;f7d6
	mov	ah, 0x0E
.loop	lodsb
	test	al, al
	jz	.done
	int	0x10
	jmp	.loop
.done	ret

SuGdt:
.null		Descriptor	0, 0, 0
.code32		Descriptor	0x00000000, 0xFFFFF, SA_VALID | SA_STORAGE | SA_32BIT | SA_LIM4K | SA_CODE | SA_READ
.data32		Descriptor	0x00000000, 0xFFFFF, SA_VALID | SA_STORAGE | SA_32BIT | SA_LIM4K | SA_WRITE
.ucode32	Descriptor	0x00000000, 0xFFFFF, SA_VALID | SA_STORAGE | SA_32BIT | SA_LIM4K | SA_CODE | SA_READ | SA_DPL_3
.udata32	Descriptor	0x00000000, 0xFFFFF, SA_VALID | SA_STORAGE | SA_32BIT | SA_LIM4K | SA_WRITE | SA_DPL_3
.code16		Descriptor	0x00000000, 0xFFFF, SA_VALID | SA_STORAGE | SA_CODE | SA_READ
.data16		Descriptor	0x00000000, 0xFFFF, SA_VALID | SA_STORAGE | SA_WRITE
;.tss0		Descriptor	0xFFFF, 0xFFFF, 0x9 | SA_VALID
SuGdtEnd:

__infmsg	db	13, "[      ] ", 0
__failmsg	db	13, "[ FAIL ] ", 13, 10, 0
__okmsg		db	13, "[  OK  ] "
__crlf		db	13, 10, 0
startup_msg	db	13, 10, "==> Boot Stage 2", 13, 10, 10, 0
test_msg	db	13, 10, "Hello, World!", 13, 10, 0

SuStackTop:
	org2	1024, db 0
KeTempStackTop:

[bits 32]
SuRealModeServiceCallEntry:
	xchg	esp, dword [SuSavedStackPtr]
	push	ss
	pop	dword [SuSavedStackSeg]
	push	dword SuGdt.code16 - SuGdt
	push	dword .real
	retf
.back	xchg	ax, word [SuSavedStackSeg]
	mov	ss, ax
	mov	ax, word [SuSavedStackSeg]
	xchg	esp, dword [SuSavedStackPtr]
	ret
[bits 16]
.real	push	eax
	push	ebx
	push	ecx
	push	edx
	call	RealMode
	pop	ax
	pop	bp
	test	ah, ah
	jnz	.srv2
	mov	byte [.servnr], al
	pop	si
	pop	di
	pop	dx
	pop	bx
	pop	ax
	pop	cx
	db	0xCD
.servnr	db	0x10
	jmp	.done
.srv2	pop	eax
	pop	ecx
	pop	edx
	cmp	eax, 0
	je	.0
	cmp	eax, 1
	je	.1
	cmp	eax, 2
	je	.2
	cmp	eax, 3
	je	.3
	putl	"WARNNING: Unknown RealModeService Called"
	jmp	.done
.fail	putl	"ERROR: RealModeService Failed"
.0	jmp	.done
.1	mov	eax, ecx
	and	cx, 0xF
	mov	si, cx
	shr	eax, 4
	test	eax, 0xFFF0000
	jnz	.fail
	push	ds
	mov	ds, ax
	call	print
	pop	ds
	jmp	.done
.2	mov	ah, 0x00
	int	0x16
.3	putl	"Shuting down..."
	jmp	shutdown
.done	call	EnableProtect
	push	dword SuGdt.code32 - SuGdt
	push	dword .back
	db	0x66
	retf

	align	4
SuSavedStackPtr:
	dd	SuStackTop
SuSavedStackSeg:
	dd	0

	org2	1320, db 0
VideoInfoBuffer:
	org2	1640, db 0
	org2	0x10000 - 0xF600, db 0
[bits 32]
KeStartUpEntry:
