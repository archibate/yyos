ENTRY(KeStartUpEntry)

SECTIONS {
	. = 0x10000;

	.text : {
		*(.phys.*)
		*(.text)
	}
	.data : {
		*(.data)
	}
	.bss : {
		*(.bss)
		*(COMMON)
	}

	/DISCARD/ : {
		*(.note)
		*(.comment)
		/* *(.GNU-stack)
		*(.eh_frame) */
	}
}
