const std = @import("std");
const midi = @import("./coremidi.zig").lib;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

const devices = @import("./devices.zig");
const Client = devices.Client;
const Source = devices.Source;
const Message = devices.Message;

pub fn setup(reader: *std.Io.Reader) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var client = try Client.init(alloc, "ncontrol_client");
    defer client.deinit();

    var source = try Source.init(alloc, &client, "ncontroller");
    defer source.deinit();

    const ch = 0;
    while (true) {
        const b = reader.takeByte() catch break;
        switch (b) {
            'a' => try source.send(Message.vol_down.asData(ch)),
            'b' => try source.send(Message.vol_up.asData(ch)),
            'c' => try source.send(Message.mute.asData(ch)),
            else => {},
        }

        std.Thread.sleep(std.time.ns_per_ms * 15);
    }
}
