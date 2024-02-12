const std = @import("std");
const Target = std.Target;

// https://wiki.osdev.org/Zig_Bare_Bones

pub fn build(b: *std.Build) void {
    const target_query: std.Target.Query = .{
        .cpu_arch = Target.Cpu.Arch.x86,
        .cpu_model = .{ .explicit = &Target.x86.cpu.i386 },

        .os_tag = Target.Os.Tag.freestanding,
        .abi = .none,
        .ofmt = .elf,
    };
    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "yo.elf",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = b.resolveTargetQuery(target_query),
        .optimize = optimize,
    });

    b.installArtifact(kernel);
}
