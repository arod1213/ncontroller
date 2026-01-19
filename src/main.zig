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
    //
    // var buff: [64]u8 = undefined;
    // var reader = stdin.reader(&buff);

    // const stdout = std.fs.File.stdout();
    // var out_buf: [64]u8 = undefined;
    // var writer = stdout.writer(&out_buf);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // _ = try cli.setup(alloc, &reader.interface, &writer.interface);

    try ncontroller.run(alloc);
    // try keys.monitor();
    //
    //
}
