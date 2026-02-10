const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const posix = std.posix;

const ncontroller = @import("ncontroller");

fn setupTermios(handle: posix.fd_t) !void {
    var settings = try posix.tcgetattr(handle);
    settings.lflag.ICANON = false;
    settings.lflag.ECHO = false;
    _ = try posix.tcsetattr(handle, posix.TCSA.NOW, settings);
}

pub fn main() !void {
    const stdin = std.fs.File.stdin();
    try setupTermios(stdin.handle);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    try ncontroller.run(alloc);
}
