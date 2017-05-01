
#define BEGFUNC(func) func:
#define ENDFUNC(func)

.section .phys.text	# in physical memory, no pagging

.global KeStartUpEntry
# kernel entry, booting up first processor
BEGFUNC(KeStartUpEntry)
	cli

	movl	$0x1234, 0x472	# BIOS warm boot

	sgdt	_KeSavedSuGdtRegister
	sidt	_KeSavedSuIdtRegister

	movl	%eax, KeMultibootMagic
	movl	%ebx, KeMultibootInfoPtr
	movl	%edx, KeRealModeServiceEntry

	#leal	wait_key_msg, %esi
	#movl	$1, %eax	# SuRmsPrint, print the string
	#call	*KeRealModeServiceEntry

	#movl	$2, %eax	# SuRmsWaitKeyPress
	#call	*KeRealModeServiceEntry

	#movl	$3, %eax	# SuRmsMachineShutdown
	#call	*KeRealModeServiceEntry

	#leal	boot_msg, %esi
	#movl	$22, %ecx
	#call	SerialOutString
	#leal	boot_msg + 2, %edi
	#movl	$7, %ecx
	#call	SerialInString
	#leal	boot_msg, %esi
	#movl	$22, %ecx
	#call	SerialOutString

	call	RelocateX86Structures

	call	init_boot_pd

	jmp	KeCoreStartUp
ENDFUNC(KeStartUpEntry)

#reg_t di, si, bp, sp, bx, ip;
.global SetJmpUserContext
BEGFUNC(SetJmpUserContext)
	movl	(%esp), %edx
	movl	%edx, 48(%eax)
	movl	%ebx, 16(%eax)
	movl	%esp, 12(%eax)
	movl	%ebp, 8(%eax)
	movl	%esi, 4(%eax)
	movl	%edi, (%eax)
	xorl	%eax, %eax
	ret
ENDFUNC(SetJmpUserContext)

.global LongJmpUserContext
BEGFUNC(LongJmpUserContext)
	#xchgl	%eax, %edx
	movl	(%edx), %edi
	movl	4(%edx), %esi
	movl	8(%edx), %ebp
	movl	12(%edx), %esp
	movl	16(%edx), %ebx
	jmp	*48(%edx)
ENDFUNC(LongJmpUserContext)

BEGFUNC(RelocateX86Structures)
	leal	_KeTss0Segment, %esi
	leal	_KeTssSegment, %edi
	movl	$_KeTss0SegmentEnd - _KeTss0Segment, %ecx
	cld
	rep
	movsb
	movw	 $_KeTssSegmentEnd - _KeTssSegment, _KeBootGdt_tss0
	leal	_KeBootIdt + 0x80 * 8, %edi
	movl	$KiInterruptHandler_SystemCall, %eax
	movw	%ax, (%edi)
	movw	$0x08, 2(%edi)
	#movw	$0x8E, 5(%edi)
	movw	$0xEE, 5(%edi)
	shrl	$16, %eax
	movw	%ax, 6(%edi)
	ret
ENDFUNC(RelocateX86Structures)

_KeTss0Segment:		# we don't use tss for task switch, we set it for ss0:esp0
	.long	0
	.long	_KeStackTop, 0x10	# load into %ss:%esp when a interrupt occurred
	.long	KeStartUpEntry, 0x08	# tss ss1:esp1, we use that for kernel %cs
	.long	0, 0
	.long	0
	.long	0, 0
	.long	0, 0, 0, 0, 0, 0, 0, 0
	.long	0, 0, 0, 0, 0, 0, 0
	.word	0
	.word	_KeTss0Iomap - _KeTss0Segment	# iomap base, offset in segment
_KeTss0Iomap:
	.byte	0xFF	# (it ends immediately :)
_KeTss0SegmentEnd:

