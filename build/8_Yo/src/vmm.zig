const std = @import("std");
const tty = @import("tty.zig");
const x86 = @import("x86.zig");
const isr = @import("isr.zig");
const pmm = @import("pmm.zig");

pub fn createPD() ![1024]PageDirectoryEntry {
    const block = try pmm.allocBlock();
    //tty.print("got block: {}\n", .{block});
    @memset(@as([*]u32, @ptrFromInt(block))[0..1024], 0);

    return @bitCast(block);
}

pub fn lookupPD(this: *[1024]PageDirectoryEntry, index: u10) *PageDirectoryEntry {
    return &this[index];
}

pub fn fullLookupPD(this: *[1024]PageDirectoryEntry, viritual: usize) usize {
    const page_address_virt: PageAddressVirt = @bitCast(viritual);
    const table = lookupPD(this, page_address_virt.table);
    const page = lookupPT(table.get(), page_address_virt.page);
    //tty.print("full: {}:{}:{}\n", .{ page_address_virt.table, page_address_virt.page, page_address_virt.index });
    return page.fullAddress(page_address_virt.index);
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

    pub fn get(this: @This()) [*]PageTableEntry {
        const full_addr = @as(usize, @intCast(this.address));
        return @ptrFromInt(full_addr);
    }

    pub fn setAddress(this: *@This(), address: usize) void {
        this.address = @truncate(std.math.shr(usize, address, 12));
    }
};

pub fn createPT() ![*]PageTableEntry {
    const block = try pmm.allocBlock();
    //tty.print("got block: 0x{X}\n", .{@intFromPtr(block)});

    const result: [*]PageTableEntry = @ptrCast(block);

    for (0..1024) |i| // set all to 0
        result[i] = @bitCast(@as(usize, 0));

    return result;
}

pub fn lookupPT(this: [*]PageTableEntry, index: u10) *PageTableEntry {
    return &this[index];
}

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

    pub fn setAddress(this: *@This(), address: usize) void {
        this.address = @truncate(std.math.shr(usize, address, 12));
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

// does not need to be linked but it is.
export var page_directory: [1024]PageDirectoryEntry align(4096) linksection(".bss") = undefined;

pub fn init() !void {
    tty.print("Setup vmm...\t", .{});
    defer tty.print("OK\n", .{});
    var address: usize = 0;
    var page_table = try createPT();

    for (0..1024) |i| {
        page_table[i].present = true; //@bitCast(address | 3);
        page_table[i].read_write = true;
        page_table[i].setAddress(address);
        address = address + 4096;
    }

    // fill the first entry of the page directory
    page_directory[0].setAddress(@intFromPtr(&page_table[0])); // attribute set to: supervisor level, read/write, present(011 in binary)
    page_directory[0].present = true;
    page_directory[0].read_write = true;

    for (1..1024) |i| {
        page_directory[i].setAddress(0); // = @bitCast(@as(usize, 0) | 2); // attribute set to: supervisor level, read/write, not present(010 in binary)
        page_directory[i].read_write = true;
    }

    isr.interrupt_handlers[14] = handler;

    switchPageDirectory(@intFromPtr(&page_directory[0]));
}

pub fn sinit() !void {
    for (0..1024) |i| {
        page_directory[i] = @bitCast(@as(usize, 0) | 2); // attribute set to: supervisor level, read/write, not present(010 in binary)
    }

    for (0..1024) |i| {
        try pageMap(i * 4096, i * 4096);
    }

    for (0..1024) |i| {
        if (i != fullLookupPD(&page_directory, i))
            testAddr(i);
    }

    //try pageMap(1023 * 4096, 1023 * 4096);

    isr.interrupt_handlers[14] = handler;
    switchPageDirectory(@intFromPtr(&page_directory[0]));
}

pub fn testAddr(addr: usize) void {
    tty.print("0x{x} == 0x{x}\n", .{ addr, fullLookupPD(&page_directory, addr) });
}

pub fn pageMap(physical: usize, viritual: usize) !void {
    const page_address_virt: PageAddressVirt = @bitCast(viritual);
    const page_address_phys: PageAddressPhys = @bitCast(physical);

    const e = lookupPD(&page_directory, page_address_virt.table);
    if (!e.present) {
        const table = try createPT();

        const entry = lookupPD(&page_directory, page_address_virt.table);
        entry.setAddress(@intFromPtr(table)); // dunno=ø
        entry.present = true;
        entry.read_write = true; // makes it not readonly
    }
    const table = e.get();
    const page = lookupPT(table, page_address_virt.page);

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
