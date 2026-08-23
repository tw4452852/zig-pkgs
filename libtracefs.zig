const std = @import("std");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, libtraceevent_lazy: error{LazyDependencyNeeded}!*std.Build.Step.Compile) error{LazyDependencyNeeded}!*std.Build.Step.Compile {
    const upstream = b.dependency("libtracefs_src", .{});
    const libtraceevent = try libtraceevent_lazy;

    const lib = b.addLibrary(.{
        .name = "libtracefs",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });

    const cflags = [_][]const u8{
        "-D_GNU_SOURCE",
    };
    lib.root_module.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = &.{
            "src/tracefs-utils.c",
            "src/tracefs-instance.c",
            "src/tracefs-events.c",
            "src/tracefs-tools.c",
            "src/tracefs-marker.c",
            "src/tracefs-kprobes.c",
            "src/tracefs-hist.c",
            "src/tracefs-stats.c",
            "src/tracefs-filter.c",
            "src/tracefs-dynevents.c",
            "src/tracefs-eprobes.c",
            "src/tracefs-uprobes.c",
            "src/tracefs-record.c",
            "src/tracefs-mmap.c",
            "src/tracefs-vsock.c",
            "src/tracefs-perf.c",
            "src/sqlhist-lex.c",
            "src/sqlhist.tab.c",
            "src/tracefs-sqlhist.c",
        },
        .flags = &cflags,
    });
    lib.root_module.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "include",
    } });
    lib.root_module.linkLibrary(libtraceevent);

    lib.installHeadersDirectory(upstream.path("include"), "", .{
        .include_extensions = &.{
            "tracefs.h",
        },
    });

    b.installArtifact(lib);

    return lib;
}
