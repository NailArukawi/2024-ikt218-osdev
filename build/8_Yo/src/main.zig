const std = @import("std");

const MAGIC: i32 = 0x1BADB002;
const FLAGS: i32 = (1 << 0) | (1 << 1);

const MultibootHeader = extern struct { magic: i32 = 0x1BADB002, flags: i32 = FLAGS, checksum: i32 = -(MAGIC + FLAGS) };

export var multiboot align(4) linksection(".multiboot") = MultibootHeader{};

export fn kernelMain() noreturn {
    while (true) {}
}
