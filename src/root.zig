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
    var state = MidiState.init(64, 1);
    const settings = try config.read.readConfig();
    var queue = KeyQueue.init(alloc, settings);
    _ = &state;

    const handle = try std.Thread.spawn(.{}, keys.handleKeys, .{&queue});
    defer handle.join();

    while (true) {
        if (queue.take()) |press| {
            // std.log.info("press is {f}\n", .{press.key});
            if (queue.settings.cmdFromKey(press)) |cmd| {
                try state.handleMessage(cmdToMessage(&state, cmd.cmd));
            }
        }
        std.Thread.sleep(std.time.ns_per_ms * 3);
    }
    std.log.info("FINISHED", .{});
}
