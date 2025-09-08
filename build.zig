const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{.preferred_optimize_mode = .ReleaseFast});

    const exe = b.addExecutable(.{
        .name = "water",
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(.{ .cwd_relative = "include" });
    exe.addIncludePath(.{ .cwd_relative = "vendor" });

    exe.addCSourceFiles(.{
        .files = getCppSources(b),
        .flags = &[_][]const u8{
            "-std=c++20",
            "-Wall",
            "-Wextra",
            "-DDIST",
            "-include", "include/pch.hpp",
        },
    });

    exe.linkLibC();
    exe.linkLibCpp();

    b.installArtifact(exe);
}

fn getCppSources(_: *std.Build) []const []const u8 {
    // TODO
}
