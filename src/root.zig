const std = @import("std");
const midi = @import("./coremidi.zig").lib;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

const devices = @import("./devices.zig");
const Client = devices.Client;
const Source = devices.Source;
const Message = devices.Message;
const keys = @import("keys");
const KeyQueue = keys.KeyQueue;

pub const MidiState = struct {
    mu: std.Thread.Mutex,

    vol: u8,
    ch: u8,

    client: *Client,
    source: *Source,

    const Self = @This();
    pub fn init(alloc: Allocator, vol: u8, ch: u8) Self {
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

        std.log.info("SENT {f}\n", .{m});
        const midi_data = m.asData(self.ch);
        try self.source.send(midi_data);
    }
};

const KeyCommand = struct { []const u8, Message };
pub fn msgFromKeys(state: *const MidiState, vals: []const u8) ?Message {
    const cmds = [_]KeyCommand{
        .{ &[_]u8{0}, .{ .vol = state.vol -| 1 } },
        .{ &[_]u8{1}, .{ .vol = state.vol +| 1 } },
        .{ &[_]u8{2}, .{ .mute = {} } },
    };
    for (cmds) |cmd| {
        const k, const msg = cmd;
        if (std.mem.eql(u8, vals, k)) {
            return msg;
        }
    }
    return null;
}

pub fn run(alloc: Allocator) !void {
    var state = MidiState.init(alloc, 64, 1);
    var queue = KeyQueue.init(alloc);
    _ = &state;

    const handle = try std.Thread.spawn(.{}, keys.keyTaps, .{&queue});
    defer handle.join();

    // TODO: Figure out why state is not sending MIDI to system
    while (true) {
        if (queue.take(alloc)) |held| {
            if (msgFromKeys(&state, held)) |msg| {
                try state.handleMessage(msg);
            }
        }
        std.Thread.sleep(std.time.ns_per_ms * 3);
    }
    std.log.info("FINISHED", .{});
}
