const std = @import("std");

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) error{LazyDependencyNeeded}!*std.Build.Step.Compile {
    const dtc = try b.dependencyLazy("dtc_src", .{});
    const is_freestanding = target.result.os.tag == .freestanding;

    const lib = b.addLibrary(.{
        .name = "libfdt",
        .root_module = b.createModule(.{
            .root_source_file = b.path("libfdt/helpers.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = if (is_freestanding) false else true,
        }),
        .linkage = .static,
    });
    lib.root_module.addCSourceFiles(.{
        .root = .{ .dependency = .{
            .dependency = dtc,
            .sub_path = "libfdt",
        } },
        .files = &.{
            "fdt.c",
            "fdt_ro.c",
            "fdt_wip.c",
            "fdt_sw.c",
            "fdt_rw.c",
            "fdt_strerror.c",
            "fdt_empty_tree.c",
            "fdt_addresses.c",
            "fdt_overlay.c",
            "fdt_check.c",
        },
    });
    lib.root_module.addIncludePath(.{ .dependency = .{
        .dependency = dtc,
        .sub_path = "libfdt",
    } });

    lib.installHeadersDirectory(dtc.path("libfdt"), "", .{
        .include_extensions = &.{
            "libfdt.h",
            "fdt.h",
            "libfdt_env.h",
        },
    });
    if (is_freestanding) {
        lib.root_module.addIncludePath(b.path("libfdt"));
    }

    b.installArtifact(lib);

    // testing
    const write_file_step = b.addWriteFiles();
    const c_file = write_file_step.add("main.c",
        \\#include <libfdt.h>
        \\__attribute__((weak)) int _start(void) { char buf[64]; fdt_path_offset(&buf, "/memory"); return 0; }
        \\int main(void) { char buf[64]; fdt_path_offset(&buf, "/memory"); return 0; }
    );
    const exe_root_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    exe_root_module.addCSourceFile(.{ .file = c_file });
    exe_root_module.addIncludePath(dtc.path("libfdt"));
    if (target.result.os.tag == .freestanding) {
        exe_root_module.addIncludePath(b.path("libfdt"));
    }
    exe_root_module.linkLibrary(lib);
    const build_exe = b.addExecutable(.{
        .name = "libfdt_test",
        .root_module = exe_root_module,
    });
    _ = build_exe.getEmittedBin(); // trigger linking
    b.getInstallStep().dependOn(&build_exe.step);

    return lib;
}
