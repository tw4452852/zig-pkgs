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

    // testing
    const write_file_step = b.addWriteFiles();
    const c_file = write_file_step.add("main.c",
        \\#include <trace-seq.h>
        \\int main(void) { struct trace_seq s; trace_seq_init(&s); return 0; }
    );
    const exe_root_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    exe_root_module.addCSourceFile(.{ .file = c_file });
    exe_root_module.addIncludePath(upstream.path("include/traceevent"));
    exe_root_module.linkLibrary(lib);
    const build_exe = b.addExecutable(.{
        .name = "libtraceevent_test",
        .root_module = exe_root_module,
    });
    _ = build_exe.getEmittedBin(); // trigger linking
    b.getInstallStep().dependOn(&build_exe.step);

    return lib;
}
