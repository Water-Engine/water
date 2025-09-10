const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable(.{
        .name = "water",
        .target = target,
        .optimize = .ReleaseFast,
    });

    exe.addIncludePath(.{ .cwd_relative = "include" });
    exe.addIncludePath(.{ .cwd_relative = "vendor" });

    const src_sources = getCCppSources(b.allocator, "src") catch unreachable;
    const include_sources = getCCppSources(b.allocator, "include") catch unreachable;
    const vendor_sources = getCCppSources(b.allocator, "vendor") catch unreachable;
    const all_sources = std.mem.concat(
        b.allocator,
        []const u8,
        &[_][]const []const u8{ src_sources, include_sources, vendor_sources },
    ) catch unreachable;

    exe.addCSourceFiles(.{
        .files = all_sources,
        .flags = &[_][]const u8{
            "-std=c++20",
            "-Wall",
            "-Wextra",
            "-DDIST",
            "-include",
            "include/pch.hpp",
        },
    });

    exe.linkLibC();
    exe.linkLibCpp();

    b.installArtifact(exe);
}

fn getCCppSources(allocator: std.mem.Allocator, directory: []const u8) ![]const []const u8 {
    const cwd = std.fs.cwd();
    var dir = try cwd.openDir(directory, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var paths = std.ArrayList([]const u8).init(allocator);

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".cpp") and !std.mem.endsWith(u8, entry.basename, ".c")) continue;

        const full_path = try std.fs.path.join(allocator, &.{ directory, entry.path });
        try paths.append(full_path);
    }

    return paths.items;
}
