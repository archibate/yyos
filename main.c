#define BOOT_CODE
#define NORETURN __attribute__((__noreturn__))
#define UNREACHABLE() __builtin_unreachable()
#define ARRAY_SIZEOF(a) (sizeof(a) / sizeof(a[0]))
#define ARRAY_TOP_OF(a) ((a) + ARRAY_SIZEOF(a))
#define ASMLINKAGE __attribute__((regparm(3)))
#define PACKED __attribute__((packed))

typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned int uint;
typedef unsigned long ulong;
typedef unsigned long long ulonglong;
typedef uchar uint8_t;
typedef ushort uint16_t;
typedef uint uint32_t;
typedef ulong uintptr_t;
typedef ulonglong uint64_t;
typedef uint word_t;
typedef uchar byte_t;

typedef uintptr_t reg_t;

typedef struct X86_SavedRegContext {
	reg_t di, si, bx, bp;
} X86_VolatileRegContext_t;

typedef struct X86_UnsavedRegContext {
	reg_t dx, cx, ax;
} X86_UnsavedRegContext_t;

typedef struct X86_PushaSavedRegContext {
	reg_t di, si, bp, sp, bx;
} X86_PushaSavedRegContext_t;

typedef struct X86_PushaRegContext {
	reg_t di, si, bp, sp, bx;
	reg_t dx, cx, ax;
} X86_PushaRegContext_t;

typedef struct X86_DataSegContext {
	reg_t gs, fs, es, ds;
} X86_DataSegContext_t;

typedef struct X86_CodeContext {
	reg_t ip;
	reg_t cs;
	reg_t eflags;
	reg_t sp;
	reg_t ss;
} X86_CodeContext_t;

typedef struct UserContext {
	X86_PushaRegContext_t PushaRegs;
	X86_DataSegContext_t DataSegs;
	X86_CodeContext_t Code;
} UserContext_t;

uint32_t KeMultibootMagic;
void *KeMultibootInfoPtr;
void *KeRealModeServiceEntry;
uint64_t KeRealModeServiceCall(uintptr_t eax, uintptr_t ebx,
		uintptr_t ecx, uintptr_t edx);
char _KiRestoreUserContextFromStack[0];
long ASMLINKAGE SetJmpUserContext(UserContext_t *uc);
void ASMLINKAGE NORETURN LongJmpUserContext(long r, UserContext_t *uc);

void NORETURN KiRestoreUserContext(UserContext_t *pUserContext)
{
	asm volatile (	"leal %0, %%esp\n\t"
			"jmp _KiRestoreUserContextFromStack\n\t"
			:: "m" (*pUserContext));
	UNREACHABLE();
}

uint32_t KeBiosServiceCall(uint8_t serv_nr, uint16_t ax, uint16_t cx, uint16_t dx, uint16_t bx, uint16_t si, uint16_t di, uint16_t bp)
{
#define MKDW(low, high) \
	(((uint32_t) (low) & 0xFFFF) | \
	 (((uint32_t) (high) & 0xFFFF) << 16))
	uint64_t res = KeRealModeServiceCall(MKDW(ax, cx), MKDW(dx, bx),
			MKDW(si, di), MKDW(serv_nr, bp));
	dx = (res >> 32) & 0xFF;
	ax = res & 0xFF;
	return ax | (dx << 16);
}

void SuRmsCall_FillRect(uint8_t nl, uint8_t col,
		uint8_t x0, uint8_t y0, uint8_t x1, uint8_t y1)
{
	KeBiosServiceCall(0x10, 0x0600 | nl,
			x0 + (y0 << 8), x1 + (y1 << 8),
			col << 8, 0, 0, 0);
}

void SuRmsCall_MoveCursor(uint16_t xy, uint8_t pg)
{
	KeBiosServiceCall(0x10, 0x0200, 0, xy,
			pg << 8, 0, 0, 0);
}

void SuRmsCall_MoveCursorPos(uint8_t x, uint8_t y, uint8_t pg)
{
	SuRmsCall_MoveCursor(x + (y << 8), pg);
}

uint16_t SuRmsCall_GetCursor(uint8_t pg)
{
	uint32_t res = KeBiosServiceCall(0x10, 0x0300, 0, 0,
			pg << 8, 0, 0, 0);
	return res >> 16;
}

uint16_t SuRmsCall_WaitKeyPress(void)
{
	return KeBiosServiceCall(0x16, 0x0000, 0, 0, 0, 0, 0, 0);
}

