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

    pub fn init(alloc: Allocator, name: []const u8) !Self {
        const ptr: *c.MIDIClientRef = try alloc.create(c.MIDIClientRef);
        const tag = utils.strToCFString(name);

        try utils.cTry(c.MIDIClientCreate(tag, null, null, ptr));
        return .{
            .ptr = ptr.*,
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

    pub fn init(alloc: Allocator, client: *const Client, name: []const u8) !Self {
        const ptr: *c.MIDIEndpointRef = try alloc.create(c.MIDIEndpointRef);
        const tag = utils.strToCFString(name);

        const result = c.MIDISourceCreate(client.ptr, tag, ptr);
        std.debug.print("MIDISourceCreate result: {}\n", .{result});
        std.debug.print("Virtual device pointer: {*}\n", .{ptr});
        try utils.cTry(result);

        return .{
            .ptr = ptr.*,
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

fn midiMsg(channel: u8, cc: u8, val: u8) [3]u8 {
    return [_]u8{ 0xB0 + channel, cc, val };
}

pub const Message = union(enum) {
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
