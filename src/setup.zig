const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const keys = @import("keys");
const config = keys.config;
const KeyQueue = keys.KeyQueue;

fn getConfig(alloc: Allocator) !config.Config {
    var queue = KeyQueue.init(alloc, null);
    _ = try std.Thread.spawn(.{}, keys.handleKeys, .{&queue});

    var settings = config.Config.default();

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        switch (i) {
            0 => print("\r\x1b[2Kplease choose a key for vol up:", .{}),
            1 => print("\r\x1b[2Kplease choose a key for vol down:", .{}),
            2 => print("\r\x1b[2Kplease choose a key for vol mute:\n", .{}),
            else => {},
        }
        blk: while (true) {
            if (queue.take()) |press| {
                switch (i) {
                    0 => settings.vol_up.key = press.key,
                    1 => settings.vol_down.key = press.key,
                    2 => settings.mute.key = press.key,
                    else => break :blk,
                }
                break;
            }
            std.Thread.sleep(std.time.ns_per_ms * 10);
        }
    }
    return settings;
}

pub fn run(alloc: Allocator) !void {
    const c = try getConfig(alloc);
    print("key binds set\n", .{});
    const cwd = std.fs.cwd();
    var file = try cwd.createFile("./config.txt", .{});
    var buff: [64]u8 = undefined;
    var writer = file.writer(&buff);

    try c.writeOut(&writer.interface);
}
