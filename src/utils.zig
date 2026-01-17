const std = @import("std");
const midi = @import("./coremidi.zig").lib;
const Allocator = std.mem.Allocator;

fn strToCFString(str: []const u8) midi.CFStringRef {
    const x = midi.CFStringCreateWithCString(null, str.ptr, midi.kCFStringEncodingUTF8);
    return x;
}

fn cfStrConvert(alloc: Allocator, str: midi.CFStringRef) ![]const u8 {
    const ptr = try alloc.create([256]u8);
    const success = midi.CFStringGetCString(
        str,
        ptr,
        ptr.len,
        midi.kCFStringEncodingUTF8,
    );

    if (success == 0) {
        return error.ConversionFailed;
    }
    const x: []const u8 = std.mem.sliceTo(ptr, 0);
    return x;
}

fn cTry(status: c_int) !void {
    if (status == 0) {
        return {};
    }
    return error.BadStatus;
}
