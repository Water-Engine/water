const std = @import("std");
const builtin = @import("builtin");

pub const ROMMapError = error{
    OpenError,
    GetEndPosError,
    EmptyFile,
};

fn isPosix(target: std.Target) bool {
    return switch (target.os.tag) {
        .linux,
        .macos,
        .freebsd,
        .netbsd,
        .openbsd,
        .dragonfly,
        .haiku,
        .solaris,
        .ios,
        .watchos,
        .tvos,
        => true,
        else => false,
    };
}

const os_type: enum {
    windows,
    posix,
} = blk: {
    if (isPosix(builtin.target)) {
        break :blk .posix;
    } else if (builtin.os.tag == .windows) {
        break :blk .windows;
    } else {
        @compileError("Unsupported OS for ROMMap");
    }
};

/// A cross-platform read-only memory map.
pub const ROMMap = struct {
    bytes: []const u8,
    platform: switch (os_type) {
        .posix => struct {
            file: std.fs.File,
        },
        .windows => struct {
            file: std.fs.File,
            handle: std.os.windows.HANDLE,
        },
    },

    /// Maps an existing file into memory for read-only access.
    ///
    /// The path's default to cwd relative, but can be altered through options
    pub fn map(
        path: []const u8,
        options: struct {
            dir: std.fs.Dir = std.fs.cwd(),
        },
    ) ROMMapError!ROMMap {
        var file = options.dir.openFile(
            path,
            .{ .mode = .read_only },
        ) catch return error.OpenError;
        errdefer file.close();

        const file_size = file.getEndPos() catch return error.GetEndPosError;
        if (file_size == 0) {
            return error.EmptyFile;
        }

        switch (comptime os_type) {
            .posix => {
                const prot: u32 = std.posix.PROT.READ;

                const ptr = try std.posix.mmap(
                    null,
                    file_size,
                    prot,
                    std.posix.system.MAP{},
                    file.handle,
                    0,
                );

                if (ptr == std.posix.MAP_FAILED) {
                    file.close();
                    return error.MapFailed;
                }
            },
            .windows => {},
        }
    }

    /// Unmaps the memory and closes all associated file handles.
    pub fn unmap() void {}
};
