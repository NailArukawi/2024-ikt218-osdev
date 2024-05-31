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
const pit = @import("pit.zig");

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
    pit.init();
    x86.sti(); // enable interupts

    var mem: allocator.KernelAllocator = .{};
    mem.allocBlock() catch @panic("Failed to start kernel allocator!");

    // lines are 256 bit so 512 bits span lines,
    // this shows allocations can be a size from 32 bytes to 4096 - 32 bytes
    // larger memory allocation system not implemented.
    const num1: *u512 = mem.create(u512).?;
    num1.* = 69;
    const num2: *u512 = mem.create(u512).?;
    num2.* = 420;
    const num3: *u512 = mem.create(u512).?;
    num3.* = num1.* + num2.*;

    mem.free(num1, 512);
    mem.free(num2, 512);
    tty.print("{} @ 0x{x} = {} @ 0x{x} + {} @ 0x{x}\n", .{
        num3.*, @intFromPtr(num3),
        num1.*, @intFromPtr(num1),
        num2.*, @intFromPtr(num2),
    });

    tty.print("[{}] Sleeping with busy-waiting (HIGH CPU)\n", .{pit.tick});
    pit.sleep(1000);
    tty.print("[{}]: Slept using busy-waiting.\n", .{pit.tick});

    tty.print("[{}] Sleeping with interrupts (LOW CPU).\n", .{pit.tick});
    pit.sleepHlt(1000);
    tty.print("[{}]: Slept using interrupts.\n", .{pit.tick});

    tty.print("END OF DEMO! :^)\n", .{});
    while (true) x86.hlt();
}
