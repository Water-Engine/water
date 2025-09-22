const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "water",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.addIncludePath(.{ .cwd_relative = "include" });
    exe.addIncludePath(.{ .cwd_relative = "vendor" });

    const cpp_src_sources = getSources(b.allocator, "src", ".cpp") catch unreachable;
    const cpp_include_sources = getSources(b.allocator, "include", ".cpp") catch unreachable;
    const c_src_sources = getSources(b.allocator, "src", ".c") catch unreachable;
    const c_include_sources = getSources(b.allocator, "include", ".c") catch unreachable;

    const all_cpp_sources = std.mem.concat(
        b.allocator,
        []const u8,
        &[_][]const []const u8{ cpp_src_sources, cpp_include_sources },
    ) catch unreachable;

    const all_c_sources = std.mem.concat(
        b.allocator,
        []const u8,
        &[_][]const []const u8{ c_src_sources, c_include_sources },
    ) catch unreachable;

    exe.root_module.addCSourceFiles(.{
        .files = all_cpp_sources,
        .flags = &[_][]const u8{
            "-std=c++20",
            "-Wall",
            "-Wextra",
            "-DDIST",
            "-include",
            "include/pch.hpp",
        },
        .language = .cpp,
    });

    exe.root_module.addCSourceFiles(.{
        .files = all_c_sources,
        .flags = &[_][]const u8{
            "-std=c11",
            "-Wall",
            "-Wextra",
            "-DDIST",
        },
        .language = .c,
    });

    exe.linkLibC();
    exe.linkLibCpp();

    b.installArtifact(exe);
}

fn getSources(allocator: std.mem.Allocator, directory: []const u8, extension: []const u8) ![]const []const u8 {
    const cwd = std.fs.cwd();
    var dir = try cwd.openDir(directory, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var paths = try std.ArrayList([]const u8).initCapacity(allocator, 10);

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, extension)) continue;

        const full_path = try std.fs.path.join(allocator, &.{ directory, entry.path });
        try paths.append(allocator, full_path);
    }

    return paths.items;
}