void SuRmsCall_PutOneChar(uint8_t c, uint8_t pg)
{
	KeBiosServiceCall(0x10, 0x0A00 | c, 1, 0, pg << 8, 0, 0, 0);
}

void SuRmsCall_SimplePutChar(uint8_t c, uint8_t pg)
{
	SuRmsCall_MoveCursor(SuRmsCall_GetCursor(pg) + 1, pg);
	SuRmsCall_PutOneChar(c, pg);
}

int SuRmsCall_SimplePrint(const char *s)
{
	uint8_t ch;
	const char *orig_s = s;
	while (ch = *s++) {
		//SuRmsCall_SimplePutChar(ch, 0);
		KeBiosServiceCall(0x10, 0x0E00 | ch,
				0, 0, 0, 0, 0, 0);
	}
	return s - orig_s;
}

void NORETURN KeProcessorDie(void)
{
	for (;;);
	UNREACHABLE();
}

void NORETURN KeProcessorHalt(void)
{
	for (;;)
		asm volatile ("cli; hlt");
	UNREACHABLE();
}

void NORETURN KernelFail(const char *s)
{
	SuRmsCall_SimplePrint("kernel fail occurred: ");
	SuRmsCall_SimplePrint(s);
	SuRmsCall_SimplePrint("\r\n");
	KeProcessorHalt();
}

void NORETURN KeMachineShutdown(void)
{
	KeRealModeServiceCall(0, 0, 3, ~0UL);
	KernelFail("KeMachineShutdown: failed to poweroff using "
			 "real mode service cx=3 dx=(~0UL)");
}

#define RtTaskActiveMax 64

typedef struct RtTaskCtl {
	UserContext_t UserContext;
	struct {
		struct RtTaskCtl *tcbNext;
	};
} RtTaskCtl_t;

RtTaskCtl_t RtTaskActiveTable[RtTaskActiveMax];
RtTaskCtl_t *RtTaskReady = &RtTaskActiveTable[0];

#define _ObGenerateIpcHandlerControllerBlockInstance() 0UL

void NORETURN RtRestoreTaskReady(void)
{
	KiRestoreUserContext(&RtTaskReady->UserContext);
	_ObGenerateIpcHandlerControllerBlockInstance();
}

void NORETURN RtSwitchToTask(RtTaskCtl_t *tcb)
{
	RtTaskReady = tcb;
	RtRestoreTaskReady();
}

typedef enum IpcState {
	IPC_UNINIT = 0,
	IPC_RUNNING,
	IPC_WAITING,
	IPC_WAIT_RECV,
	IPC_WAIT_SEND,
} IpcState_t;

typedef struct IpcCtl {
	RtTaskCtl_t *tcbWaiter;
	RtTaskCtl_t *tcbPoster;
	IpcState_t State;
	word_t wMessage;
} IpcCtl_t, cap_t;

void NORETURN cap_post(cap_t *cap)
/* client, post a request */
{
	RtTaskCtl_t *tcbWaiter = cap->tcbWaiter;
	RtTaskCtl_t *tcbPoster = RtTaskReady;
	cap->tcbPoster = tcbPoster;	/* client: hey, it's me! */
	RtSwitchToTask(tcbWaiter);	/* wait for his waiting on his cap */
}

void NORETURN cap_wait(cap_t *cap)
/* server, waiting for request */
{
	RtTaskCtl_t *tcbPoster = cap->tcbPoster;
	RtTaskCtl_t *tcbWaiter = RtTaskReady;
	cap->tcbWaiter = tcbWaiter;	/* server: hey, i'm here! */
	RtSwitchToTask(tcbPoster);	/* wait for her post on my cap */
}

void ASMLINKAGE KiInterruptHandler_SystemCall(uintptr_t ax, uintptr_t dx, uintptr_t cx)
{
	switch (ax) {
	case 1: {
			RtTaskCtl_t *tcbTo = (RtTaskCtl_t *) dx;
			RtSwitchToTask(tcbTo);
		} break;
	default: {
			 KeProcessorHalt();
			 KeMachineShutdown();
		 } break;
	}
}

void NORETURN SyscSwitch(RtTaskCtl_t *tcb)
{
	asm volatile ("int $0x80" :: "a" (1), "d" (tcb));
	UNREACHABLE();
}

