const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

pub const Mode = enum { config, testing, run };
pub fn chooseMode(alloc: Allocator) !Mode {
    const args = try std.process.argsAlloc(alloc);
    if (args.len < 2) {
        return .run;
    }
    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "config")) {
        return .config;
    } else if (std.mem.eql(u8, cmd, "testing")) {
        return .testing;
    } else {
        return .run;
    }
}
