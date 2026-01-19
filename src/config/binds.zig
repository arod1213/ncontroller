const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const Key = struct {
    val: u8,
    flags: ?u64,
    down: bool,

    const Self = @This();
    pub fn init(key: u8, flags: u64, down: bool) Self {
        return .{
            .key = key,
            .flags = if (flags == 256) null else flags,
            .down = down,
        };
    }

    pub fn eq(self: Self, other: Self) bool {
        return self.flags == other.flags and self.val == other.val;
    }

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        try w.print("k: {d} f: {d}", .{ self.val, self.flags orelse 256 });
    }
};

pub const KeyPress = struct {
    key: Key,
    triggered_at: std.time.Instant,

    const Self = @This();
    pub fn init(key: Key) !Self {
        return .{
            .key = key,
            .triggered_at = try std.time.Instant.now(),
        };
    }

    pub fn ms_diff(self: Self, other: Self) u64 {
        return self.triggered_at.since(other.triggered_at) / 1000000;
    }
};

pub const Command = union(enum) {
    vol_up: u8,
    vol_down: u8,
    mute,

    const Self = @This();
    pub fn format(self: Self, w: *std.Io.Writer) !void {
        switch (self) {
            .vol_up => |x| try w.print("vol up by {d}\n", .{x}),
            .vol_down => |x| try w.print("vol down by {d}\n", .{x}),
            .mute => try w.print("toggle mute\n", .{}),
        }
    }
};

pub const KeyCommand = struct {
    key: Key,
    cmd: Command,
    retrigger: bool,
    trigger_per_ms: u64 = 300,

    const Self = @This();
    pub fn init(press: Key, cmd: Command, retrigger: bool) Self {
        return .{
            .key = press,
            .cmd = cmd,
            .retrigger = retrigger,
        };
    }

    pub fn eq(self: Self, other: KeyPress) bool {
        return self.key.eq(other.key);
    }

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        try w.print("key: {f} cmd: {f} retrig {any}", .{ self.key, self.cmd, self.retrigger });
    }

    pub fn shouldTrigger(self: Self, curr: KeyPress, prev: KeyPress) bool {
        if (!self.key.eq(curr.key)) {
            return true;
        } else if (self.retrigger == false) {
            return false;
        }

        const trig_per_ms: u64 = 300;
        return trig_per_ms <= curr.ms_diff(prev);
    }
};

pub const Config = struct {
    vol_up: KeyCommand,
    vol_down: KeyCommand,
    mute: KeyCommand,

    const Self = @This();

    pub fn default() Self {
        return .{
            .vol_up = KeyCommand.init(
                .{ .val = 111, .flags = 9437448, .down = true },
                .{ .vol_up = 1 },
                true,
            ),
            .vol_down = KeyCommand.init(
                .{ .val = 113, .flags = 9437448, .down = true },
                .{ .vol_down = 1 },
                true,
            ),
            .mute = KeyCommand.init(
                .{ .val = 109, .flags = 9437448, .down = true },
                .{ .mute = {} },
                true,
            ),
        };
    }

    pub fn cmdFromKey(self: Self, key: KeyPress) ?KeyCommand {
        if (self.vol_up.eq(key)) {
            return self.vol_up;
        } else if (self.vol_down.eq(key)) {
            return self.vol_down;
        } else if (self.mute.eq(key)) {
            return self.mute;
        }
        return null;
    }
};
