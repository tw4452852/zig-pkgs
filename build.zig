const std = @import("std");
const zlib = @import("zlib.zig");
const zstd = @import("zstd.zig");
const libelf = @import("libelf.zig");
const libbpf = @import("libbpf.zig");
const libtraceevent = @import("libtraceevent.zig");

pub const Artifact = enum {
    zlib,
    zstd,
    libelf,
    libbpf,
    libtraceevent,
};

pub fn build(b: *std.Build) error{LazyDependencyNeeded}!void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const artifacts_opt = b.option([]Artifact, "include", "The artifact you want to include, if not specified, include all");

    const artifacts = if (artifacts_opt) |artifacts| artifacts else b: {
        const ti = @typeInfo(Artifact).@"enum";
        var all: [ti.field_names.len]Artifact = undefined;
        for (&all, 0..) |*p, i| {
            p.* = @fromBackingInt(@intCast(i));
        }

        break :b &all;
    };

    var has_lazy = false;
    var built: [@typeInfo(Artifact).@"enum".field_names.len]?error{LazyDependencyNeeded}!*std.Build.Step.Compile = @splat(null);
    for (artifacts) |artifact| {
        if (buildOne(b, artifact, target, optimize, &built)) |_| {} else |e| switch (e) {
            error.LazyDependencyNeeded => has_lazy = true,
        }
    }

    if (has_lazy) return error.LazyDependencyNeeded;
}

fn buildOne(
    b: *std.Build,
    artifact: Artifact,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    built: []?error{LazyDependencyNeeded}!*std.Build.Step.Compile,
) error{LazyDependencyNeeded}!*std.Build.Step.Compile {
    return if (built[@backingInt(artifact)]) |result| result else {
        const result = switch (artifact) {
            .zlib => zlib.build(b, target, optimize),
            .zstd => zstd.build(b, target, optimize),
            .libelf => b: {
                const compile_zlib = buildOne(b, .zlib, target, optimize, built);
                const compile_zstd = buildOne(b, .zstd, target, optimize, built);
                break :b libelf.build(b, target, optimize, compile_zlib, compile_zstd);
            },
            .libbpf => b: {
                const compile_zlib = buildOne(b, .zlib, target, optimize, built);
                const compile_libelf = buildOne(b, .libelf, target, optimize, built);
                break :b libbpf.build(b, target, optimize, compile_zlib, compile_libelf);
            },
            .libtraceevent => libtraceevent.build(b, target, optimize),
        };
        built[@backingInt(artifact)] = result;
        return result;
    };
}
