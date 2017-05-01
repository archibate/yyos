typedef int cap_t;	/* capability */

typedef struct {	/* thread/task controller block */
	vcspace_t vcs;	/* virtual capability space */
} tcb_t;

typedef struct {	/* processor controller block */
	cap_t waiter;	/* who is waiting for signal occurred on this processor */
} pcb_t;

pcspace_t phy_cspace;	/* physical capability space */

void signal_occurred_on(pcb_t *proc)
{
	wake_up(proc->waiter);
}

void cap_map(vcspace_t *vcs, cidx_t vci, cap_t pc)
{
	vcs[vci] = pc;
}
