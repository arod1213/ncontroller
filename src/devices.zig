const std = @import("std");
const midi = @import("./coremidi.zig").lib;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;
const utils = @import("./utils.zig");

pub const Client = struct {
    ptr: midi.MIDIClientRef,
    name: midi.CFStringRef,

    const Self = @This();

    pub fn init(alloc: Allocator, name: []const u8) !Self {
        const ptr: *midi.MIDIClientRef = try alloc.create(midi.MIDIClientRef);
        const tag = utils.strToCFString(name);

        try utils.cTry(midi.MIDIClientCreate(tag, null, null, ptr));
        return .{
            .ptr = ptr.*,
            .name = tag,
        };
    }

    pub fn deinit(self: *Self) void {
        midi.CFRelease(self.name);
    }
};

pub const Source = struct {
    ptr: midi.MIDIEndpointRef,
    name: midi.CFStringRef,
    client: midi.MIDIClientRef,

    const Self = @This();

    pub fn init(alloc: Allocator, client: *const Client, name: []const u8) !Self {
        const ptr: *midi.MIDIEndpointRef = try alloc.create(midi.MIDIEndpointRef);
        const tag = utils.strToCFString(name);

        const result = midi.MIDISourceCreate(client.ptr, tag, ptr);
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
        midi.CFRelease(self.name);
    }

    pub fn send(self: *Self, msg: [3]u8) !void {
        var packetList: midi.MIDIPacketList = undefined;
        var packet = midi.MIDIPacketListInit(&packetList);

        packet = midi.MIDIPacketListAdd(
            &packetList,
            @sizeOf(midi.MIDIPacketList),
            packet,
            0,
            msg.len,
            &msg,
        );

        if (packet == null) {
            return error.MIDIPacketListFull;
        }

        try utils.cTry(midi.MIDIReceived(self.ptr, &packetList));
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
