const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

// pub const setup = @import("./setup.zig");

const midi = @import("midi");
const Client = midi.Client;
const Source = midi.Source;
const MidiMsg = midi.Msg;
const MidiState = midi.MidiState;

const zigkeys = @import("zigkeys");
const Key = zigkeys.Key;
const Modifier = zigkeys.Modifier;

const KC = zigkeys.KeyCommand(Msg);
pub const Msg = union(enum) {
    vol_up: u7,
    vol_down: u7,
    default_vol: u7,
    mute,

    const Self = @This();
    pub fn format(self: Self, w: *std.Io.Writer) !void {
        switch (self) {
            .vol_up => |x| try w.print("vol up by {d}\n", .{x}),
            .vol_down => |x| try w.print("vol down by {d}\n", .{x}),
            .default_vol => |x| try w.print("set to default vol {d}\n", .{x}),
            .mute => try w.print("toggle mute\n", .{}),
        }
    }

    pub fn toMidiMsg(self: Self, state: *const MidiState) MidiMsg {
        return switch (self) {
            .vol_up => |x| MidiMsg{ .vol = state.vol +| x },
            .vol_down => |x| MidiMsg{ .vol = state.vol -| x },
            .default_vol => |x| MidiMsg{ .vol = x },
            .mute => MidiMsg{ .mute = {} },
        };
    }
};

pub fn handle(state: *MidiState, k: KC) !void {
    try state.handleMessage(k.cmd.toMidiMsg(state));
}

pub fn run(alloc: Allocator) !void {
    var state = MidiState.init(64, &[_]u4{ 0, 1 });
    _ = &state;

    const cmds = [_]KC{
        KC.init(
            Key.init(11, &[_]Modifier{.control}, true),
            .mute,
            false,
            "mute",
        ),
    };

    var settings = zigkeys.Config(Msg).init(&cmds);
    try zigkeys.run(alloc, Msg, &settings, &state, handle);
}
