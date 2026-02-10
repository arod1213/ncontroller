const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

pub fn defaultState(alloc: Allocator) !State {
    const channels = try readChannels(alloc);
    return State{
        .channels = channels,
    };
}

pub const Message = enum {
    vol_up,
    vol_down,
    mute,
};

pub const State = struct {
    mu: std.Thread.Mutex = std.Thread.Mutex{},
    vol: u7 = 64,

    channels: []const u8,

    const Self = @This();
    pub fn handleMessage(self: *Self, msg: Message) void {
        self.mu.lock();
        defer self.mu.unlock();

        switch (msg) {
            .vol_up => self.vol +|= 1,
            .vol_down => self.vol -|= 1,
            .mute => {},
        }
    }
};

fn installPath(alloc: Allocator) ![]const u8 {
    const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
    return try std.fmt.allocPrint(alloc, "{s}/documents/ncontroller", .{home});
}

fn readChannels(alloc: Allocator) ![]const u8 {
    const install_path = try installPath(alloc);
    const config_path = try std.fs.path.join(alloc, &[_][]const u8{ install_path, "config.txt" });
    var file = try std.fs.openFileAbsolute(config_path, .{ .mode = .read_only });

    var channels = try std.ArrayList(u8).initCapacity(alloc, 2);
    defer channels.deinit(alloc);

    var buffer: [4096]u8 = undefined;
    const bytes = try file.readAll(&buffer);
    std.mem.replaceScalar(u8, buffer[0..bytes], '\n', ' ');

    var values = std.mem.splitAny(u8, buffer[0..bytes], " ");
    while (values.next()) |val| {
        const digit = std.fmt.parseInt(u8, val, 10) catch continue;
        try channels.append(alloc, digit);
    }

    if (channels.items.len == 0) {
        return &[_]u8{ 0, 1 };
    }

    return try channels.toOwnedSlice(alloc);
}
