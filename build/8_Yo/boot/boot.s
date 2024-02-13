.global _start
.type _start, @function

_start:
    mov $0x80000, %esp  // Setup the stack.

    push %ebx   // Pass multiboot info structure.
    push %eax   // Pass multiboot magic code.

    call kernelMain  // Call the kernel.

    // Halt the CPU.
    cli
    hlt