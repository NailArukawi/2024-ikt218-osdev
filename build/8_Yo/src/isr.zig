const std = @import("std");
const tty = @import("tty.zig");
const x86 = @import("x86.zig");

const IDTEntry = @import("idt.zig").IDTEntry;

pub const IRQ: [16]u8 = .{ 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47 };

pub const Registers = extern struct {
    ds: usize,
    edi: usize,
    esi: usize,
    ebp: usize,
    esp: usize,
    ebx: usize,
    edx: usize,
    ecx: usize,
    eax: usize,
    number: usize,
    error_code: usize,
    eip: usize,
    cs: usize,
    eflags: usize,
    useresp: usize,
    ss: usize,
};

pub var interrupt_handlers: [256]?*const fn (Registers) void = .{null} ** 256;

extern fn isr0() void;
extern fn isr1() void;
extern fn isr2() void;
extern fn isr3() void;
extern fn isr4() void;
extern fn isr5() void;
extern fn isr6() void;
extern fn isr7() void;
extern fn isr8() void;
extern fn isr9() void;
extern fn isr10() void;
extern fn isr11() void;
extern fn isr12() void;
extern fn isr13() void;
extern fn isr14() void;
extern fn isr15() void;
extern fn isr16() void;
extern fn isr17() void;
extern fn isr18() void;
extern fn isr19() void;
extern fn isr20() void;
extern fn isr21() void;
extern fn isr22() void;
extern fn isr23() void;
extern fn isr24() void;
extern fn isr25() void;
extern fn isr26() void;
extern fn isr27() void;
extern fn isr28() void;
extern fn isr29() void;
extern fn isr30() void;
extern fn isr31() void;

comptime {
    const compFormat = std.fmt.comptimePrint;

    asm (
        \\ .extern isrHandler
        \\
        \\ .type isrCommon, @function
        \\
        \\ isrCommonStub:
        //  pushes edi, esi, ebp, esp, ebx, edx, ecx, eax
        \\  pusha
        //  save the data segment descriptor
        \\  mov %ds, %ax
        \\  push %eax
        //  load kernel data segment descriptor
        \\  mov $0x10, %ax
        \\  mov %ax, %ds
        \\  mov %ax, %es
        \\  mov %ax, %fs
        \\  mov %ax, %gs
        //  call handler implemented in zig
        \\  call isrHandler
        //  restore state
        \\  pop %eax 
        \\  mov %ax, %ds
        \\  mov %ax, %es
        \\  mov %ax, %fs
        \\  mov %ax, %gs
        //  pops edi, esi, ebp, esp, ebx, edx, ecx, eax
        \\  popa
        //  cleans up the pushed error code and pushed ISR number
        \\  add $0x8, %esp
        \\  sti
        //  pops 5 things at once: cs, eip, eflags, ss, and esp
        \\  iret
    );

    for (0..32) |isr_i| { // generate isr plugs
        switch (isr_i) {
            0...7, 9, 15...31 => { // add null argument, cpu only invokes without passing any argument
                asm (compFormat(
                        \\ .type isr{}, @function
                        \\ .global isr{}
                        \\
                        \\ isr{}:
                        \\  cli
                        \\  push $0
                        \\  push ${}
                        \\  jmp isrCommonStub
                    , .{ isr_i, isr_i, isr_i, isr_i }));
            },
            else => { // don't add null argmuent, cpu will pass argument
                asm (compFormat(
                        \\ .type isr{}, @function
                        \\ .global isr{}
                        \\
                        \\ isr{}:
                        \\  cli
                        \\  push ${}
                        \\  jmp isrCommonStub
                    , .{ isr_i, isr_i, isr_i, isr_i }));
            },
        }
    }
}

const exception_messages = [_][]const u8{
    "Division By Zero",
    "Debug",
    "Non Maskable Interrupt",
    "Breakpoint",
    "Into Detected Overflow",
    "Out of Bounds",
    "Invalid Opcode",
    "No Coprocessor",

    "Double Fault",
    "Coprocessor Segment Overrun",
    "Bad TSS",
    "Segment Not Present",
    "Stack Fault",
    "General Protection Fault",
    "Page Fault",
    "Unknown Interrupt",

    "Coprocessor Fault",
    "Alignment Check",
    "Machine Check",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",

    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
};

export fn isrHandler(registers: Registers) void {
    const old_fg = tty.getFG();
    defer tty.setFG(old_fg);
    tty.setFG(.Yellow);

    tty.print("[INTERUPT: {}] {s}\n", .{ registers.error_code, exception_messages[registers.error_code] });
}

extern fn irq0() void;
extern fn irq1() void;
extern fn irq2() void;
extern fn irq3() void;
extern fn irq4() void;
extern fn irq5() void;
extern fn irq6() void;
extern fn irq7() void;
extern fn irq8() void;
extern fn irq9() void;
extern fn irq10() void;
extern fn irq11() void;
extern fn irq12() void;
extern fn irq13() void;
extern fn irq14() void;
extern fn irq15() void;

