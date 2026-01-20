const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

// TODO: use keys types here instead
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
