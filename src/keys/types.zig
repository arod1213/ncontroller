const std = @import("std");
const keys = @import("./coregraphics.zig").lib;
const print = std.debug.print;
const Allocator = std.mem.Allocator;

pub const config = @import("config");

fn isRetrigger(a: config.KeyPress, b: ?config.KeyPress) bool {
    if (a.key.down) {
        if (b) |p| {
            if (p.key.eq(a.key)) {
                return true;
            }
        }
    }
    return false;
}

pub const KeyQueue = struct {
    alloc: Allocator,
    settings: config.Config,

    prev: ?config.KeyPress,
    curr: ?config.KeyPress,

    mu: std.Thread.Mutex,

    const Self = @This();
    pub fn init(alloc: Allocator, settings: ?config.Config) Self {
        const s = if (settings == null) config.Config.default() else settings.?;
        return .{
            .alloc = alloc,
            .settings = s,
            .prev = null,
            .curr = null,
            .mu = std.Thread.Mutex{},
        };
    }

    pub fn clear(self: *Self) void {
        self.mu.lock();
        defer self.mu.unlock();
        self.curr = null;
        std.log.info("CLEARED", .{});
    }

    // TODO: Prevent repeat presses of mute key command
    pub fn handleKey(self: *Self, press: config.KeyPress) !void {
        self.mu.lock();
        defer self.mu.unlock();
        if (press.key.down) {
            // comment this out if we want to use system key retrigger timing
            if (isRetrigger(press, self.prev)) {
                return;
            }

            if (self.settings.cmdFromKey(press)) |cmd| {
                if (self.prev != null and !cmd.shouldTrigger(press, self.prev)) {
                    return; // prevent retrigger
                }
            }

            self.curr = press;
            return;
        } else {
            if (self.prev) |prev| {
                if (press.key.eq(prev.key)) {
                    self.prev = null;
                }
            }
        }
    }

    pub fn take(self: *Self) ?config.KeyPress {
        self.mu.lock();
        defer self.mu.unlock();

        const x = self.curr;
        if (x != null) {
            self.prev = x;
        }

        // put this back if we want to use system key retrigger timing
        // self.curr = null;
        return x;
    }
};
