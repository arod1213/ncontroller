const std = @import("std");
const midi = @import("./coremidi.zig").lib;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

const devices = @import("./devices.zig");
pub const Client = devices.Client;
pub const Source = devices.Source;
pub const Message = devices.Message;
pub const midiMsg = devices.midiMsg;

pub const MidiState = struct {
    mu: std.Thread.Mutex,

    vol: u7, // 0 to 127
    ch: u4, // 0 to 16

    client: Client,
    source: Source,

    const Self = @This();
    pub fn init(vol: u7, ch: u4) Self {
        const c = Client.init("ncontrol_client") catch @panic("failed to set client");
        const s = Source.init(&c, "ncontroller") catch @panic("failed to set source");

        return .{
            .mu = std.Thread.Mutex{},
            .vol = vol,
            .ch = ch,
            .client = c,
            .source = s,
        };
    }

    pub fn deinit(self: *Self) void {
        self.source.deinit();
        self.client.deinit();
    }

    pub fn handleMidi(self: *Self, data: [3]u8) !void {
        self.mu.lock();
        defer self.mu.unlock();

        self.source.send(data) catch |e| {
            std.log.err("failed to send midi: {any}", .{e});
            return;
        };
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
        self.source.send(midi_data) catch |e| {
            std.log.err("failed to send midi: {any}", .{e});
            return;
        };
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
