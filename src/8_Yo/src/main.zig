const std = @import("std");
const tty = @import("tty.zig");
const gdt = @import("gdt.zig");
const x86 = @import("x86.zig");

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    tty.panic("{s}", .{message});
}

pub export fn kernelMain() noreturn {
    tty.init();
    gdt.init();

    tty.print("END OF DEMO! :^)\n", .{});
    while (true) x86.hlt();
}
