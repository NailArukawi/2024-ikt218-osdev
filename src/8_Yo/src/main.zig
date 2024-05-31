const std = @import("std");
const x86 = @import("x86.zig");
const tty = @import("tty.zig");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");
const keyboard = @import("keyboard.zig");

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    tty.panic("{s}", .{message});
}

pub export fn kernelMain() noreturn {
    tty.init();
    gdt.init();
    idt.init();
    keyboard.init();
    x86.sti(); // enable interupts

    tty.print("END OF DEMO! :^)\n", .{});
    while (true) x86.hlt();
}
