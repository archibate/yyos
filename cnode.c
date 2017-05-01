typedef struct _Capability {
} Capability, cap_t;

typedef struct _CNode {
	Capability cap;
} CNode;

#define CSPACE_MAX 32

typedef struct _CSpace {
	cap_t *caps[CSPACE_MAX];
} CSpace;

void cap_wait(cap_t *cap)
{
}
