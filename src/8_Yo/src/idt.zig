const std = @import("std");
const tty = @import("tty.zig");
const isr = @import("isr.zig");
const x86 = @import("x86.zig");

const IDTEntryEncoded = packed struct(u64) {
    address_low: u16 = 0,
    kernel_cs: u16 = 0,
    reserved: u8 = 0,
    attributes: u8 = 0,
    address_high: u16 = 0,
};

pub const IDTEntry = struct {
    address: u32,
    kernel_cs: u16,
    reserved: u8 = 0,
    attributes: u8,

    pub fn encode(this: *const @This()) u64 {
        var result: IDTEntryEncoded = undefined;

        // address
        result.address_low = @truncate((this.address >> 0) & 0xFFFF);
        result.address_high = @truncate((this.address >> 16) & 0xFFFF);

        // kernel_cs
        result.kernel_cs = this.kernel_cs;

        // flags
        result.reserved = this.reserved;

        // flags
        result.attributes = this.attributes;

        return @bitCast(result);
    }
};

pub const IDTRegister = packed struct(u48) {
    limit: u16,
    base: *const u64,
};

pub var IDT: [256]u64 = undefined;

pub fn init() void {
    tty.print("Setup interrupt descriptor table...\t", .{});
    defer tty.print("OK\n", .{});

    isr.init(&IDT);

    x86.loadIDT(.{
        .limit = @as(u16, @sizeOf(u64) * 256) - 1,
        .base = &IDT[0],
    });
}
