const std = @import("std");
const read = @import("./read.zig");
const binds = @import("./binds.zig");

fn midiMsg(channel: u8, cc: u8, val: u8) [3]u8 {
    return [_]u8{ 0xB0 + channel, cc, val };
}

pub const MidiMessage = union(enum) {
    vol: u8,
    mute,

    const Self = @This();
    pub fn asData(self: Self, track: u8) [3]u8 {
        return switch (self) {
            .vol => |x| midiMsg(0, track, x),
            .mute => midiMsg(1, track, 127),
        };
    }

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        switch (self) {
            .vol => |x| {
                try w.print("VOL to {d}", .{x});
            },
            .mute => try w.print("TOGGLE MUTE", .{}),
        }
    }
};

pub fn msgFromKeys(config: *read.Config, cmd: binds.KeyCommand) ?MidiMessage {
    if (cmd.eq(config.vol_up)) {
        if (cmd.shouldTrigger(config.vol_up)) {
            return .{ .vol = 1 };
        }
    } else if (cmd.eq(config.vol_down)) {
        if (cmd.shouldTrigger(config.vol_down)) {
            return .{ .vol = -1 };
        }
    } else if (cmd.eq(config.mute)) {
        if (cmd.shouldTrigger(config.mute)) {
            return .{ .mute = {} };
        }
    } else {
        return null;
    }
    return null;
}
