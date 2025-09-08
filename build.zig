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

    exe.addCSourceFiles(.{
        .files = getCppSources(b.allocator, "src") catch unreachable,
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

fn getCppSources(allocator: std.mem.Allocator, directory: []const u8) ![]const []const u8 {
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
