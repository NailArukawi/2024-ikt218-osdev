const std = @import("std");
const tty = @import("tty.zig");
const x86 = @import("x86.zig");
const isr = @import("isr.zig");
const pmm = @import("pmm.zig");

// VMM manages pages and paging.
// uses pmm for backing page memory
// but does not have a function to allocate and page at once.

pub fn createPD() ![1024]PageDirectoryEntry {
    const block = try pmm.allocBlock();
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

    pub fn get(this: *@This()) [*]PageTableEntry {
        const full_addr = @shlExact(@as(usize, @intCast(this.address)), 12);
        return @ptrFromInt(full_addr);
    }

    pub fn setAddress(this: *@This(), address: usize) void {
        this.address = @truncate(std.math.shr(usize, address, 12));
    }
};

pub fn createPT() ![*]PageTableEntry {
    const block = try pmm.allocBlock();

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
        const full_addr = @shlExact(@as(usize, @intCast(this.address)), 12);
        return full_addr;
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
pub export var page_directory: [1024]PageDirectoryEntry align(4096) linksection(".bss") = undefined;

pub fn init() !void {
    tty.print("Setup vmm...\t", .{});
    defer tty.print("OK\n", .{});
    var address: usize = 0;

    for (0..1024) |i| {
        page_directory[i].setAddress(0); // = @bitCast(@as(usize, 0) | 2); // attribute set to: supervisor level, read/write, not present(010 in binary)
        page_directory[i].read_write = true;
    }

    for (0..4) |t| {
        var page_table = try createPT();

        for (0..1024) |i| {
            page_table[i].present = true; //@bitCast(address | 3);
            page_table[i].read_write = true;
            page_table[i].setAddress(address);
            address = address + 4096;
        }

        // fill the first entry of the page directory
        page_directory[t].setAddress(@intFromPtr(&page_table[0])); // attribute set to: supervisor level, read/write, present(011 in binary)
        page_directory[t].present = true;
        page_directory[t].read_write = true;
    }

    isr.interrupt_handlers[14] = handlerPageFault;

    switchPageDirectory(@intFromPtr(&page_directory[0]));
}

// maps and physical address to viritual.
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

pub fn switchPageDirectory(directory: usize) void {
    x86.outCr3(directory); // put that page directory address into CR3
    x86.outCr0(x86.inCr0() | 0x80000000); // set the paging.
}

fn handlerPageFault(registers: isr.Registers) void {
    const cr2 = x86.inCr2();
    tty.print("Page fault! [ ", .{});
    if ((registers.error_code & 0x1) == 0) tty.print("present ", .{});
    if ((registers.error_code & 0x2) > 0) tty.print("read-only ", .{});
    if ((registers.error_code & 0x4) > 0) tty.print("user-mode ", .{});
    if ((registers.error_code & 0x8) > 0) tty.print("reserved ", .{});
    tty.print("] at 0x{x}\n", .{cr2});
    @panic("Page fault");
}
