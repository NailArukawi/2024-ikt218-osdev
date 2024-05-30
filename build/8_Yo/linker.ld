ENTRY(_start)

VERSION {
	VERS_1.0 {
		local:
			stack_bottom;
	};
}

SECTIONS {
	. = 1M;
	
	.multiboot : ALIGN(4K) {
		KEEP(*(.multiboot))
	}

	.text : ALIGN(4K) {
		*(.text .text.*)
	}
 
	.rodata : ALIGN(4K) {
		*(.rodata .rpdata.*)
	}
 
	.data : ALIGN(4K) {
		*(.data .data.*)
	}
 
	.bss : ALIGN(4K) {
		*(COMMON)
		*(.bss .bss.*)
	}

   _kernel_end = .;
}