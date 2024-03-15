const MAGIC: i32 = 0x1BADB002;
const FLAGS: i32 = (1 << 0) | (1 << 1);

const MultibootHeader = extern struct { magic: i32 = 0x1BADB002, flags: i32 = FLAGS, checksum: i32 = -(MAGIC + FLAGS) };

pub export const multiboot: MultibootHeader align(4) linksection(".multiboot") = .{};

const STACK_SIZE: u32 = 16 * 1024;

var stack: [STACK_SIZE]u8 align(4096) linksection(".bss") = undefined;
export var stack_bottom: [*]u8 = @as([*]u8, @ptrCast(&stack)) + @sizeOf(@TypeOf(stack));

export fn _start() callconv(.Naked) noreturn {
    asm volatile (
    // Setup the stack.
        \\ mov stack_bottom, %esp
        \\ movl %esp, %ebp

        // Pass (multiboot info structure, multiboot magic code).
        \\ push %ebx
        \\ push %eax

        // Call the kernel.
        \\ call kernelMain

        // Halt cpu.
        \\ cli
        \\ hlt
    );

    while (true) {}
}

export fn _stack_start() noreturn {
    @import("main.zig").kernelMain();
}
