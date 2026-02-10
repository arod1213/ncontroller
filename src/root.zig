const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

const keys = @import("zigkeys");
const Key = keys.Key;
const Modifier = keys.Modifier;
const KeyQueue = keys.KeyQueue;

const zmidi = @import("zmidi");

const Message = enum {
    vol_up,
    vol_down,
    mute,
};
const T = keys.KeyCommand(Message);

const State = struct {
    mu: std.Thread.Mutex = std.Thread.Mutex{},
    vol: u7,

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

fn handleMessage(ctx: *Ctx, kc: T) !void {
    ctx.state.handleMessage(kc.cmd);
    for (ctx.state.channels) |ch| {
        switch (kc.cmd) {
            .vol_up, .vol_down => {
                const data = zmidi.midiMsg(ch, 1, @intCast(ctx.state.vol));
                try ctx.midi_state.handleMidi(data);
            },
            .mute => {
                const data = zmidi.midiMsg(ch, 2, 127);
                try ctx.midi_state.handleMidi(data);
            },
        }
    }
}

const Ctx = struct {
    state: *State,
    midi_state: *zmidi.MidiThroughput,
};

pub fn run(alloc: Allocator) !void {
    const destination = try zmidi.devices.getEndpointByName(alloc, "NControl");
    var midi_state = try zmidi.MidiThroughput.init("client", "output", destination);

    var state = State{ .channels = &[_]u8{ 1, 2 }, .vol = 64 };
    var ctx = Ctx{ .midi_state = &midi_state, .state = &state };

    const cmds = [_]T{.{
        .cmd = .vol_up,
        .key = Key.init(0, &[_]Modifier{.{ .shift = .either }}, true),
        .retrigger = false,
        .use = "",
    }};
    var key_handler = keys.Config(Message).init(&cmds);
    // key_handler.should_log = true;

    try keys.run(alloc, Message, &key_handler, &ctx, handleMessage);
}
