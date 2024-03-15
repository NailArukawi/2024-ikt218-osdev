const std = @import("std");
const Target = std.Target;

// https://wiki.osdev.org/Zig_Bare_Bones

pub fn build(b: *std.Build) void {
    const target_query: std.Target.Query = .{
        .cpu_arch = Target.Cpu.Arch.x86,
        .cpu_model = .{ .explicit = &Target.x86.cpu.i686 },

        .os_tag = Target.Os.Tag.freestanding,
        .abi = .none,
    };
    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "yo.elf",
        .root_source_file = .{ .path = "src/entry.zig" },
        .target = b.resolveTargetQuery(target_query),
        .optimize = optimize,
    });
    kernel.setLinkerScript(.{ .cwd_relative = "./linker.ld" });

    b.installArtifact(kernel);
    const kernel_step = b.step("kernel", "Build the kernel");
    kernel_step.dependOn(&kernel.step);

    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-i386",
        "-kernel",
        "zig-out/bin/yo.elf",
        "-display",
        "gtk,zoom-to-fit=on",
        "-no-reboot",
        "-s",
    });
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the kernel");
    run_step.dependOn(&run_cmd.step);
}
