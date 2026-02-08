const std = @import("std");
const midi = @import("./coremidi.zig").lib;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

const devices = @import("./devices.zig");
pub const Client = devices.Client;
pub const Source = devices.Source;
pub const Msg = devices.Msg;

pub const MidiState = struct {
    mu: std.Thread.Mutex,

    vol: u7, // 0 to 127
    ch: []const u4, // 0 to 16

    client: Client,
    source: Source,

    const Self = @This();
    pub fn init(vol: u7, ch: []const u4) Self {
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

    pub fn handleMessage(self: *Self, m: Msg) !void {
        self.mu.lock();
        defer self.mu.unlock();

        switch (m) {
            .vol => |x| self.vol = x,
            .mute => {},
        }

        std.log.info("SENT {f}", .{m});
        for (self.ch) |ch| {
            const midi_data = m.asData(ch);
            self.source.send(midi_data) catch |e| {
                std.log.err("failed to send midi: {any}", .{e});
                return;
            };
        }
    }
};
