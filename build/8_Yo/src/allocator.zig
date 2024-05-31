const std = @import("std");
const pmm = @import("pmm.zig");
const vmm = @import("vmm.zig");
const tty = @import("tty.zig");
// immix inspired compiler
// but not an immix allocator

const BlockInfo = packed struct(u32) {
    start: u8,
    end: u8,
    full: bool,
    unused: u15, // bits with no use
};

const BlockMeta = extern struct {
    marked: std.bit_set.IntegerBitSet(128), // is actually only 127 lines as head takes one
    info: BlockInfo,

    pub fn init(this: *@This()) void {
        this.info.start = 1;
        this.info.end = 128;
    }

    pub fn tryFindRoom(this: *@This()) bool {
        var candidate: u8 = 0;
        var candidate_length: u8 = 0;

        var current: u8 = 0;
        var current_length: u8 = 0;
        for (1..128) |i| {
            if (current == 0 or !this.marked.isSet(i)) { // we found a new hole start
                current = @intCast(i);
                current_length = 0;
                continue;
            } else if (current != 0 and this.marked.isSet(i)) { // we found the end of a hole
                if (current_length < candidate_length) { // if hole bigger, it is our new candidate.
                    candidate = current;
                    candidate_length = current_length;
                    current = 0;
                    current_length = 0;
                }
            } else current_length += 1;
        }

        if (candidate == 0) // we found no hole.
            return false;

        this.info.start = candidate;
        this.info.end = candidate + candidate_length;
        return true;
    }

    pub fn alloc(this: *@This(), lines: u8) u8 {
        if (this.info.start + lines == this.info.end) // todo check if correct
            return 0; // none found

        const mark_start = this.info.start;
        const mark_end = this.info.start + lines;
        const range = std.bit_set.Range{ .start = mark_start, .end = mark_end };
        this.marked.setRangeValue(range, true);

        const result = this.info.start;
        this.info.start += lines;
        return result;
    }

    pub fn free(this: *@This(), lines: u8) u8 {
        if (this.info.start - 1 == 0) // todo check if correct
            return 0; // todo error none found

        const mark_start = this.info.start;
        const mark_end = this.info.start + lines;
        const range = std.bit_set.Range{ .start = mark_start, .end = mark_end };
        this.marked.setRangeValue(range, true);
        return 1;
    }
};

// Block contains 128 lines filling 4096B making each line is 32 bytes.
// first line is used for meta.
pub const Block = extern struct {
    meta: BlockMeta,
    body: [127][32]u8,

    pub fn init(this: *@This()) void {
        var block_mem = @as([*]u32, @ptrCast(this))[0..1024];
        for (0..1024) |i|
            block_mem[i] = 0;

        this.meta.init();
    }

    pub fn isFull(this: *@This()) bool {
        return this.meta.info.full;
    }

    pub fn tryFindRoom(this: *@This()) bool {
        this.meta.tryFindRoom();
    }

    pub fn alloc(this: *@This(), len: usize) ?[*]u8 {
        const lines: u8 = @intCast(len / 32);
        var room = this.meta.alloc(lines);
        if (room == 0) {
            if (!this.meta.tryFindRoom()) {
                return null;
            } else room = this.meta.alloc(lines);
        }
        if (room == 0)
            return null;

        return @ptrCast(&this.body[room]);
    }

    pub fn free(this: *@This(), len: usize) void {
        const lines: u8 = @intCast(len / 32);
        _ = this.meta.free(lines);
    }
};

// ZIG HAS A ALLOCATOR INTERFACE
// TODO WRAP THIS IN THAT INTERFACE!
// TODO NO BLOCK REUSE
// TODO MAPPING SHOULD HAPPEN IN HERE
pub const KernelAllocator = struct { // todo support larger than 127 line allocations
    current_block: ?*Block = null,
    blocks: [1023]?*Block = .{null} ** 1023, // hardcoded max is bad, todo make dynamic

    pub fn allocBlock(this: *@This()) !void {
        const block_mem = try pmm.allocBlock();
        var block: *Block = @ptrCast(block_mem);
        block.init();
        for (0..1023) |i| {
            if (this.blocks[i] == null) {
                this.current_block = block;

                this.blocks[i] = block;
                break;
            }
        }
    }

    // pub fn alloc(_: *anyopaque, len: usize, _: u8, _: usize) ?[*]u8;
    pub fn alloc(this: *@This(), len: usize) ?[*]u8 {
        if (this.current_block == null)
            this.allocBlock() catch return null;

        var result = this.current_block.?.alloc(len);
        if (result == null) {
            this.allocBlock() catch return null;

            result = this.current_block.?.alloc(len);
            if (result == null)
                return null;
        }

        return result;
    }

    pub fn create(this: *@This(), t: type) ?*t {
        if (this.current_block == null)
            this.allocBlock() catch return null;

        var result = this.current_block.?.alloc(@sizeOf(t));
        if (result == null) {
            this.allocBlock() catch return null;

            result = this.current_block.?.alloc(@sizeOf(t));
            if (result == null)
                return null;
        }

        return @ptrCast(@alignCast(result.?));
    }

    pub fn free(this: *@This(), ptr: anytype, len: usize) void {
        _ = this;
        const block_base: usize = @intFromPtr(ptr) - (@intFromPtr(ptr) % 4096);
        var block: *Block = @ptrFromInt(block_base);

        tty.print("free: (0x{x})(0x{x})\n", .{ @intFromPtr(ptr), block_base });
        block.free(len);
    }
};
