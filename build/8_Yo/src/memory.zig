const std = @import("std");
const x86 = @import("x86.zig");
const isr = @import("isr.zig");
const tty = @import("tty.zig");

pub extern const end: usize; //                           value at the end of the kernel, for the poition of the end it is @intFromPtr(&end).
pub const LOW_END: usize = std.math.pow(usize, 2, 24); // end of low memory, low memory is for compatibility.
pub const CHUNK_SIZE: usize = 4096; //                    size of a chunck of physical memory, same size as a page here.
pub const MEMORY_MAX: usize = std.math.maxInt(usize); //  end of memory, Hardcoded to 4GiB until finding our platforms memory size is implimented.

// OUR MEMORY IS:
// (0 MiB               -> 1 MiB)               is kernel.
// (1 MiB               -> 16 MiB)              is low memory.
// (16 MiB              -> (16 MiB + PMM size)) is for storing what chunks are in use.
// ((16 MiB + PMM size) -> end of memory)       is high memory.

// PhysicalMemoryManager
var low: MemoryStack = undefined;
var high: MemoryStack = undefined;

pub fn init() void {
    const kernel_end: usize = @intFromPtr(&end) + (LOW_END % 4096); // kernel end page aligned.
    const low_size: usize = (LOW_END - kernel_end) / CHUNK_SIZE;
    const high_size: usize = (MEMORY_MAX - (LOW_END + kernel_end)) / CHUNK_SIZE;
    tty.print("k: 0x{x}, l: 0x{x}, h: 0x{x}\n", .{ kernel_end, low_size, high_size });

    low = MemoryStack.createAt(kernel_end, low_size);
    high = MemoryStack.createAt(kernel_end + MemoryStack.sizeOf(low_size), high_size);

    var cursor: usize = kernel_end;
    for (low.free) |*address| { // write all low addresses as unused
        address.* = cursor;
        cursor = cursor + CHUNK_SIZE;
    }

    for (high.free) |*address| { // write all high addresses as unused
        address.* = cursor;
        cursor = cursor + CHUNK_SIZE;
    }
}

// returns a list of chunks to fit your requested size in high memory.
pub fn alloc(size: usize) ![]usize {
    return high.alloc(size);
}

// returns a chunk in high memory.
pub fn allocPage() !usize {
    return high.allocPage();
}

// returns a list of chunks to fit your requested size in low memory.
// only use when there is a compatibility reason for needing to be in 2^24 address space.
pub fn allocLow(size: usize) ![]usize {
    return low.alloc(size);
}

// returns a chunk in high memory.
pub fn allocLowPage() !usize {
    return low.allocPage();
}

// frees in high memory.
pub fn free(chunk: usize) void {
    high.dealloc(chunk);
}

// frees in low memory.
pub fn freeLow(chunk: usize) void {
    low.dealloc(chunk);
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
        if (((this.free.len - this.free_top) * CHUNK_SIZE) < size)
            return MemoryError.OutOfFreeMemory;

        const chunks_needed = try std.math.divCeil(usize, size, CHUNK_SIZE);
        const old_free_top = this.free_top;
        this.free_top += chunks_needed;

        return this.free[old_free_top..this.free_top];
    }

    pub fn allocPage(this: *@This()) !usize {
        tty.print("alloc left: {}", .{this.free.len});
        if ((this.free.len - this.free_top) == 0)
            return MemoryError.OutOfFreeMemory;

        this.free_top += 1;
        return this.free[this.free_top - 1];
    }

    // double free will corrupt and possibly overflow the stack.
    pub fn dealloc(this: *@This(), chunk: usize) void {
        //std.debug.assert((chunk % 4096) == 0);

        this.free_top -= 1;
        this.free[this.free_top] = chunk;
    }
};

var page_directory: [*]PageDirectoryEntry = undefined;
var page_tables: [1024][*]PageTableEntry = .{undefined} ** 1024;
pub fn initPaging() !void {
    const page_directory_raw = try allocLowPage();
    tty.print("rule: 0x{x}\n", .{page_directory_raw});
    page_directory = @as([*]PageDirectoryEntry, @ptrFromInt(page_directory_raw));

    const table_raw = try allocLowPage();
    page_tables[0] = @as([*]PageTableEntry, @ptrFromInt(table_raw));

    for (page_tables[0][0..1023], 0..) |*entry, j| {
        (entry.*).present = true;
        (entry.*).read_write = true;
        (entry.*).address = @intCast(j);
    }

    page_directory[0].present = true;
    page_directory[0].address = @intCast(table_raw / 4096);

    tty.print("scrr: 0x{x}\n", .{@intFromPtr(&page_directory[0])});
    isr.interrupt_handlers[14] = &handler;

    x86.outCr3(page_directory_raw); // put that page directory address into CR3
    //x86.outCr0(x86.inCr0() | 0x80000000); // set the paging.
}

pub const PageDirectoryEntry = packed struct(u32) {
    present: bool,
    read_write: bool,
    user_super: bool,
    write_through: bool,
    cache_disable: bool,
    accessed: bool,
    dirty: bool,
    page_size: bool,
    available: u4, // free for os to use
    address: u20,
};

pub const PageTableEntry = packed struct(u32) {
    present: bool,
    read_write: bool,
    user_super: bool,
    write_through: bool,
    cache_disable: bool,
    accessed: bool,
    dirty: bool,
    page_attribute_table: bool,
    global: bool,
    available: u3, // free for os to use
    address: u20,
};

pub fn handler(registers: isr.Registers) void {
    const cr2 = asm ("mov %%cr2, %[value]"
        : [value] "=r" (-> u32),
    );
    const present = (registers.error_code & 0x1) == 0;
    const read_write = (registers.error_code & 0x2) > 0;
    const user_mode = (registers.error_code & 0x4) > 0;
    const reserved = (registers.error_code & 0x8) > 0;
    tty.print("Page fault(0x{x}):", .{cr2});
    defer tty.print("\n", .{});
    if (present) tty.print(" present", .{});
    if (read_write) tty.print(" read-only", .{});
    if (user_mode) tty.print(" user-mode", .{});
    if (reserved) tty.print(" reserved", .{});

    @panic("Page fault");
}
