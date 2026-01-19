const std = @import("std");
const keys = @import("./coregraphics.zig").lib;
const Allocator = std.mem.Allocator;

pub const config = @import("config");

pub const KeyQueue = struct {
    alloc: Allocator,
    settings: config.Config,

    prev: ?config.KeyPress,
    curr: ?config.KeyPress,

    mu: std.Thread.Mutex,

    const Self = @This();
    pub fn init(alloc: Allocator, settings: config.Config) Self {
        return .{
            .alloc = alloc,
            .settings = settings,
            .prev = null,
            .curr = null,
            .mu = std.Thread.Mutex{},
        };
    }

    // TODO: Prevent repeat presses of mute key command
    pub fn handleKey(self: *Self, press: config.KeyPress) !void {
        if (press.key.down) {
            self.mu.lock();
            defer self.mu.unlock();

            if (self.settings.cmdFromKey(press)) |cmd| {
                if (self.prev != null and !cmd.shouldTrigger(press, self.prev.?)) {
                    return; // prevent retrigger
                }
            }

            std.log.info("SETTING", .{});
            self.curr = press;
            return;
        }
    }

    pub fn take(self: *Self) ?config.KeyPress {
        self.mu.lock();
        defer self.mu.unlock();

        const x = self.curr;
        if (x != null) {
            self.prev = x;
        }

        self.curr = null;
        return x;
    }
};
