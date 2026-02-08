const std = @import("std");
const print = std.debug.print;
const ncontroller = @import("ncontroller");
const cli = @import("cli");
const posix = std.posix;

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

    const mode = try cli.chooseMode(alloc);
    switch (mode) {
        .config => {},
        .run => try ncontroller.run(alloc),
        .testing => {},
    }
}