comptime {
    const compFormat = std.fmt.comptimePrint;

    asm (
        \\ .extern irqHandler
        \\
        \\ .type isrCommon, @function
        \\
        \\ irqCommonStub:
        //  pushes edi, esi, ebp, esp, ebx, edx, ecx, eax
        \\  pusha
        //  save the data segment descriptor
        \\  mov %ds, %ax
        \\  push %eax
        //  load kernel data segment descriptor
        \\  mov $0x10, %ax
        \\  mov %ax, %ds
        \\  mov %ax, %es
        \\  mov %ax, %fs
        \\  mov %ax, %gs
        //  call handler implemented in zig
        \\  call irqHandler
        //  restore state
        \\  pop %ebx 
        \\  mov %bx, %ds
        \\  mov %bx, %es
        \\  mov %bx, %fs
        \\  mov %bx, %gs
        //  pops edi, esi, ebp, esp, ebx, edx, ecx, eax
        \\  popa
        //  cleans up the pushed error code and pushed ISR number
        \\  add $0x8, %esp
        \\  sti
        //  pops 5 things at once: cs, eip, eflags, ss, and esp
        \\  iret
    );

    for (0..32) |isr_i| { // generate isr plugs
        asm (compFormat(
                \\ .type irq{}, @function
                \\ .global irq{}
                \\
                \\ irq{}:
                \\  cli
                \\  push $0
                \\  push ${}
                \\  jmp irqCommonStub
            , .{ isr_i, isr_i, isr_i, isr_i + 32 }));
    }
}

export fn irqHandler(registers: Registers) void {
    if (registers.number >= 40)
        x86.out(0xA0, @as(u8, 0x20));
    x86.out(0x20, @as(u8, 0x20));

    if (interrupt_handlers[registers.number]) |handler|
        handler(registers);
}

pub fn init(IDT: *[256]u64) void {
    IDT[0] = (IDTEntry{ .address = @intFromPtr(&isr0), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[1] = (IDTEntry{ .address = @intFromPtr(&isr1), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[2] = (IDTEntry{ .address = @intFromPtr(&isr2), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[3] = (IDTEntry{ .address = @intFromPtr(&isr3), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[4] = (IDTEntry{ .address = @intFromPtr(&isr4), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[5] = (IDTEntry{ .address = @intFromPtr(&isr5), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[6] = (IDTEntry{ .address = @intFromPtr(&isr6), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[7] = (IDTEntry{ .address = @intFromPtr(&isr7), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[8] = (IDTEntry{ .address = @intFromPtr(&isr8), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[9] = (IDTEntry{ .address = @intFromPtr(&isr9), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[10] = (IDTEntry{ .address = @intFromPtr(&isr10), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[11] = (IDTEntry{ .address = @intFromPtr(&isr11), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[12] = (IDTEntry{ .address = @intFromPtr(&isr12), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[13] = (IDTEntry{ .address = @intFromPtr(&isr13), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[14] = (IDTEntry{ .address = @intFromPtr(&isr14), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[15] = (IDTEntry{ .address = @intFromPtr(&isr15), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[16] = (IDTEntry{ .address = @intFromPtr(&isr16), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[17] = (IDTEntry{ .address = @intFromPtr(&isr17), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[18] = (IDTEntry{ .address = @intFromPtr(&isr18), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[19] = (IDTEntry{ .address = @intFromPtr(&isr19), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[20] = (IDTEntry{ .address = @intFromPtr(&isr20), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[21] = (IDTEntry{ .address = @intFromPtr(&isr21), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[22] = (IDTEntry{ .address = @intFromPtr(&isr22), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[23] = (IDTEntry{ .address = @intFromPtr(&isr23), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[24] = (IDTEntry{ .address = @intFromPtr(&isr24), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[25] = (IDTEntry{ .address = @intFromPtr(&isr25), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[26] = (IDTEntry{ .address = @intFromPtr(&isr26), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[27] = (IDTEntry{ .address = @intFromPtr(&isr27), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[28] = (IDTEntry{ .address = @intFromPtr(&isr28), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[29] = (IDTEntry{ .address = @intFromPtr(&isr29), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[30] = (IDTEntry{ .address = @intFromPtr(&isr30), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();
    IDT[31] = (IDTEntry{ .address = @intFromPtr(&isr31), .attributes = 0x8E, .kernel_cs = 0x08 }).encode();

    // PIC
    x86.out(0x20, @as(u8, 0x11));
    x86.out(0x21, @as(u8, 0x20));
    x86.out(0xA0, @as(u8, 0x11));
    x86.out(0xA1, @as(u8, 0x28));
    x86.out(0x21, @as(u8, 0x04));
    x86.out(0xA1, @as(u8, 0x02));
    x86.out(0x21, @as(u8, 0x01));
    x86.out(0xA1, @as(u8, 0x01));
    x86.out(0x21, @as(u8, 0x00));
    x86.out(0xA1, @as(u8, 0x00));

    IDT[32] = (IDTEntry{ .address = @intFromPtr(&irq0), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[33] = (IDTEntry{ .address = @intFromPtr(&irq1), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[34] = (IDTEntry{ .address = @intFromPtr(&irq2), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[35] = (IDTEntry{ .address = @intFromPtr(&irq3), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[36] = (IDTEntry{ .address = @intFromPtr(&irq4), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[37] = (IDTEntry{ .address = @intFromPtr(&irq5), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[38] = (IDTEntry{ .address = @intFromPtr(&irq6), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[39] = (IDTEntry{ .address = @intFromPtr(&irq7), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[40] = (IDTEntry{ .address = @intFromPtr(&irq8), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[41] = (IDTEntry{ .address = @intFromPtr(&irq9), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[42] = (IDTEntry{ .address = @intFromPtr(&irq10), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[43] = (IDTEntry{ .address = @intFromPtr(&irq11), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[44] = (IDTEntry{ .address = @intFromPtr(&irq12), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[45] = (IDTEntry{ .address = @intFromPtr(&irq13), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[46] = (IDTEntry{ .address = @intFromPtr(&irq14), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
    IDT[47] = (IDTEntry{ .address = @intFromPtr(&irq15), .kernel_cs = 0x08, .attributes = 0x8e }).encode();
}
