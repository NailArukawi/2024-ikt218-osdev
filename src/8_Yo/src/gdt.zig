const std = @import("std");
const tty = @import("tty.zig");
const x86 = @import("x86.zig");

// Access byte values.
const KERNEL = 0x90;
const USER = 0xF0;
const CODE = 0x0A;
const DATA = 0x02;
const TSS_ACCESS = 0x89;

pub const GDTError = error{
    surpasses_encode_limits,
};

pub const GDTAccess = packed struct(u8) {
    accessed: bool = false,
    read_write: bool = false,
    direction_conforming: bool = false,
    executable: bool = false,
    descriptor: bool = false,
    privilege: u2 = 0,
    present: bool = false,
};

pub const GDTFlags = packed struct(u4) {
    reserved: bool = false,
    long: bool = false,
    size: bool = false,
    granularity: bool = false,
};

const GDTEntryEncoded = packed struct(u64) {
    limit_low: u16 = 0,
    base_low: u16 = 0,
    base_mid: u8 = 0,
    access: GDTAccess = .{},
    limit_high: u4 = 0,
    flags: GDTFlags = .{},
    base_high: u8 = 0,
};

pub const GDTEntry = struct {
    base: u32,
    limit: u20,
    access: GDTAccess,
    flags: GDTFlags,

    pub fn encode(this: *const @This()) u64 {
        var result: GDTEntryEncoded = .{};

        // base
        result.base_low = @truncate((this.base >> 0) & 0xFFFF);
        result.base_mid = @truncate((this.base >> 16) & 0xFF);
        result.base_high = @truncate((this.base >> 24) & 0xFF);

        // limit
        result.limit_low = @truncate((this.limit >> 0) & 0xFFFF);
        result.limit_high = @truncate((this.limit >> 16) & 0x0F);

        // access
        result.access = this.access;

        // flags
        result.flags = this.flags;

        return @bitCast(result);
    }
};

pub const GDTRegister = packed struct(u48) {
    limit: u16,
    base: *const u64,
};

const GDT = [_]u64{
    (GDTEntry{ .base = 0, .limit = 0, .access = .{}, .flags = .{} }).encode(), // NULL Descriptor
    (GDTEntry{ // Kernel Mode Code Segment
        .base = 0,
        .limit = 0xFFFFF,
        .access = .{ .read_write = true, .executable = true, .descriptor = true, .present = true },
        .flags = .{ .granularity = true, .size = true },
    }).encode(),
    (GDTEntry{ // Kernel Mode Data Segment
        .base = 0,
        .limit = 0xFFFFF,
        .access = .{ .read_write = true, .descriptor = true, .present = true },
        .flags = .{ .granularity = true, .size = true },
    }).encode(),
    (GDTEntry{ // User Mode Code Segment
        .base = 0,
        .limit = 0xFFFFF,
        .access = .{ .read_write = true, .executable = true, .descriptor = true, .privilege = 3, .present = true },
        .flags = .{ .granularity = true, .size = true },
    }).encode(),
    (GDTEntry{ // User Mode Data Segment
        .base = 0,
        .limit = 0xFFFFF,
        .access = .{ .read_write = true, .descriptor = true, .privilege = 3, .present = true },
        .flags = .{ .granularity = true, .size = true },
    }).encode(),
};

pub fn init() void {
    tty.print("Setup global descriptor table...\t", .{});
    defer tty.print("OK\n", .{});

    x86.loadGDT(.{
        .limit = @as(u16, @sizeOf(@TypeOf(GDT)) - 1),
        .base = &GDT[0],
    });
}
