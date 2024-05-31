const std = @import("std");
const x86 = @import("x86.zig");

var vga: VGA = .{};

pub fn init() void {
    disableCursor();
    vga.clear();
}

pub fn clear() void {
    vga.clear();
}

pub fn enableCursor() void {
    x86.out(0x3D4, @as(u8, 0x0A));
    x86.out(0x3D5, @as(u8, 0x00));
}

pub fn disableCursor() void {
    x86.out(0x3D4, @as(u8, 0x0A));
    x86.out(0x3D5, @as(u8, 1 << 5));
}

pub fn setBG(color: VGAColor) void {
    vga.background = color;
}

pub fn setFG(color: VGAColor) void {
    vga.foreground = color;
}

pub fn getBG() VGAColor {
    return vga.background;
}

pub fn getFG() VGAColor {
    return vga.foreground;
}

pub fn print(comptime format: []const u8, args: anytype) void {
    std.fmt.format(vga.writer(), format, args) catch unreachable; // panic for tty should be imposible
}

pub fn put(char: u8) void {
    vga.put(char);
}

pub fn rmv() void {
    if (vga.row == 0 and vga.line == 0)
        return;

    if (vga.row == 0) {
        vga.row = VGA_WIDTH - 1;
        vga.line -= 1;
        put(' ');
        vga.row = VGA_WIDTH - 1;
        vga.line -= 1;
        return;
    }

    vga.row -= 1;
    put(' ');
    vga.row -= 1;
}

pub fn panic(comptime format: []const u8, args: anytype) noreturn {
    setFG(.Red);
    setBG(.White);
    print("PANIC: " ++ format, args);
    x86.hang();
}

// VRAM buffer address in physical memory.
pub const VRAM_ADDR = 0xB8000;
pub const VRAM_SIZE = 0x8000;
// Screen size.
pub const VGA_WIDTH = 80;
pub const VGA_HEIGHT = 25;
pub const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;

pub const VGAColor = enum(u4) {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGrey = 7,
    DarkGrey = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    Yellow = 14,
    White = 15,
};

pub const VGAEntry = packed struct(u16) {
    char: u8,
    foreground: VGAColor,
    background: VGAColor,
};

const Errors = error{rip};

pub const VGA = struct {
    width: usize = VGA_WIDTH,
    height: usize = VGA_HEIGHT,
    row: usize = 0,
    line: usize = 0,
    foreground: VGAColor = .White,
    background: VGAColor = .Black,
    vram: []VGAEntry = @as([*]VGAEntry, @ptrFromInt(VRAM_ADDR))[0..(VRAM_SIZE / @sizeOf(VGAEntry))],

    const Writer = std.io.Writer(*@This(), error{}, printText);

    pub fn clear(this: *@This()) void {
        this.row = 0;
        this.line = 0;

        for (0..this.height) |y| {
            for (0..this.width) |x|
                this.vram[y * this.width + x] = .{
                    .char = ' ',
                    .foreground = this.foreground,
                    .background = this.background,
                };
        }
    }

    pub fn writer(this: *@This()) Writer {
        return .{ .context = this };
    }

    fn putChar(this: *@This(), char: u8) void {
        const i = this.line * this.width + this.row;
        this.vram[i] = .{
            .char = char,
            .foreground = this.foreground,
            .background = this.background,
        };
        this.row += 1;
        if (this.row < this.width)
            return;

        this.newline();
    }

    pub fn put(this: *@This(), ascii: u8) void {
        switch (ascii) {
            '\n' => {
                this.newline();
            },
            '\t' => {
                this.put(' ');
                while (this.row % 4 != 0)
                    this.put(' ');
            },
            else => this.putChar(ascii),
        }
    }

    fn newline(this: *@This()) void {
        this.row = 0;
        this.line += 1;

        if (this.line < VGA_HEIGHT)
            return;

        this.line -= 1;

        std.mem.copyForwards(VGAEntry, this.vram[0..], this.vram[VGA_WIDTH..]);
    }

    pub fn printText(this: *@This(), text: []const u8) !usize {
        for (text) |char| {
            this.put(char);
        }
        return text.len;
    }
};
