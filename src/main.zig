const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

const menuczar = @import("menuczar");
const ncontroller = @import("ncontroller");

fn appLoop() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var default_state = ncontroller.config.defaultState(alloc) catch
        ncontroller.State{
            .channels = &[_]u8{ 0, 1 },
        };

    for (default_state.channels) |ch| {
        print("ch {d} ", .{ch});
    }
    ncontroller.run(alloc, &default_state) catch @panic("failed to run app");
}

pub fn main() !void {
    try menuczar.run(.{ .icon = "tuningfork" }, appLoop);
}

// fn setupTermios(handle: posix.fd_t) !void {
//     var settings = try posix.tcgetattr(handle);
//     settings.lflag.ICANON = false;
//     settings.lflag.ECHO = false;
//     _ = try posix.tcsetattr(handle, posix.TCSA.NOW, settings);
// }
//
// pub fn main() !void {
//     const stdin = std.fs.File.stdin();
//     if (std.posix.isatty(stdin.handle)) {
//         setupTermios(stdin.handle) catch |err| {
//             std.debug.print("Warning: failed to setup terminal: {}\n", .{err});
//         };
//     }
//
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();
//     const alloc = arena.allocator();
//
//     var default_state = try ncontroller.config.defaultState(alloc);
//
//     for (default_state.channels) |ch| {
//         print("ch {d} ", .{ch});
//     }
//     try ncontroller.run(alloc, &default_state);
// }
