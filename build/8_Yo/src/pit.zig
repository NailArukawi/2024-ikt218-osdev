const std = @import("std");
const isr = @import("isr.zig");
const tty = @import("tty.zig");
const x86 = @import("x86.zig");

pub var tick: u64 = 0; // current system tick since boot.
var tick_per_ms: usize = 0;

pub fn init() void {
    tty.print("Setup PIT...\t", .{});
    defer tty.print("OK\n", .{});
    isr.interrupt_handlers[32] = handlerPit0;

    tick_per_ms = 1000 / 1000;
    const divider: u32 = 1193180 / 1000;

    x86.out(0x43, @as(u8, 0x36));
    x86.out(0x43, @as(u16, @truncate(divider)));
}

fn handlerPit0(_: isr.Registers) void {
    tick += 1;
}

pub fn sleep(ms: u32) void {
    const end_tick = tick + ms / tick_per_ms;
    while (tick < end_tick) {}
}

pub fn sleepHlt(ms: u32) void {
    const end_tick = tick + ms / tick_per_ms;
    while (tick < end_tick) x86.hlt();
}
