const std = @import("std");
const c = @import("./coregraphics.zig").lib;
pub const config = @import("config");

const types = @import("./types.zig");
pub const KeyQueue = types.KeyQueue;

fn eventCallback(
    _: c.CGEventTapProxy, // proxy
    type_: c.CGEventType,
    event: c.CGEventRef,
    queue: ?*anyopaque,
) callconv(.c) c.CGEventRef {
    const queue_ptr: *KeyQueue = @ptrCast(@alignCast(queue));

    switch (type_) {
        10, 11 => { // key presses
            const flags = switch (c.CGEventGetFlags(event)) {
                256 => null,
                else => |x| x,
            };

            const keycode = c.CGEventGetIntegerValueField(
                event,
                c.kCGKeyboardEventKeycode,
            );

            const is_down = type_ == 10;

            // std.log.info("key {d} flag {d}", .{ keycode, flags orelse 256 });
            const key_press = config.KeyPress.init(.{
                .val = @intCast(keycode),
                .flags = flags,
                .down = is_down,
            }) catch @panic("invalid key");
            queue_ptr.handleKey(key_press) catch @panic("fucked");
        },
        else => {},
    }

    return event;
}

pub fn handleKeys(queue: *KeyQueue) void {
    const tap = c.CGEventTapCreate(
        c.kCGSessionEventTap,
        c.kCGHeadInsertEventTap,
        c.kCGEventTapOptionDefault,
        (1 << c.kCGEventKeyDown) | (1 << c.kCGEventKeyUp),
        eventCallback,
        queue,
    );
    if (tap == null) {
        @panic("Missing accessibility permissions");
    }

    const run_loop_source = c.CFMachPortCreateRunLoopSource(null, tap, 0);
    c.CFRunLoopAddSource(
        c.CFRunLoopGetCurrent(),
        run_loop_source,
        c.kCFRunLoopCommonModes,
    );

    c.CGEventTapEnable(tap, true);
    c.CFRunLoopRun();
    std.log.info("KEY LOOP CLOSED", .{});
}
