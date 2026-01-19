const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cli = b.addModule("cli", .{
        .root_source_file = b.path("src/cli.zig"),
        .target = target,
    });

    const config = b.addModule("config", .{
        .root_source_file = b.path("src/config/main.zig"),
        .target = target,
    });

    const midi = b.addModule("midi", .{
        .root_source_file = b.path("src/midi/main.zig"),
        .target = target,
    });
    midi.linkFramework("CoreMidi", .{ .needed = true });
    midi.linkFramework("CoreFoundation", .{ .needed = true });

    const keys = b.addModule("keys", .{
        .root_source_file = b.path("src/keys/main.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "config", .module = config },
        },
    });
    keys.linkFramework("CoreGraphics", .{ .needed = true });

    const mod = b.addModule("ncontroller", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "keys", .module = keys },
            .{ .name = "midi", .module = midi },
        },
    });

    const exe = b.addExecutable(.{
        .name = "ncontroller",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ncontroller", .module = mod },
                .{ .name = "cli", .module = cli },
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
