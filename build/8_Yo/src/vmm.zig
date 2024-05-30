const std = @import("std");
const tty = @import("tty.zig");
const x86 = @import("x86.zig");
const isr = @import("isr.zig");
const pmm = @import("pmm.zig");

pub const PageDirectory = extern struct {
    directory: *[1024]PageDirectoryEntry,

    pub fn create() !@This() {
        const block = try pmm.allocBlock();
        tty.print("got block: {}\n", .{block});
        @memset(@as([*]u32, @ptrFromInt(block))[0..1024], 0);

        return @bitCast(block);
    }

    pub fn lookup(this: @This(), index: u10) *PageDirectoryEntry {
        return &this.directory[index];
    }

    pub fn fullLookup(this: @This(), viritual: usize) usize {
        const page_address_virt: PageAddressVirt = @bitCast(viritual);
        const table = this.lookup(page_address_virt.table);
        const page = table.get().lookup(page_address_virt.page);
        //tty.print("full: {}:{}:{}\n", .{ page_address_virt.table, page_address_virt.page, page_address_virt.index });
        return page.fullAddress(page_address_virt.index);
    }
};

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

    pub fn get(this: @This()) PageTable {
        const full_addr = @as(usize, @intCast(this.address));
        return @bitCast(full_addr);
    }
};

pub const PageTable = extern struct {
    table: *[1024]PageTableEntry,

    pub fn create() !@This() {
        const block = try pmm.allocBlock();
        tty.print("got block: {}\n", .{block});

        const result: @This() = @bitCast(block);

        for (0..1024) |i| // set all to 0
            result.table[i] = PageTableEntry{};

        return result;
    }

    pub fn lookup(this: @This(), index: u10) *PageTableEntry {
        return &this.table[index];
    }
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

    pub fn fullAddress(this: @This(), index: u12) usize {
        return @bitCast(PageAddressPhys{ .page = this.address, .index = index });
    }

    pub fn get(this: @This()) usize {
        return @as(usize, @intCast(this.address));
    }
};

pub const PageAddressVirt = packed struct(u32) {
    index: u12,
    // what page or page table entry
    page: u10,
    // what table or page directory entry
    table: u10,
};

pub const PageAddressPhys = packed struct(u32) {
    index: u12,
    page: u20,
};

pub export var page_directory: PageDirectory = undefined;

export var pages_directory: [1024]usize align(4096) linksection(".bss") = undefined;
export var page_table: [1024]usize align(4096) linksection(".bss") = undefined;

pub fn init() void {
    var address: usize = 0;

    for (0..1024) |i| {
        page_table[i] = address | 3;
        address = address + 4096;
    }

    // fill the first entry of the page directory
    pages_directory[0] = @intFromPtr(&page_table[0]); // attribute set to: supervisor level, read/write, present(011 in binary)
    pages_directory[0] = pages_directory[0] | 3;

    for (1..1024) |i| {
        pages_directory[i] = 0 | 2; // attribute set to: supervisor level, read/write, not present(010 in binary)
    }

    isr.interrupt_handlers[14] = handler;

    x86.outCr3(@intFromPtr(&pages_directory[0])); // put that page directory address into CR3
    x86.outCr0(x86.inCr0() | 0x80000000); // set the paging.
}

pub fn sinit() !void {
    page_directory = try PageDirectory.create();

    for (0..2048) |i| {
        try pageMap(i * 4096, i * 4096);
    }

    for (0..2048) |i| {
        if (i != page_directory.fullLookup(i))
            testAddr(i);
    }

    page_directory.lookup(0).get().lookup(0).user_super = true;

    //try pageMap(1023 * 4096, 1023 * 4096);

    isr.interrupt_handlers[14] = handler;
    switchPageDirectory(@intFromPtr(&page_directory.directory.*[0]));
}

pub fn testAddr(addr: usize) void {
    tty.print("0x{x} == 0x{x}\n", .{ addr, page_directory.fullLookup(addr) });
}

pub fn pageMap(physical: usize, viritual: usize) !void {
    const page_address_virt: PageAddressVirt = @bitCast(viritual);
    const page_address_phys: PageAddressPhys = @bitCast(physical);

    const e = page_directory.lookup(page_address_virt.table);
    //tty.print("e: {any}\n", .{e});
    if (!e.present) {
        const table = try PageTable.create();
        //tty.print("t: {*}\n", .{table.table});

        const entry = page_directory.lookup(page_address_virt.table);
        entry.present = true;
        entry.read_write = true; // makes it not readonly
        entry.address = @truncate(@intFromPtr(table.table)); // dunno=ø
    }
    //tty.print("e: {any}\n", .{e});
    const table = e.get();
    const page = table.lookup(page_address_virt.page);

    page.address = page_address_phys.page;
    page.present = true;
    page.read_write = true;
}

fn switchPageDirectory(directory: usize) void {
    x86.outCr3(directory); // put that page directory address into CR3
    x86.outCr0(x86.inCr0() | 0x80000000); // set the paging.
}

pub fn handler(registers: isr.Registers) void {
    const cr2 = asm ("mov %%cr2, %[value]"
        : [value] "=r" (-> u32),
    );
    const present = (registers.error_code & 0x1) == 0;
    const read_write = (registers.error_code & 0x2) > 0;
    const user_mode = (registers.error_code & 0x4) > 0;
    const reserved = (registers.error_code & 0x8) > 0;
    tty.print("Page fault! [ ", .{});
    if (present) tty.print("present ", .{});
    if (read_write) tty.print("read-only ", .{});
    if (user_mode) tty.print("user-mode ", .{});
    if (reserved) tty.print("reserved ", .{});
    tty.print("] at 0x{x}\n", .{cr2});
    @panic("Page fault");
}
