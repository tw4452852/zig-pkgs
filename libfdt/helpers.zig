const std = @import("std");

comptime {
    @export(&strrchr, .{ .name = "strrchr", .linkage = .weak, .visibility = .default });
    @export(&strnlen, .{ .name = "strnlen", .linkage = .weak, .visibility = .default });
    @export(&memchr, .{ .name = "memchr", .linkage = .weak, .visibility = .default });
}

fn strlen(s: [*c]const u8) callconv(.c) usize {
    return std.mem.len(s);
}

fn strrchr(s: [*c]const u8, target: u8) callconv(.c) [*c]const u8 {
    const slice = std.mem.sliceTo(s, 0);
    return if (std.mem.lastIndexOfScalar(u8, slice, target)) |pos| s + pos else null;
}

fn strnlen(s: [*c]const u8, n: usize) callconv(.c) usize {
    return @min(strlen(s), n);
}

fn memchr(s: [*c]u8, c: u8, n: c_ulong) callconv(.c) [*c]u8 {
    return if (std.mem.indexOfScalar(u8, s[0..n], c)) |pos| s + pos else null;
}