#// Task state segment (TSS) format (as described by the Pentium architecture book):
#struct tss_segment {
#	uint16_t ts_backlink;   // Old TSS selector
#	uint16_t ts_padding0;
#	uintptr_t ts_esp0;      // Stack pointers and segment selectors
#	uint16_t ts_ss0;        //   after an increase in privilege level
#	uint16_t ts_padding1;
#	uintptr_t ts_esp1;
#	uint16_t ts_ss1;
#	uint16_t ts_padding2;
#	uintptr_t ts_esp2;
#	uint16_t ts_ss2;
#	uint16_t ts_padding3;
#	uintptr_t ts_cr3;       // Page directory base
#	uintptr_t ts_eip;       // Saved state from last task switch
#	uint32_t ts_eflags;
#	uint32_t ts_eax;        // More saved state (registers)
#	uint32_t ts_ecx;
#	uint32_t ts_edx;
#	uint32_t ts_ebx;
#	uintptr_t ts_esp;
#	uintptr_t ts_ebp;
#	uint32_t ts_esi;
#	uint32_t ts_edi;
#	uint16_t ts_es;         // Even more saved state (segment selectors)
#	uint16_t ts_padding4;
#	uint16_t ts_cs;
#	uint16_t ts_padding5;
#	uint16_t ts_ss;
#	uint16_t ts_padding6;
#	uint16_t ts_ds;
#	uint16_t ts_padding7;
#	uint16_t ts_fs;
#	uint16_t ts_padding8;
#	uint16_t ts_gs;
#	uint16_t ts_padding9;
#	uint16_t ts_ldt;
#	uint16_t ts_padding10;
#	uint16_t ts_trap;       // Trap on task switch
#	uint16_t ts_iomb;       // I/O map base offset
#	uint8_t ts_iomap[];     // I/O map (if has) (end with 0xFF)
#} __packed;

BEGFUNC(SerialInString)
	cld
1:	movw	$0x3FD, %dx
	inb	%dx, %al
	test	$1, %al
	jz	1b
	movw	$0x3F8, %dx
	insb
	loop	1b
	ret
ENDFUNC(SerialInString)

BEGFUNC(SerialOutString)
	movw	$0x3F8, %dx
	cld
	rep
	outsb
	ret
ENDFUNC(SerialOutString)

boot_msg:	.byte	13, 10
		.ascii	"Welcome to yyOS!"
		.byte	13, 10, 10, 0
wait_key_msg:	.ascii	"Press any key to shutdown."
		.byte	13, 10, 0

.global KeMultibootMagic, KeMultibootInfoPtr, KeRealModeServiceEntry
	.p2align 2
KeMultibootMagic:	.long	0
KeMultibootInfoPtr:	.long	0
KeRealModeServiceEntry:	.long	0

.global KeRealModeServiceCall
BEGFUNC(KeRealModeServiceCall)
	# call Su module routines, which is running in real mode
	movl	16(%esp), %edx
	movl	12(%esp), %ecx
	movl	8(%esp), %ebx
	movl	4(%esp), %eax

	pushl	%ebp
	pushl	%ebx
	pushl	%esi
	pushl	%edi

	pushfl

	pushl	$0
	popfl

	sgdt	_KeGdtRegister
	sidt	_KeIdtRegister

	lgdt	_KeSavedSuGdtRegister
	lidt	_KeSavedSuIdtRegister

	pushl	%gs
	pushl	%fs
	pushl	%es
	pushl	%ds

	call	*KeRealModeServiceEntry

	popl	%ds
	popl	%es
	popl	%fs
	popl	%gs

	lgdt	_KeGdtRegister
	lidt	_KeIdtRegister

	popfl
	popl	%edi
	popl	%esi
	popl	%ebx
	popl	%ebp
	ret
ENDFUNC(KeRealModeServiceCall)

.global _KiRestoreUserContextFromStack
BEGFUNC(_KiRestoreUserContextFromStack)
	# at 0x10176
	popal
	popl	%gs
	popl	%fs
	popl	%es
	popl	%ds
	testl	$3, 4(%esp)	# CS, check if we'll return to user
	jnz	1f	# if it will return to kernel,
			# we have to restore SS and ESP by software
			# as the x86-32 architecture defined,
			# 'iretl' does not pop out SS and ESP
			# when context CS.DPL == current DPL
	movl	%eax, %ss:eax
	movl	%ebp, %ss:ebp
	movl	%esp, %ebp
	movl	24(%ebp), %eax	# SS
	movl	%eax, %ss
	movl	20(%ebp), %esp	# ESP
	# we are using kernel stack (in order to 'iretl' from it)
	pushl	16(%ebp)	# EFLAGS
	pushl	12(%ebp)	# CS
	pushl	8(%ebp)		# EIP
	# restore the %eax and %ebp we've changed
	movl	%ss:eax, %eax	# fine, it's kernel %ss
	movl	%ss:ebp, %ebp
	#popl	2f	# EIP
	#popl	3f	# CS
	#popfl		# EFLAGS
	#xchgl	%eax, 4(%esp)	# SS
	#movl	%eax, %ss
	#xchgl	%eax, 4(%esp)	# restore the %eax we changed
	# note that next instruction will not be interrupted (see intel)
	#movl	(%esp), %esp	# ESP
	#ljmp	*2f	# jump to CS:EIP, memory referenced
1:	iretl		# will pop out all 5 registers in struct X86_CodeContext
#	.p2align 2
#2:	.long	0	# ljmp EIP
#3:	.long	0x08	# ljmp CS
eax:	.long	0
ebp:	.long	0
ENDFUNC(_KiRestoreUserContextFromStack)

