const std = @import("std");
const c = @import("./coremidi.zig").lib;
const Allocator = std.mem.Allocator;

pub fn strToCFString(str: []const u8) c.CFStringRef {
    const x = c.CFStringCreateWithCString(null, str.ptr, c.kCFStringEncodingUTF8);
    return x;
}

pub fn cfStrConvert(alloc: Allocator, str: c.CFStringRef) ![]const u8 {
    const ptr = try alloc.create([256]u8);
    const success = c.CFStringGetCString(
        str,
        ptr,
        ptr.len,
        c.kCFStringEncodingUTF8,
    );

    if (success == 0) {
        return error.ConversionFailed;
    }
    const x: []const u8 = std.mem.sliceTo(ptr, 0);
    return x;
}

pub fn cTry(status: c_int) !void {
    if (status == 0) {
        return {};
    }
    return error.BadStatus;
}
