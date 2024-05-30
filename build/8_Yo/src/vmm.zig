const std = @import("std");
const tty = @import("tty.zig");
const x86 = @import("x86.zig");
const pmm = @import("pmm.zig");

var page_directory: [*]PageDirectoryEntry = undefined;

pub fn init() !void {
    const page_directory_raw = try pmm.allocBlock();
    tty.print("rule: 0x{x}\n", .{page_directory_raw});
    page_directory = @as([*]PageDirectoryEntry, @ptrFromInt(page_directory_raw));

    const ree = try pmm.allocBlock();
    const table = @as([*]PageTableEntry, @ptrFromInt(ree));

    // identity map first 4MiB
    for (0..4) |i| {
        var page: PageTableEntry = .{};
        page.present = true;
        page.address = @truncate(i * pmm.BLOCK_SIZE);

        table[std.math.shr(usize, 0x100000 + i * 4096, 12) & 0x3ff] = page;
        tty.print("page: {}\n", .{page});
    }

    const entry = &page_directory[std.math.shr(usize, 0x00000000, 22) & 0x3ff];

    entry.present = true;
    entry.read_write = true;
    entry.address = @truncate(@intFromPtr(table));

    //switchPageDirectory(page_directory);
}

pub fn allocPage(page_table_entry: *PageTableEntry) !void {
    const block = try pmm.allocBlock();
    page_table_entry.address = @truncate(block);
    page_table_entry.present = true;
}

pub fn freePage(page: *PageTableEntry) void {
    pmm.free(@intCast(page.address));
    page.present = false;
}

pub fn lookupPageTableEntry(table: [1024]PageTableEntry, viritual_address: usize) *PageTableEntry {
    const index = std.math.shr(usize, viritual_address, 12) & 0x3ff;
    return &table[index];
}

pub fn lookupPageDirectoryEntry(directory: [1024]PageDirectoryEntry, viritual_address: usize) *PageDirectoryEntry {
    const index = std.math.shr(usize, viritual_address, 22) & 0x3ff; // maybe error!
    return &directory[index];
}

pub fn getPageDirectoryTable(directory: [1024]PageDirectoryEntry, viritual_address: usize) [1024]PageTableEntry {
    const entry = lookupPageDirectoryEntry(directory, viritual_address);
    const table = @as([1024]PageTableEntry, @ptrFromInt(@as(usize, @intCast(entry.address))));
    return table;
}

pub fn mapPage(physical: usize, viritual: usize) !void {
    const directory_entry = lookupPageDirectoryEntry(page_directory[0..1024], viritual);
    if (!directory_entry.present) {
        // allocate for page table
        const block = try pmm.allocBlock();

        // clear it
        @memset(@as([1024]u32, @ptrFromInt(block)), 0);

        const table = @as([1024]PageTableEntry, @ptrFromInt(block));

        // create new entry
        const entry = lookupPageDirectoryEntry(page_directory[0..1024], viritual);

        // set new table
        entry.*.present = true;
        entry.*.read_write = true; // makes it not readonly
        entry.*.address = @truncate(@intFromPtr(&table)); // dunno=ø
    }

    // get table
    const table = getPageDirectoryTable(page_directory[0..1024], viritual);
    // get page
    const page = lookupPageTableEntry(table, viritual);

    page.*.address = @truncate(physical);
    page.*.present = true;
}

pub fn switchPageDirectory(directory: [*]PageDirectoryEntry) void {
    x86.outCr3(@intFromPtr(directory)); // put that page directory address into CR3
    x86.outCr0(x86.inCr0() | 0x80000000); // set the paging.
}

pub const PageDirectoryEntry = packed struct(u32) {
    present: bool = false,
    read_write: bool = false,
    user_super: bool = false,
    write_through: bool = false,
    cache_disable: bool = false,
    accessed: bool = false,
    dirty: bool = false,
    page_size: bool = false,
    available: u4 = 0, // free for os to use
    address: u20 = 0,
};

pub const PageTableEntry = packed struct(u32) {
    present: bool = false,
    read_write: bool = false,
    user_super: bool = false,
    write_through: bool = false,
    cache_disable: bool = false,
    accessed: bool = false,
    dirty: bool = false,
    page_attribute_table: bool = false,
    global: bool = false,
    available: u3 = 0, // free for os to use
    address: u20 = 0,
};
