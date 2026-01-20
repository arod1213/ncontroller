const std = @import("std");
const midi = @import("./coremidi.zig").lib;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

const devices = @import("./devices.zig");
pub const Client = devices.Client;
pub const Source = devices.Source;
pub const Message = devices.Message;

pub const MidiState = struct {
    mu: std.Thread.Mutex,

    vol: u7, // 0 to 127
    ch: u4, // 0 to 16

    client: *Client,
    source: *Source,

    const Self = @This();
    pub fn init(alloc: Allocator, vol: u7, ch: u4) Self {
        var c = Client.init(alloc, "ncontrol_client") catch @panic("failed to set client");
        var s = Source.init(alloc, &c, "ncontroller") catch @panic("failed to set source");

        return .{
            .mu = std.Thread.Mutex{},
            .vol = vol,
            .ch = ch,
            .client = &c,
            .source = &s,
        };
    }

    pub fn deinit(self: *Self) void {
        self.source.deinit();
        self.client.deinit();
    }

    pub fn handleMessage(self: *Self, m: Message) !void {
        self.mu.lock();
        defer self.mu.unlock();

        switch (m) {
            .vol => |x| self.vol = x,
            .mute => {},
        }

        std.log.info("SENT {f}", .{m});
        const midi_data = m.asData(self.ch);
        try self.source.send(midi_data);
    }
};

// TODO: accept config to load in user key commands here
const KeyCommand = struct { u8, ?u64, Message };
pub fn msgFromKeys(state: *const MidiState, key: u8, flag: ?u64) ?Message {
    const cmds = [_]KeyCommand{
        .{ 111, 9437448, .{ .vol = state.vol +| 1 } }, // cmd + f12
        .{ 103, 9437448, .{ .vol = state.vol -| 1 } }, // cmd + f11
        .{ 109, 9437448, .{ .mute = {} } }, // cmd + f10
    };
    for (cmds) |cmd| {
        const k, const f, const msg = cmd;
        if (k == key and f == flag) {
            return msg;
        }
    }
    return null;
}
