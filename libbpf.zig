const std = @import("std");

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    deps: struct {
        zlib_lazy: error{LazyDependencyNeeded}!*std.Build.Step.Compile,
        libelf_lazy: error{LazyDependencyNeeded}!*std.Build.Step.Compile,
    },
) error{LazyDependencyNeeded}!*std.Build.Step.Compile {
    const upstream = try b.dependencyLazy("libbpf_src", .{});
    const zlib = try deps.zlib_lazy;
    const libelf = try deps.libelf_lazy;

    const libbpf = b.addLibrary(.{
        .name = "bpf",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .sanitize_c = .off, // offsetofend macro in libbpf will trigger ubsan...
        }),
        .linkage = .static,
    });

    const cflags = [_][]const u8{
        "-D_LARGEFILE64_SOURCE",
        "-D_FILE_OFFSET_BITS=64",
    };
    libbpf.root_module.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = &.{
            "src/bpf.c",
            "src/btf.c",
            "src/libbpf.c",
            "src/netlink.c",
            "src/nlattr.c",
            "src/libbpf_probes.c",
            "src/libbpf_utils.c",
            "src/bpf_prog_linfo.c",
            "src/btf_dump.c",
            "src/hashmap.c",
            "src/ringbuf.c",
            "src/strset.c",
            "src/linker.c",
            "src/gen_loader.c",
            "src/relo_core.c",
            "src/usdt.c",
            "src/zip.c",
            "src/elf.c",
            "src/features.c",
            "src/btf_iter.c",
            "src/btf_relocate.c",
        },
        .flags = &cflags,
    });
    libbpf.root_module.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "include",
    } });
    libbpf.root_module.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "include/uapi",
    } });
    libbpf.root_module.addIncludePath(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "src",
    } });
    libbpf.root_module.linkLibrary(zlib);
    libbpf.root_module.linkLibrary(libelf);

    libbpf.installHeadersDirectory(upstream.path("src"), "bpf", .{
        .include_extensions = &.{
            ".h",
        },
    });
    libbpf.installHeadersDirectory(upstream.path("include/uapi/linux"), "linux", .{
        .include_extensions = &.{
            "bpf.h",
            "bpf_common.h",
            "btf.h",
        },
    });
    b.installArtifact(libbpf);

    // testing
    const write_file_step = b.addWriteFiles();
    const c_file = write_file_step.add("main.c",
        \\#include <libbpf.h>
        \\int main(void) { libbpf_version_string(); return 0; }
    );
    const exe_root_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    exe_root_module.addCSourceFile(.{ .file = c_file });
    exe_root_module.addIncludePath(upstream.path("src"));
    exe_root_module.linkLibrary(libbpf);
    const build_exe = b.addExecutable(.{
        .name = "libbpf_test",
        .root_module = exe_root_module,
    });
    _ = build_exe.getEmittedBin(); // trigger linking
    b.getInstallStep().dependOn(&build_exe.step);

    return libbpf;
}
