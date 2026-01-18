const std = @import("std");
const keys = @import("./coregraphics.zig").lib;
const print = std.debug.print;
const Allocator = std.mem.Allocator;

pub fn getHeldKeys(alloc: Allocator) ![]const u8 {
    var list = try std.ArrayList(u8).initCapacity(alloc, 3);
    defer list.deinit(alloc);

    for (0..128) |keycode| {
        const is_pressed = keys.CGEventSourceKeyState(
            keys.kCGEventSourceStateHIDSystemState,
            @intCast(keycode),
        );

        if (is_pressed) {
            try list.append(alloc, @intCast(keycode));
        }
    }

    return try list.toOwnedSlice(alloc);
}

pub fn monitor() !void {
    const alloc = std.heap.page_allocator;

    // Monitor keys every 100ms
    while (true) {
        const held = try getHeldKeys(alloc);
        defer alloc.free(held);
        if (held.len > 0) {
            for (held) |d| {
                print("code: {d} ", .{d});
            }
        }
        print("\n", .{});
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
}
