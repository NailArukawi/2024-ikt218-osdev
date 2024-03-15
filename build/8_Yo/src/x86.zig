// Read byte from a port.
pub inline fn in(comptime Type: type, port: u16) Type {
    return switch (Type) {
        u8 => asm volatile ("inb %[port], %[result]"
            : [result] "={al}" (-> Type),
            : [port] "N{dx}" (port),
        ),
        u16 => asm volatile ("inw %[port], %[result]"
            : [result] "={ax}" (-> Type),
            : [port] "N{dx}" (port),
        ),
        u32 => asm volatile ("inl %[port], %[result]"
            : [result] "={eax}" (-> Type),
            : [port] "N{dx}" (port),
        ),
        else => @compileError("Only u8, u16 or u32, found: " ++ @typeName(Type)),
    };
}

// Write byte to a port.
pub fn out(port: u16, data: anytype) void {
    switch (@TypeOf(data)) {
        u8 => asm volatile ("outb %[data], %[port]"
            :
            : [port] "{dx}" (port),
              [data] "{al}" (data),
        ),
        u16 => asm volatile ("outw %[data], %[port]"
            :
            : [port] "{dx}" (port),
              [data] "{ax}" (data),
        ),
        u32 => asm volatile ("outl %[data], %[port]"
            :
            : [port] "{dx}" (port),
              [data] "{eax}" (data),
        ),
        else => @compileError("Only u8, u16 or u32, found: " ++ @typeName(@TypeOf(data))),
    }
}

// Halt the CPU.
pub inline fn hlt() noreturn {
    while (true)
        asm volatile ("hlt");
}

// Disable interrupts.
pub inline fn cli() void {
    asm volatile ("cli");
}

// Enable interrupts.
pub inline fn sti() void {
    asm volatile ("sti");
}

// Completely stop the computer.
pub inline fn hang() noreturn {
    cli();
    hlt();
}

const GDTRegister = @import("gdt.zig").GDTRegister;
export var GDTR: [3]u16 = undefined;

// Load a new Interrupt Descriptor Table.
pub inline fn loadGDT(gdtr: GDTRegister) void {
    GDTR = @bitCast(gdtr);

    asm volatile (
        \\ cli
        \\ lgdt (GDTR)
        \\ jmp $0x08, $.reload_CS
        \\ .reload_CS:
        \\ movw $0x10, %ax
        \\ movw %ax, %ds
        \\ movw %ax, %es
        \\ movw %ax, %fs
        \\ movw %ax, %gs
    );
}

pub inline fn storeGDT() GDTRegister {
    var gdt_ptr = GDTRegister{ .limit = 0, .base = 0 };
    asm volatile ("sgdt %[tab]"
        : [tab] "=m" (gdt_ptr),
    );
    return gdt_ptr;
}

const IDTRegister = @import("idt.zig").IDTRegister;
export var IDTR: [3]u16 = undefined;

// Load a new Global Descriptor Table.
pub fn loadIDT(idtr: IDTRegister) void {
    IDTR = @bitCast(idtr);

    asm volatile (
        \\ lidt (IDTR)
    );
}
