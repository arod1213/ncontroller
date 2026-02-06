const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

const keys = @import("keys");
const config = keys.config;
const KeyQueue = keys.KeyQueue;

const midi = @import("midi");
pub const setup = @import("./setup.zig");
const Client = midi.Client;
const Source = midi.Source;
const Message = midi.Message;
const MidiState = midi.MidiState;

fn cmdToMessage(state: *const MidiState, cmd: config.Command) Message {
    return switch (cmd) {
        .vol_up => |x| Message{ .vol = state.vol +| x },
        .vol_down => |x| Message{ .vol = state.vol -| x },
        .default_vol => |x| Message{ .vol = x },
        .mute => Message{ .mute = {} },
    };
}

pub fn run(alloc: Allocator) !void {
    const settings = try config.read.readConfig(alloc);

    var state = MidiState.init(64, settings.channels);
    var queue = KeyQueue.init(alloc, settings);
    _ = &state;

    const handle = try std.Thread.spawn(.{}, keys.handleKeys, .{&queue});
    defer handle.join();

    while (true) {
        if (queue.take()) |press| {
            if (queue.settings.cmdFromKey(press)) |cmd| {
                try state.handleMessage(cmdToMessage(&state, cmd.cmd));
                if (cmd.trigger_per_ms == 0 or !cmd.retrigger) {
                    queue.clear();
                } else {
                    std.Thread.sleep(std.time.ns_per_ms * cmd.trigger_per_ms);
                }
            }
        }
        std.Thread.sleep(std.time.ns_per_ms * 3);
    }
    std.log.info("FINISHED", .{});
}

pub fn testing() !void {
    print("TESTING", .{});
    var state = MidiState.init(64, &[_]u4{ 0, 1 });
    _ = &state;

    for (0..16) |chan| {
        for (0..127) |cc| {
            std.log.info("running chan {d} cc {d}", .{ chan, cc });

            const down = midi.midiMsg(@intCast(chan), @intCast(cc), 0);
            try state.handleMidi(down);

            std.Thread.sleep(std.time.ns_per_ms * 50);

            const up = midi.midiMsg(@intCast(chan), @intCast(cc), 127);
            try state.handleMidi(up);

            std.Thread.sleep(std.time.ns_per_ms * 50);
        }
    }
    std.log.info("FINISHED", .{});
}