void NORETURN SwicPost(cap_t *cap)
/* client, post a request */
{
	RtTaskCtl_t *tcbWaiter = cap->tcbWaiter;
	RtTaskCtl_t *tcbPoster = RtTaskReady;
	cap->tcbPoster = tcbPoster;	/* client: hey, it's me! */
	SyscSwitch(tcbWaiter);	/* wait for his waiting on his cap */
}

void NORETURN SwicWait(cap_t *cap)
/* server, waiting for request */
{
	RtTaskCtl_t *tcbPoster = cap->tcbPoster;
	RtTaskCtl_t *tcbWaiter = RtTaskReady;
	cap->tcbWaiter = tcbWaiter;	/* server: hey, i'm here! */
	SyscSwitch(tcbPoster);	/* wait for her post on my cap */
}

void SyncPost(cap_t *cap)
{
	if (!SetJmpUserContext(&RtTaskReady->UserContext)) {
		SwicPost(cap);
	}
}

void SyncWait(cap_t *cap)
{
	if (!SetJmpUserContext(&RtTaskReady->UserContext)) {
		SwicWait(cap);
	}
}

void SyncListen(cap_t *cap)
{
	SyncWait(cap);
}

void IpcSend(cap_t *cap, word_t wMessage)
{
	if (cap->State == IPC_WAIT_RECV) {
		KeProcessorDie();
		//SyscSwitch(cap->tcbWaiter);
		return;
	}
	cap->wMessage = wMessage;
	cap->State = IPC_WAIT_SEND;
	RtTaskReady->UserContext.PushaRegs.ax = 1UL;
	if (!SetJmpUserContext(&RtTaskReady->UserContext)) {
		SyncPost(cap);
	}
}

word_t IpcRecv(cap_t *cap)
{
	if (cap->State == IPC_WAIT_SEND) {
		cap->State = IPC_RUNNING;
		return cap->wMessage;
	}
	cap->State = IPC_WAIT_RECV;
	RtTaskReady->UserContext.PushaRegs.ax = 1UL;
	if (!SetJmpUserContext(&RtTaskReady->UserContext)) {
		SyncWait(cap);
	}
}

/* void SyncSwitch(cap_t *cap)
{
	if (!SetJmpUserContext(&RtTaskReady->UserContext)) {
		SyscSwitch(cap->tcbBlocked);
	}
} */

void NORETURN UserProcessExit(void)
{
	asm volatile ("int $0x80" :: "a" (2));
	UNREACHABLE();
}

cap_t capTest;
cap_t capHardware;	/* hardware is a 'task' */

char UserProcess0_Stack[2048];

void NORETURN UserProcess0_Main(void)
{
	volatile char test[1458];
	for (volatile char *p = test; p < ARRAY_TOP_OF(test); p++)
		*p = 0;
	capTest.tcbWaiter = &RtTaskActiveTable[1];
	capHardware.tcbWaiter = &RtTaskActiveTable[2];
	IpcSend(&capTest, 715);
	UserProcessExit();
	KernelFail("hey, should not reach here");
}

char UserProcess1_Stack[2048];

void NORETURN UserProcess1_Main(void)
{
	volatile char test[1458];
	for (volatile char *p = test; p < ARRAY_TOP_OF(test); p++)
		*p = 0;
	IpcRecv(&capTest);
	UserProcessExit();
	KeProcessorDie();
	KernelFail("hey, should not reach here");
}

typedef uint8_t colval_t;

typedef struct Color {
	colval_t blue;
	colval_t green;
	colval_t red;
} PACKED color_t;

#define RGBColor(r, g, b) ((color_t) {.red = (r), .green = (g), .blue = (b)})
#define RGBNum(x) (((union { color_t c; uint32_t i; }) {.i = 0x##x}).c)
#define ABS(x) ((x) > 0 ? (x) : -(x))
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define MIN(a, b) ((a) < (b) ? (a) : (b))

color_t *const XiVideoBuffer = (void *) 0xFD000000;
int const yScrn = 768;
int const xScrn = 1024;

int xOrig = 0;
int yOrig = 0;

void XiFillRect(int xBeg, int yBeg, int xSize, int ySize, color_t color)
{
	color_t *const buf = XiVideoBuffer + yOrig * xScrn + xOrig;
	for (int y = yBeg; y < yBeg + ySize; y++)
		for (int x = xBeg; x < xBeg + xSize; x++)
			buf[y * xScrn + x] = color;
}

