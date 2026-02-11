const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zmidi_dep = b.dependency("zmidi", .{
        .target = target,
        .optimize = optimize,
    });
    const zmidi = zmidi_dep.module("zmidi");

    const keys_dep = b.dependency("zigkeys", .{
        .target = target,
        .optimize = optimize,
    });
    const keys = keys_dep.module("zigkeys");

    const mod = b.addModule("ncontroller", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "zigkeys", .module = keys },
            .{ .name = "zmidi", .module = zmidi },
        },
    });

    const menuczar_dep = b.dependency("menuczar", .{
        .target = target,
        .optimize = optimize,
    });
    const menuczar = menuczar_dep.module("menuczar");

    const exe = b.addExecutable(.{
        .name = "ncontroller",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "menuczar", .module = menuczar },
                .{ .name = "ncontroller", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
