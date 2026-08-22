const std = @import("std");

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) error{LazyDependencyNeeded}!*std.Build.Step.Compile {
    const pic = b.option(bool, "zlib.pie", "Produce Position Independent Code");
    const upstream = try b.dependencyLazy("zlib_src", .{});
    const lib = b.addLibrary(.{
        .name = "zlib",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .pic = pic,
        }),
    });

    const base_cflags = [_][]const u8{
        "-DHAVE_SYS_TYPES_H",
        "-DHAVE_STDINT_H",
        "-DHAVE_STDDEF_H",
        "-DZ_HAVE_UNISTD_H",
    };
    const cflags_with_pic = base_cflags ++ [_][]const u8{"-fPIC"};
    const cflags = if (pic orelse false) &cflags_with_pic else &base_cflags;

    lib.root_module.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = &.{
            "adler32.c",
            "crc32.c",
            "deflate.c",
            "infback.c",
            "inffast.c",
            "inflate.c",
            "inftrees.c",
            "trees.c",
            "zutil.c",
            "compress.c",
            "uncompr.c",
            "gzclose.c",
            "gzlib.c",
            "gzread.c",
            "gzwrite.c",
        },
        .flags = cflags,
    });
    lib.installHeadersDirectory(upstream.path(""), "", .{
        .include_extensions = &.{
            "zconf.h",
            "zlib.h",
        },
    });
    b.installArtifact(lib);

    return lib;
}
