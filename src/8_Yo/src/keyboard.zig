const std = @import("std");
const isr = @import("isr.zig");
const tty = @import("tty.zig");
const x86 = @import("x86.zig");

var shift: bool = false;
var algr: bool = false;

fn keyboardHandler(_: isr.Registers) void {
    const scancode = x86.in(u8, 0x60);
    switch (scancode) {
        0x02 => if (shift) tty.put('!') else tty.put('1'),
        0x03 => if (shift) tty.put('"') else if (algr) tty.put('@') else tty.put('2'),
        0x04 => if (shift) tty.put('#') else tty.put('3'),
        0x05 => if (shift) tty.put('¤') else tty.put('4'),
        0x06 => if (shift) tty.put('%') else tty.put('5'),
        0x07 => if (shift) tty.put('&') else tty.put('6'),
        0x08 => if (shift) tty.put('/') else tty.put('7'),
        0x09 => if (shift) tty.put('(') else tty.put('8'),
        0x0a => if (shift) tty.put(')') else tty.put('9'),
        0x0b => if (shift) tty.put('=') else tty.put('0'),

        0x1e => if (shift) tty.put('A') else tty.put('a'),
        0x30 => if (shift) tty.put('B') else tty.put('b'),
        0x2e => if (shift) tty.put('C') else tty.put('c'),
        0x20 => if (shift) tty.put('D') else tty.put('d'),
        0x12 => if (shift) tty.put('E') else tty.put('e'),
        0x21 => if (shift) tty.put('F') else tty.put('f'),
        0x22 => if (shift) tty.put('G') else tty.put('g'),
        0x23 => if (shift) tty.put('H') else tty.put('h'),
        0x17 => if (shift) tty.put('I') else tty.put('i'),
        0x24 => if (shift) tty.put('J') else tty.put('j'),
        0x25 => if (shift) tty.put('K') else tty.put('k'),
        0x26 => if (shift) tty.put('L') else tty.put('l'),
        0x32 => if (shift) tty.put('M') else tty.put('m'),
        0x31 => if (shift) tty.put('N') else tty.put('n'),
        0x18 => if (shift) tty.put('O') else tty.put('o'),
        0x19 => if (shift) tty.put('P') else tty.put('p'),
        0x10 => if (shift) tty.put('Q') else tty.put('q'),
        0x13 => if (shift) tty.put('R') else tty.put('r'),
        0x1f => if (shift) tty.put('S') else tty.put('s'),
        0x14 => if (shift) tty.put('T') else tty.put('t'),
        0x16 => if (shift) tty.put('U') else tty.put('u'),
        0x2f => if (shift) tty.put('V') else tty.put('v'),
        0x11 => if (shift) tty.put('W') else tty.put('w'),
        0x2d => if (shift) tty.put('X') else tty.put('x'),
        0x15 => if (shift) tty.put('Y') else tty.put('y'),
        0x2c => if (shift) tty.put('Z') else tty.put('z'),

        0x39 => tty.put(' '),
        0x1c => tty.put('\n'),
        0x0e => tty.rmv(),
        0x2a => shift = true,
        0xaa => shift = false,

        0xe0 => algr = !algr,

        else => {},
        //else => tty.print("pressed: {x} ", .{scancode}),
    }
}

pub fn init() void {
    isr.interrupt_handlers[isr.IRQ[1]] = keyboardHandler;
    x86.out(0xA1, @as(u8, 0xFF));
}
