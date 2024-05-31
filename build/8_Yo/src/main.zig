const std = @import("std");
const tty = @import("tty.zig");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");
const x86 = @import("x86.zig");
const entry = @import("entry.zig");
const keyboard = @import("keyboard.zig");
const pmm = @import("pmm.zig");
const vmm = @import("vmm.zig");
const allocator = @import("allocator.zig");

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    tty.panic("{s}", .{message});
}

pub export fn kernelMain() noreturn {
    tty.init();
    gdt.init();
    idt.init();
    pmm.init();
    keyboard.init();

    vmm.init() catch @panic("Failed to init paging!");
    x86.sti(); // enable interupts

    var mem: allocator.KernelAllocator = .{};
    mem.allocBlock() catch @panic("Failed to start kernel allocator!");

    const num1: *u32 = @ptrCast(@alignCast(&mem.alloc(32).?[0]));
    num1.* = 69;
    const num2: *u32 = @ptrCast(@alignCast(&mem.alloc(32).?[0]));
    num2.* = 420;
    const num3: *u32 = @ptrCast(@alignCast(&mem.alloc(32).?[0]));
    num3.* = num1.* + num2.*;
    tty.print("sized: {}\n", .{num3.*});
    tty.print("Hello, sludracks!\n\tthis is Yo!\n", .{});
    while (true) {}
}
