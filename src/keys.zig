const std = @import("std");
const keys = @import("./coregraphics.zig").lib;
const print = std.debug.print;
const Allocator = std.mem.Allocator;

pub const KeyQueue = struct {
    alloc: Allocator,
    keyDowns: ?std.ArrayList(u8),
    // keyUp: u8,
    mu: std.Thread.Mutex,

    const Self = @This();
    pub fn init(alloc: Allocator) Self {
        return .{
            .alloc = alloc,
            .keyDowns = null,
            .mu = std.Thread.Mutex{},
        };
    }

    pub fn handleKey(self: *Self, key: u8, down: bool) !void {
        if (down) {
            return try self.keyDown(key);
        } else {
            return try self.keyUp(key);
        }
    }

    fn keyUp(self: *Self, key: u8) !void {
        self.mu.lock();
        defer self.mu.unlock();
        if (self.keyDowns) |k| {
            for (k.items, 0..) |val, i| {
                if (val == key) {
                    _ = self.keyDowns.?.orderedRemove(i);
                }
            }
        }
    }

    fn keyDown(self: *Self, key: u8) !void {
        self.mu.lock();
        defer self.mu.unlock();
        if (self.keyDowns == null) {
            self.keyDowns = try std.ArrayList(u8).initCapacity(self.alloc, 3);
        }
        try self.keyDowns.?.append(self.alloc, key);
    }

    pub fn take(self: *Self, alloc: Allocator) ?[]const u8 {
        self.mu.lock();
        defer self.mu.unlock();

        if (self.keyDowns != null) {
            const x = self.keyDowns.?.toOwnedSlice(alloc) catch return null;
            self.keyDowns = null;
            return x;
        }
        return null;
    }
};

fn eventCallback(
    _: keys.CGEventTapProxy, // proxy
    type_: keys.CGEventType,
    event: keys.CGEventRef,
    queue: ?*anyopaque,
) callconv(.c) keys.CGEventRef {
    const queue_ptr: *KeyQueue = @ptrCast(@alignCast(queue));

    switch (type_) {
        10, 11 => { // key presses
            const keycode = keys.CGEventGetIntegerValueField( // == keycode
                event,
                keys.kCGKeyboardEventKeycode,
            );
            const is_down = type_ == 10;

            // std.log.info("key {d} down {any}\n", .{ keycode, is_down });
            queue_ptr.handleKey(@intCast(keycode), is_down) catch @panic("fucked");
        },
        else => {},
    }

    return event;
}

pub fn keyTaps(queue: *KeyQueue) void {
    const tap = keys.CGEventTapCreate(
        keys.kCGSessionEventTap,
        keys.kCGHeadInsertEventTap,
        keys.kCGEventTapOptionDefault,
        (1 << keys.kCGEventKeyDown) | (1 << keys.kCGEventKeyUp),
        eventCallback,
        queue,
    );
    if (tap == null) {
        @panic("Missing accessibility permissions");
    }

    const run_loop_source = keys.CFMachPortCreateRunLoopSource(null, tap, 0);
    keys.CFRunLoopAddSource(
        keys.CFRunLoopGetCurrent(),
        run_loop_source,
        keys.kCFRunLoopCommonModes,
    );

    keys.CGEventTapEnable(tap, true);
    keys.CFRunLoopRun();
    std.log.info("KEY LOOP CLOSED", .{});
}

fn getModifers(alloc: Allocator) ![]const u8 {
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

// pub fn cmdTaps(queue: *KeyQueue) void {
//     const alloc = std.heap.page_allocator;
//
//     while (true) {
//         const held = getModifers(alloc) catch return;
//         // defer alloc.free(held);
//
//         queue.set(held);
//         std.Thread.sleep(100 * std.time.ns_per_ms);
// }
//     }
