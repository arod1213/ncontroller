const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

const KeyCommand = struct { u8, ?u64 }; // key + flag
pub const KeyBindings = struct {
    vol_up: KeyCommand,
    vol_down: KeyCommand,
    mute: KeyCommand,
};

pub const Mode = enum { config, run };
pub fn chooseMode(alloc: Allocator) !Mode {
    const args = try std.process.argsAlloc(alloc);
    if (args.len < 2) {
        return .run;
    }
    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "config")) {
        return .config;
    } else {
        return .run;
    }
}

// expand to support control + command + option + shift
pub fn setup(alloc: Allocator, reader: *std.Io.Reader, writer: *std.Io.Writer) !*KeyBindings {
    const ptr = try alloc.create(KeyBindings);

    try writer.print("Please choose vol up key command: \n", .{});
    const vol_up = try reader.takeByte();

    try writer.print("Please choose vol down key command: \n", .{});
    const vol_down = try reader.takeByte();

    try writer.print("Please choose mute key command: \n", .{});
    const mute = try reader.takeByte();

    ptr.mute = mute;
    ptr.vol_up = vol_up;
    ptr.vol_down = vol_down;
    return ptr;
}
