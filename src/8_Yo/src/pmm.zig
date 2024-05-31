const std = @import("std");
const x86 = @import("x86.zig");
const isr = @import("isr.zig");
const tty = @import("tty.zig");

pub extern const _kernel_end: u8; //                         value at the end of the kernel, for the poition of the end it is @intFromPtr(&_kernel_end).
pub extern const _kernel_start: u8; //                         value at the start of the kernel, for the poition of the start it is @intFromPtr(&_kernel_start)..
pub const BLOCK_SIZE: usize = 4096; //                          size of a chunck of physical memory, same size as a page here.
pub const MEMORY_MAX: usize = std.math.maxInt(usize) / 16; //   end of memory, Hardcoded to 4GiB until finding our platforms memory size is implimented.

// PhysicalMemoryManager
// Responsible to mapping physical memory to blocks that are BLOCK_SIZE aligned
pub var mem: MemoryStack = undefined;

pub fn init() void {
    tty.print("Setup pmm...\t", .{});
    defer tty.print("OK\n", .{});
    const kernel_end = @intFromPtr(&_kernel_end);
    const mem_size: usize = (MEMORY_MAX - kernel_end) / BLOCK_SIZE;

    mem = MemoryStack.createAt(kernel_end, mem_size);
}

pub const BlockPtr = *align(4096) anyopaque;

// returns a list of blocks to fit your requested size in high memory.
pub fn alloc(size: usize) ![]BlockPtr {
    return mem.alloc(size);
}

// returns a block in high memory.
pub fn allocBlock() !BlockPtr {
    return mem.allocBlock();
}

// frees in high memory.
pub fn free(block: usize) void {
    mem.dealloc(block);
}

pub const MemoryError = error{
    OutOfFreeMemory,
};

// The memory stack is really just a block of meomory starting from base, and is size long
// the first part of the block is a stack containing free memory that can be popped of to be allocated.
// to free the memory you just push it onto the free stack to be popped of later.
pub const MemoryStack = struct {
    free: []BlockPtr,
    free_top: usize,

    pub fn createAt(base: usize, size: usize) @This() {
        const result = @This(){
            .free = @as([*]BlockPtr, @ptrFromInt(base))[0..size],
            .free_top = std.math.divCeil(usize, size * @sizeOf(usize), BLOCK_SIZE) catch unreachable,
        };

        for (result.free, 0..) |*address, i| // write all high addresses as unused
            address.* = @ptrFromInt(base + (i * BLOCK_SIZE));

        return result;
    }

    // gives you enough blocks to hold your requested size, can be non-contigous.
    pub fn alloc(this: *@This(), size: usize) ![]BlockPtr {
        if (((this.free.len - this.free_top) * BLOCK_SIZE) < size)
            return MemoryError.OutOfFreeMemory;

        const blocks_needed = try std.math.divCeil(usize, size, BLOCK_SIZE);
        const old_free_top = this.free_top;
        this.free_top += blocks_needed;

        return this.free[old_free_top..this.free_top];
    }

    // gives you one block of memory.
    pub fn allocBlock(this: *@This()) !BlockPtr {
        if ((this.free.len - this.free_top) == 0)
            return MemoryError.OutOfFreeMemory;

        this.free_top += 1;
        return this.free[this.free_top - 1];
    }

    // double free will corrupt and possibly overflow the stack.
    pub fn dealloc(this: *@This(), block: usize) void {
        this.free_top -= 1;
        this.free[this.free_top] = block;
    }
};
