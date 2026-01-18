const std = @import("std");
const keys = @import("./coregraphics.zig").lib;
const print = std.debug.print;
const Allocator = std.mem.Allocator;

pub const KeyCommand = struct {
    key: u8,
    flags: ?u64,

    timestamp: std.time.Instant,

    const Self = @This();
    pub fn init(key: u8, flags: ?u64) !Self {
        return .{
            .timestamp = try std.time.Instant.now(),
            .key = key,
            .flags = flags,
        };
    }

    pub fn retrigger(self: Self, other: Self) bool {
        if (!self.eq(other)) {
            return true;
        }
        const tpms: i64 = 30; // triggers per milli second
        const ms_diff = self.timestamp.since(other.timestamp) / 1000000;
        return tpms <= ms_diff;
    }

    pub fn eq(self: Self, other: Self) bool {
        return self.flags == other.flags and self.key == other.key;
    }

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        try w.print("k: {d} f: {d}", .{ self.key, self.flags orelse 256 });
    }
};

pub const KeyQueue = struct {
    alloc: Allocator,

    prev: ?KeyCommand,
    curr: ?KeyCommand,

    mu: std.Thread.Mutex,

    const Self = @This();
    pub fn init(alloc: Allocator) Self {
        return .{
            .alloc = alloc,
            .prev = null,
            .curr = null,
            .mu = std.Thread.Mutex{},
        };
    }

    // TODO: Prevent repeat presses of mute key command
    pub fn handleKey(self: *Self, key: u8, flags: ?u64, down: bool) !void {
        if (down) {
            self.mu.lock();
            defer self.mu.unlock();

            const cmd = try KeyCommand.init(key, flags);
            if (self.prev != null) {
                // TODO: add timeout to key comamnd to allow throttled commands
                // block repeated commands
                if (!cmd.retrigger(self.prev.?)) {
                    return;
                }
            }

            print("SETTING", .{});
            self.curr = cmd;
            return;
        }
    }

    pub fn take(self: *Self) ?KeyCommand {
        self.mu.lock();
        defer self.mu.unlock();

        const x = self.curr;
        // TODO: this is overriding real previous command
        if (x != null) {
            self.prev = x;
        }
        self.curr = null;
        return x;
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
            const flags = switch (keys.CGEventGetFlags(event)) {
                256 => null,
                else => |x| x,
            };

            const keycode = keys.CGEventGetIntegerValueField(
                event,
                keys.kCGKeyboardEventKeycode,
            );

            const is_down = type_ == 10;

            std.log.info("key {d} flag {d}", .{ keycode, flags orelse 256 });
            queue_ptr.handleKey(@intCast(keycode), flags, is_down) catch @panic("fucked");
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
