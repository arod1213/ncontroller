const std = @import("std");
const midi = @import("./coremidi.zig").lib;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

const devices = @import("./devices.zig");
const Client = devices.Client;
const Source = devices.Source;
const Message = devices.Message;

const State = struct {
    vol: u8,
    ch: u8,
    mu: std.Thread.Mutex,

    const Self = @This();
    pub fn init(vol: u8, ch: u8) Self {
        return .{
            .vol = vol,
            .ch = ch,
            .mu = std.Thread.Mutex{},
        };
    }

    pub fn change(self: *Self, val: i8) void {
        self.mu.lock();
        defer self.mu.unlock();

        const cast: i8 = @intCast(self.vol);
        const new_val = cast +| val;
        self.vol = @intCast(new_val);
    }
};

fn handleKeyPress(state: *State, source: *Source, key: u8) !void {
    const data: ?Message = switch (key) {
        'a' => blk: {
            state.change(-1);
            break :blk .{ .vol = state.vol };
        },
        's' => blk: {
            state.change(1);
            break :blk .{ .vol = state.vol };
        },
        'd' => .{ .mute = {} },
        else => null,
    };

    if (data) |d| {
        try source.send(d.asData(state.ch));
    }
}

pub fn setup(reader: *std.Io.Reader) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var client = try Client.init(alloc, "ncontrol_client");
    defer client.deinit();

    var source = try Source.init(alloc, &client, "ncontroller");
    defer source.deinit();

    var state = State.init(64, 16);
    while (true) {
        const b = reader.takeByte() catch break;
        try handleKeyPress(&state, &source, b);
        std.Thread.sleep(std.time.ns_per_ms * 3);
    }
}
