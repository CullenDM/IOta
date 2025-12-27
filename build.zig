const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = .{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
    };

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "kernel",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = b.resolveTargetQuery(target),
        .optimize = optimize,
        .linkage = .static,
    });

    exe.entry = .{ .symbol_name = "_start" };
    exe.setLinkerScript(.{ .path = "linker.ld" });
    exe.addAssemblyFile(.{ .path = "src/entry.S" });
    exe.strip = false;

    b.installArtifact(exe);

    const run_step = b.step("qemu", "Run the kernel in QEMU with OpenSBI");
    const qemu_cmd = b.addSystemCommand(&[_][]const u8{
        "qemu-system-riscv64",
        "-machine",
        "virt",
        "-cpu",
        "rv64,v=true",
        "-m",
        "256M",
        "-nographic",
        "-bios",
        "default",
        "-kernel",
        b.getInstallPath(.bin, "kernel"),
    });
    qemu_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&qemu_cmd.step);
}
