const std = @import("std");
const c = @import("./coremidi.zig").lib;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;
const utils = @import("./utils.zig");

pub const Client = struct {
    ptr: c.MIDIClientRef,
    name: c.CFStringRef,

    const Self = @This();

    pub fn init(name: []const u8) !Self {
        const tag = utils.strToCFString(name);
        var client_ref: c.MIDIClientRef = undefined;
        try utils.cTry(c.MIDIClientCreate(tag, null, null, &client_ref));

        return .{
            .ptr = client_ref,
            .name = tag,
        };
    }

    pub fn deinit(self: *Self) void {
        c.CFRelease(self.name);
    }
};

pub const Source = struct {
    ptr: c.MIDIEndpointRef,
    name: c.CFStringRef,
    client: c.MIDIClientRef,

    const Self = @This();

    pub fn init(client: *const Client, name: []const u8) !Self {
        const tag = utils.strToCFString(name);
        var client_ref: c.MIDIClientRef = undefined;
        try utils.cTry(c.MIDISourceCreate(client.ptr, tag, &client_ref));

        return .{
            .ptr = client_ref,
            .name = tag,
            .client = client.ptr,
        };
    }

    pub fn deinit(self: *Self) void {
        c.CFRelease(self.name);
    }

    pub fn send(self: *Self, msg: [3]u8) !void {
        var packetList: c.MIDIPacketList = undefined;
        var packet = c.MIDIPacketListInit(&packetList);

        packet = c.MIDIPacketListAdd(
            &packetList,
            @sizeOf(c.MIDIPacketList),
            packet,
            0,
            msg.len,
            &msg,
        );

        if (packet == null) {
            return error.MIDIPacketListFull;
        }

        try utils.cTry(c.MIDIReceived(self.ptr, &packetList));
    }
};

pub fn midiMsg(channel: u8, cc: u8, val: u8) [3]u8 {
    return [_]u8{ 0xB0 + channel, cc, val };
}

pub const Msg = union(enum) {
    vol: u7, // 0 to 127
    mute,

    const Self = @This();
    pub fn asData(self: Self, track: u4) [3]u8 {
        return switch (self) {
            .vol => |x| midiMsg(0, @intCast(track), @intCast(x)),
            .mute => midiMsg(1, @intCast(track), 127),
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