void XiBresenhamLine(int x0, int y0, int x1, int y1, color_t color)
{
	color_t *const buf = XiVideoBuffer + yOrig * xScrn + xOrig;
	int dx = ABS(x1 - x0);
	int dy = ABS(y1 - y0);
	int k = (x1 - x0) * (y1 - y0);
	if (dx >= dy) {
		int p = 2 * dy + dx;
		x = MAX(x0, x1);
		while (x < x1) {
			buf[y * xScrn + x] = color;
			++x;
			if (p < 0) {
				p += 2 * dy;
			} else {
				if (k > 0)
					++y;
				else
					--y;
				p += 2 * dy - 2 * dx;
			}
		}
	}
}

void XiDrawOurLogo(void)
{
	xOrig = 0;
	yOrig = 0;
	XiFillRect(0, 0, xScrn, yScrn, RGBNum(262626));
	XiFillRect(0, 0, xScrn, yScrn, RGBNum(BC8F8F));
	XiFillRect(0, 0, xScrn, yScrn, RGBNum(959595));
	xOrig = 123;
	yOrig = 123;
	XiFillRect(6, 19, 239, 235, RGBNum(363636));
	XiFillRect(10, 23, 243, 243, RGBNum(C69F9F));
	XiFillRect(253, 23, 150, 243, RGBNum(A7C6F0));
	XiFillRect(192, 168, 10, 101, RGBNum(7D79DE));
	xOrig = 371;
	yOrig = 371;
	XiFillRect(180, 96, 86, 192, RGBNum(B0B0C2));
	xOrig = 347;
	yOrig = 347;
	XiFillRect(180, 96, 86, 192, RGBNum(FB9828));
	xOrig = 0;
	yOrig = 0;
	XiFillRect(0, 0, xScrn, yScrn, RGBNum(262626));
}

void BOOT_CODE NORETURN KeBootCoreNode(void)
{
	XiDrawOurLogo();
	KeProcessorHalt();
	SuRmsCall_FillRect(0, 0x3E, 0, 0, 79, 24);
	SuRmsCall_FillRect(0, 0x1F, 3, 2, 74, 21);
	SuRmsCall_MoveCursor(0, 0);
	SuRmsCall_PutOneChar('O', 0);
	SuRmsCall_MoveCursor(1, 0);
	SuRmsCall_PutOneChar('K', 0);
	SuRmsCall_MoveCursorPos(0, 1, 0);
	SuRmsCall_SimplePrint("Hello, World!\nHey, Dog?!\r\n");
	SuRmsCall_SimplePrint("This is my YYOS kernel!\r\n\n");
	SuRmsCall_SimplePrint("Probing TYW (tyw=off to disable)... ok\r\n");
	SuRmsCall_SimplePrint("Host controller error, PCI problems?\r\n");
	SuRmsCall_SimplePrint("KeBootCoreNode: TYW's in the rubbish bin\r\n");
	SuRmsCall_SimplePrint("[  OK  ] got a rubbish, i'll eat it\r\n");

	RtTaskActiveTable[0].UserContext = (UserContext_t) {
		.DataSegs.ds	= 0x23,
		.DataSegs.es	= 0x23,
		.DataSegs.fs	= 0x23,
		.DataSegs.gs	= 0x23,
		.Code.ss	= 0x23,
		.Code.sp	= (reg_t) ARRAY_TOP_OF(UserProcess0_Stack),
		.Code.cs	= 0x1B,
		.Code.eflags	= 0x0002,
		.Code.ip	= (reg_t) UserProcess0_Main,
	};
	RtTaskActiveTable[1].UserContext = (UserContext_t) {
		.DataSegs.ds	= 0x23,
		.DataSegs.es	= 0x23,
		.DataSegs.fs	= 0x23,
		.DataSegs.gs	= 0x23,
		.Code.ss	= 0x23,
		.Code.sp	= (reg_t) ARRAY_TOP_OF(UserProcess1_Stack),
		.Code.cs	= 0x1B,
		.Code.eflags	= 0x0002,
		.Code.ip	= (reg_t) UserProcess1_Main,
	};
	RtRestoreTaskReady();
	KeProcessorHalt();
}

/*
typedef struct task {
} tcb_t;

typedef struct sync {
	tcb_t *waiter;
	tcb_t *poster;
} syn_t;

typedef struct pipe {
	syn_t sync;
} pip_t;

pip_t piptab[64];

pip_t *pip_open2(int fidx)
{
	return &piptab[fidx];
}
*/
