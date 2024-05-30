const std = @import("std");
const tty = @import("tty.zig");
const x86 = @import("x86.zig");
const pmm = @import("pmm.zig");

var page_directory: [*]PageDirectoryEntry = undefined;

pub fn init() !void {
    const page_directory_raw = try pmm.allocBlock();
    tty.print("aligned?: 0x{X}", .{page_directory_raw});
    const cum = @as([*]u32, @ptrFromInt(page_directory_raw));
    cum[0] = 0;

    tty.print("rule: 0x{x}\n", .{page_directory_raw});
    page_directory = @as([*]PageDirectoryEntry, @ptrFromInt(page_directory_raw));

    // identity map first 4MiB
    var frame: usize = 0;
    for (0..128) |t| {
        const ree = try pmm.allocBlock();
        const table = @as([*]PageTableEntry, @ptrFromInt(ree));

        for (0..1024) |i| {
            var page: PageTableEntry = .{};
            page.present = true;
            page.user_super = true;
            page.address = @truncate(frame >> 12);

            table[i] = page;
            if (i == 5) {
                tty.print("page: {any}\n", .{page.address});
            }
            frame += 4096;
        }
        const entry = &page_directory[t];
        entry.present = true;
        entry.read_write = true;
        entry.address = @truncate(@intFromPtr(table));
        //tty.print("entry: {any}\n", .{entry});
    }

    //switchPageDirectory(@intFromPtr(page_directory));
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

pub fn lookupPageTableEntry(table: [*]PageTableEntry, viritual_address: usize) *PageTableEntry {
    const index = std.math.shr(usize, viritual_address, 12) & 0x3ff;
    return &table[index];
}

pub fn lookupPageDirectoryEntry(directory: [*]PageDirectoryEntry, viritual_address: usize) *PageDirectoryEntry {
    const index = std.math.shr(usize, viritual_address, 22) & 0x3ff; // maybe error!
    return &directory[index];
}

pub fn getPageDirectoryTable(directory: [*]PageDirectoryEntry, viritual_address: usize) [*]PageTableEntry {
    const entry = lookupPageDirectoryEntry(directory, viritual_address);
    const table = @as([*]PageTableEntry, @ptrFromInt(@as(usize, @intCast(entry.address))));
    return table;
}

pub fn mapPage(physical: usize, viritual: usize) !void {
    const directory_entry = lookupPageDirectoryEntry(page_directory, viritual);
    if (!directory_entry.present) {
        // allocate for page table
        const block = try pmm.allocBlock();

        // clear it
        @memset(@as([*]u32, @ptrFromInt(block))[0..1024], 0);

        const table = @as([*]PageTableEntry, @ptrFromInt(block));

        // create new entry
        const entry = lookupPageDirectoryEntry(page_directory, viritual);

        // set new table
        entry.*.present = true;
        entry.*.read_write = true; // makes it not readonly
        entry.*.address = @truncate(@intFromPtr(&table)); // dunno=ø
    }

    // get table
    const table = getPageDirectoryTable(page_directory, viritual);
    // get page
    const page = lookupPageTableEntry(table, viritual);

    page.*.address = @truncate(physical);
    page.*.present = true;
}

fn switchPageDirectory(directory: usize) void {
    asm volatile ("mov %[physical_tables], %%cr3"
        :
        : [physical_tables] "r" (directory),
    );
    var cr0: u32 = 0;
    asm volatile ("mov %%cr0, %[cr0]"
        : [cr0] "=r" (cr0),
    );
    cr0 |= 0x80000000; // Enable paging!
    asm volatile ("mov %[input], %%cr0"
        :
        : [input] "r" (cr0),
    );
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
