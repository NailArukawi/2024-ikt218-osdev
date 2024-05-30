const std = @import("std");
const x86 = @import("x86.zig");
const isr = @import("isr.zig");
const tty = @import("tty.zig");

pub extern const _kernel_end: usize; //                           value at the end of the kernel, for the poition of the end it is @intFromPtr(&end).
pub const BLOCK_SIZE: usize = 4096; //                    size of a chunck of physical memory, same size as a page here.
pub const MEMORY_MAX: usize = std.math.maxInt(usize); //  end of memory, Hardcoded to 4GiB until finding our platforms memory size is implimented.

// OUR MEMORY IS:
// (0 MiB               -> 1 MiB)               is kernel.
// (1MiB              -> (1 MiB + PMM size)) is for storing what blocks are in use.
// ((1 MiB + PMM size) -> end of memory)       is high memory.

// PhysicalMemoryManager
var low: MemoryStack = undefined;
var high: MemoryStack = undefined;

pub fn init() void {
    const kernel_end: usize = @intFromPtr(&_kernel_end); // kernel end page aligned.
    const mem_size: usize = (MEMORY_MAX - kernel_end) / BLOCK_SIZE;
    tty.print("k: 0x{x}, m: 0x{x}\n", .{ kernel_end, mem_size });

    high = MemoryStack.createAt(kernel_end, mem_size);

    for (high.free, 0..) |*address, i| // write all high addresses as unused
        address.* = kernel_end + (i * BLOCK_SIZE);
}

// returns a list of blocks to fit your requested size in high memory.
pub fn alloc(size: usize) ![]usize {
    return high.alloc(size);
}

// returns a block in high memory.
pub fn allocBlock() !usize {
    return high.allocPage();
}

// frees in high memory.
pub fn free(block: usize) void {
    high.dealloc(block);
}

pub const MemoryError = error{
    OutOfFreeMemory,
};

pub const MemoryStack = struct {
    free: []usize,
    free_top: usize,

    pub fn createAt(start: usize, size: usize) @This() {
        return .{
            .free = @as([*]usize, @ptrFromInt(start))[0..size],
            .free_top = 0,
        };
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