BEGFUNC(enable_pagging)
	# enable PSE to use 4M pages
	movl	%cr4, %eax
	orl	$0x10, %eax	# CR4.PSE = 1
	movl	%eax, %cr4

	# write page directory base to CR3
	leal	_KeBootPageDir, %eax
	movl	%eax, %cr3

	# enable pagging and caches
	movl	%cr0, %eax
	andl	$0x9FFFFFFF, %eax	# CR0.CD = 0, CR0.NW = 0
	orl	$0x80000000, %eax	# CR0.PG = 1
	movl	%eax, %cr0

	# enable PGE to enable global pages (after enable pagging)
	movl	%cr4, %eax
	orl	$0x80, %eax	# CR4.PGE
	movl	%eax, %cr4
	ret
ENDFUNC(enable_pagging)

BEGFUNC(init_boot_pd)	# initialize the boot time page directory
	leal	_KeBootPageDir, %edi
	movl	$_KeBootPagePsePte + 3, _KeBootPageDir
	ret
ENDFUNC(init_boot_pd)

BEGFUNC(KeCoreStartUp)	# 32-bit code for initializing processor
	cs lgdt	_KeGdtRegister
	cs lidt	_KeIdtRegister

	ljmp	$0x08, $_KeCoreStartUp32

_KeCoreStartUp32:	# ljmp from _KeCoreStartUp16
	movw	$0x10, %ax	# set important segment registers
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %ss
	leal	_KeStackTop, %esp

	# load LDTR with NULL descriptor, since we doesn't use LDT in kernel
	xorw	%ax, %ax
	lldt	%ax

	# load TR, in order to use TSS
	movw	$0x28, %ax
	# at 0x10207
	ltr	%ax

	pushl	$0
	popfl		# clear EFLAGS, also disable interrupts

	#call	enable_pagging

	jmp	KeBootCoreNode
ENDFUNC(KeCoreStartUp)

BEGFUNC(_KeCoreStartUp16)
	.code16		# real mode startup routine for the ap processor
	cs lgdt	_KeGdtRegister - _KeCoreStartUp16
	cs lidt	_KeIdtRegister - _KeCoreStartUp16

	movl	%cr0, %eax
	orl	$1, %eax	# CR0.PE = 1, enable protected mode
	movl	%eax, %cr0

	.byte	0x66, 0xEA	# 32-bit ljmp instruction
	.long	_KeCoreStartUp32
	.word	0x08
	.code32

	.p2align 1
_KeGdtRegister:
	.word	_KeBootGdtEnd - _KeBootGdt - 1
	.long	_KeBootGdt

_KeIdtRegister:
	.word	_KeBootIdtEnd - _KeBootIdt - 1
	.long	_KeBootIdt
_KeCoreStartUp16End:
ENDFUNC(_KeCoreStartUp16)

	.p2align 1
_KeSavedSuGdtRegister:
	.word	0
	.long	0

_KeSavedSuIdtRegister:
	.word	0
	.long	0

	.p2align 3
_KeBootGdt:
	.quad	0x0000000000000000	# NULL descriptor
	.quad	0x00CF9B000000FFFF	# 32-bit, 4GiB code segment, DPL 0 (kernel)
	.quad	0x00CF93000000FFFF	# 32-bit, 4GiB data segment, DPL 0 (kernel)
	.quad	0x00CFFB000000FFFF	# 32-bit, 4GiB code segment, DPL 3 (user)
	.quad	0x00CFF3000000FFFF	# 32-bit, 4GiB data segment, DPL 3 (user)
_KeBootGdt_tss0:
	.quad	0x0000890030000000	#+ ((_KeTssSegment & 0xFFFFFF) << 16) + ((_KeTssSegment & 0xFF000000) << 32) + ((_KeTssSegmentEnd - _KeTssSegment) & 0xFFFF) + (((_KeTssSegmentEnd - _KeTssSegment) & 0xF0000) << 32)
_KeBootGdtEnd:

	#movw	%ax, (%edi)
	#movw	$0x08, 2(%edi)
	#movw	$0x8E, 5(%edi)
	## movw	$0xEE, 5(%edi) for swi
	#shrl	$16, %eax
	#movw	%ax, 6(%edi)

_KeBootIdt:
	.space	8 * 0x80
	.quad	0x0000000000000000
	.space	8 * 0x7F
_KeBootIdtEnd:

	.space	2048
_KeStackTop:

.equ	_KeBootPageDir,		0x1000
.equ	_KeBootPagePsePte,	0x2000
.equ	_KeTssSegment,		0x3000
.equ	_KeTssSegmentEnd,	_KeTssSegment + (_KeTss0SegmentEnd - _KeTss0Segment)
