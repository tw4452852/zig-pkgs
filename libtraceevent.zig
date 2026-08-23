const std = @import("std");

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) error{LazyDependencyNeeded}!*std.Build.Step.Compile {
    const upstream = b.dependency("libtraceevent_src", .{});

    const lib = b.addLibrary(.{
        .name = "libtraceevent",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const cflags = [_][]const u8{
        "-D_GNU_SOURCE",
    };
    lib.root_module.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = &.{
            "src/event-parse-api.c",
            "src/event-parse.c",
            "src/event-plugin.c",
            "src/kbuffer-parse.c",
            "src/parse-filter.c",
            "src/parse-utils.c",
            "src/tep_strerror.c",
            "src/trace-seq.c",
            "src/trace-btf.c",
        },
        .flags = &cflags,
    });
    lib.root_module.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "include",
    } });
    lib.root_module.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "include/traceevent",
    } });

    lib.installHeadersDirectory(upstream.path("include/traceevent"), "", .{});

    b.installArtifact(lib);

    return lib;
}
