#define hard_cast(to_type, from_inst) \
	((to_type) (from_inst))
#define soft_cast(to_type, from_inst) \
	({ to_type __LOCAL_ptr = (from_inst); \
	 __LOCAL_ptr; })
#define null_instance(class) \
	hard_cast(class *, 0UL)
#define offsetof(class, member) \
	__builtin_offsetof(class, member)
#define container_of(class, member, mptr) \
	({ typeof(((class *) 0UL)->member) *__LOCAL_mptr = (mptr); \
	 (class *) (((char *) __LOCAL_mptr) - offsetof(class, member)); })

#define pass
#define defclass(class) \
	typedef struct class {
#define extends(base_class) \
	union { base_class base_##base_class; \
		base_class BaseClass; }
#define endclass(class) } class;

#define cast_to_base(base_class, derived_inst) \
	soft_cast(base_class *, &(derived_inst)->base_##base_class)
#define cast_to_derived(derived_class, base_inst) \
	soft_cast(derived_class *, container_of(derived_class, BaseClass, (base_inst)))

/* List Node, used for linking data types */
defclass(ListNode);
	struct ListNode *listNext;
endclass(ListNode);

/* Processor Node */
defclass(PNode);
endclass(PNode);

/* Task Node */
defclass(TNode);
endclass(TNode);
