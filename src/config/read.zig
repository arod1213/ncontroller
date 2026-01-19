const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const binds = @import("./binds.zig");
const KeyCommand = binds.KeyCommand;
const Config = binds.Config;

fn getInfo(line: []const u8) !struct { u8, ?u64 } {
    var digits = std.mem.splitAny(u8, line, " ");

    const key = try std.fmt.parseInt(
        u8,
        digits.next() orelse @panic("invalid config"),
        10,
    );
    const flag = if (digits.next()) |d| try std.fmt.parseInt(u64, d, 10) else null;
    return .{ key, flag };
}

pub fn readConfig() !Config {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile("./config.txt", .{});
    defer file.close();

    var buffer: [64]u8 = undefined;
    const bytes = try file.readAll(&buffer);
    const data = buffer[0..bytes];

    var config = Config.default();

    var iter = std.mem.splitAny(u8, data, "\n");
    while (iter.next()) |item| {
        if (std.mem.startsWith(u8, item, "VOL_UP:")) {
            const key, const flag = try getInfo(item[8..]);

            config.vol_up.key = .{ .val = key, .flags = flag, .down = true };

            std.log.info("SET {d} and {d}\n", .{ key, flag orelse 256 });
        } else if (std.mem.startsWith(u8, item, "VOL_DOWN:")) {
            const key, const flag = try getInfo(item[10..]);

            config.vol_down.key = .{ .val = key, .flags = flag, .down = true };

            std.log.info("SET {d} and {d}\n", .{ key, flag orelse 256 });
        } else if (std.mem.startsWith(u8, item, "MUTE:")) {
            const key, const flag = try getInfo(item[6..]);

            config.mute.key = .{ .val = key, .flags = flag, .down = true };
            config.mute.retrigger = false;

            std.log.info("SET {d} and {d}\n", .{ key, flag orelse 256 });
        }
    }
    return config;
}
