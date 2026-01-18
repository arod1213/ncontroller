const std = @import("std");
const ncontroller = @import("ncontroller");
const posix = std.posix;
const keys = @import("keys");

fn setupTermios(handle: posix.fd_t) !void {
    var settings = try posix.tcgetattr(handle);
    settings.lflag.ICANON = false;
    settings.lflag.ECHO = false;
    _ = try posix.tcsetattr(handle, posix.TCSA.NOW, settings);
}

pub fn main() !void {
    const stdin = std.fs.File.stdin();
    try setupTermios(stdin.handle);
    try keys.monitor();
    //
    // var state = ncontroller.State.init(64, 16);
    //
    // var buff: [1]u8 = undefined;
    // var reader = stdin.reader(&buff);
    // try ncontroller.run(&reader.interface, &state);
}
