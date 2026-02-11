const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

const keys = @import("zigkeys");
const Key = keys.Key;
const Modifier = keys.Modifier;
const KeyQueue = keys.KeyQueue;

const zmidi = @import("zmidi");

pub const config = @import("config.zig");
const Message = config.Message;
pub const State = config.State;

const T = keys.KeyCommand(Message);

fn handleMessage(ctx: *Ctx, kc: T) !void {
    ctx.state.handleMessage(kc.cmd);
    for (ctx.state.channels) |ch| {
        switch (kc.cmd) {
            .vol_up, .vol_down => {
                const data = zmidi.midiMsg(0, ch, @intCast(ctx.state.vol));
                try ctx.midi_state.handleMidi(data);
            },
            .mute => {
                const data = zmidi.midiMsg(1, ch, 127);
                try ctx.midi_state.handleMidi(data);
            },
        }
    }
}

const Ctx = struct {
    state: *State,
    midi_state: *zmidi.MidiThroughput,
};

pub fn run(alloc: Allocator, state: *State) !void {
    const destination = try zmidi.devices.getEndpointByName(alloc, "NControl");
    var midi_state = try zmidi.MidiThroughput.init("client", "output", destination);

    var ctx = Ctx{ .midi_state = &midi_state, .state = state };

    const trig_speed = 40;
    const cmds = [_]T{
        .{
            .cmd = .vol_up,
            .key = Key.init(
                111,
                &[_]Modifier{
                    .{ .command = .either },
                    .{ .fn_key = {} },
                },
                true,
            ),
            .retrigger = true,
            .trigger_per_ms = trig_speed,
            .use = "Vol Up",
        },
        .{
            .cmd = .vol_down,
            .key = Key.init(
                103,
                &[_]Modifier{
                    .{ .command = .either },
                    .{ .fn_key = {} },
                },
                true,
            ),
            .retrigger = true,
            .trigger_per_ms = trig_speed,
            .use = "Vol Down",
        },
        .{
            .cmd = .mute,
            .key = Key.init(
                109,
                &[_]Modifier{
                    .{ .command = .either },
                    .{ .fn_key = {} },
                },
                true,
            ),
            .retrigger = false,
            .use = "Mute",
        },
    };
    const key_handler = keys.Config(Message).init(&cmds);
    try keys.run(alloc, Message, &key_handler, &ctx, handleMessage);
}
