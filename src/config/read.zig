const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const binds = @import("./binds.zig");
const KeyCommand = binds.KeyCommand;
const Key = binds.Key;
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

pub fn readConfig(alloc: Allocator) !Config {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile("./config.txt", .{});
    defer file.close();

    var buffer: [256]u8 = undefined;
    const bytes = try file.readAll(&buffer);
    const data = buffer[0..bytes];

    var config = Config.default();

    // TODO: be careful of buffer overflow (some settings may not get set)
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
        } else if (std.mem.startsWith(u8, item, "VOL_DEFAULT:")) {
            const key, const flag = try getInfo(item[13..]);
            config.default_vol.key = .{ .val = key, .flags = flag, .down = true };
            config.default_vol.retrigger = false;
            std.log.info("SET {d} and {d}\n", .{ key, flag orelse 256 });
        } else if (std.mem.startsWith(u8, item, "CHANNELS:")) {
            var iterator = std.mem.splitAny(u8, item[11..], " ");
            var list = try std.ArrayList(u4).initCapacity(alloc, 2);
            defer list.deinit();

            while (iterator.next()) |val| {
                const num = try std.fmt.parseInt(u4, val, 10);
                try list.append(alloc, num);
            }
            config.channels = try list.toOwnedSlice(alloc);
            std.log.info("SET channels {d} \n", .{config.channels});
        }
    }
    return config;
}
