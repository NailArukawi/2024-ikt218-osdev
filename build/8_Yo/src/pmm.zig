const std = @import("std");
const x86 = @import("x86.zig");
const isr = @import("isr.zig");
const tty = @import("tty.zig");

pub extern const _kernel_end: usize; //                           value at the end of the kernel, for the poition of the end it is @intFromPtr(&end).
pub const BLOCK_SIZE: usize = 4096; //                    size of a chunck of physical memory, same size as a page here.
pub const MEMORY_MAX: usize = std.math.maxInt(usize) / 16; //  end of memory, Hardcoded to 4GiB until finding our platforms memory size is implimented.

// OUR MEMORY IS:
// (0 MiB    -> 4 MiB)               is kernel.
// (4 MiB - > end of memory)       is high memory.

// PhysicalMemoryManager
var mem: MemoryStack = undefined;

pub fn init() void {
    const mem_size: usize = (MEMORY_MAX - _kernel_end) / BLOCK_SIZE;
    tty.print("k: 0x{x} m: 0x{x}\n", .{
        _kernel_end,
        mem_size,
    });

    mem = MemoryStack.createAt(_kernel_end, mem_size);
    tty.print("({}) mem[0]: {}, mem[1]: {}, mem[2]: {}, mem[3]: {}\n", .{ mem.free.len, mem.free[0], mem.free[1], mem.free[2], mem.free[3] });
}

pub const BlockPtr = *align(4086) anyopaque;

// returns a list of blocks to fit your requested size in high memory.
pub fn alloc(size: usize) ![]usize {
    return mem.alloc(size);
}

// returns a block in high memory.
pub fn allocBlock() !usize {
    return mem.allocPage();
}

// frees in high memory.
pub fn free(block: usize) void {
    mem.dealloc(block);
}

pub const MemoryError = error{
    OutOfFreeMemory,
};

pub const MemoryStack = struct {
    free: []usize,
    free_top: usize,

    pub fn createAt(base: usize, size: usize) @This() {
        const result = @This(){
            .free = @as([*]usize, @ptrFromInt(base))[0..size],
            .free_top = std.math.divCeil(usize, size * @sizeOf(usize), BLOCK_SIZE) catch unreachable,
        };

        for (result.free, 0..) |*address, i| // write all high addresses as unused
            address.* = base + (i * BLOCK_SIZE);

        return result;
    }

    pub inline fn sizeOf(size: usize) usize {
        return size * @sizeOf(usize);
    }

    pub fn alloc(this: *@This(), size: usize) ![]usize {
        if (((this.free.len - this.free_top) * BLOCK_SIZE) < size)
            return MemoryError.OutOfFreeMemory;

        const blocks_needed = try std.math.divCeil(usize, size, BLOCK_SIZE);
        const old_free_top = this.free_top;
        this.free_top += blocks_needed;

        return this.free[old_free_top..this.free_top];
    }

    pub fn allocPage(this: *@This()) !usize {
        if ((this.free.len - this.free_top) == 0)
            return MemoryError.OutOfFreeMemory;

        this.free_top += 1;
        return this.free[this.free_top - 1];
    }

    // double free will corrupt and possibly overflow the stack.
    pub fn dealloc(this: *@This(), block: usize) void {
        //std.debug.assert((block % 4096) == 0);

        this.free_top -= 1;
        this.free[this.free_top] = block;
    }
};
