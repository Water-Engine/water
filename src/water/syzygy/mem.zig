const std = @import("std");
const builtin = @import("builtin");

// Windows shenanigans
const windows = std.os.windows;

extern "kernel32" fn CreateFileMappingA(
    hFile: windows.HANDLE,
    lpFileMappingAttributes: ?*windows.SECURITY_ATTRIBUTES,
    flProtect: windows.DWORD,
    dwMaximumSizeHigh: windows.DWORD,
    dwMaximumSizeLow: windows.DWORD,
    lpNam: ?windows.LPCSTR,
) callconv(.winapi) ?windows.HANDLE;

extern "kernel32" fn MapViewOfFile(
    hFileMappingObject: windows.HANDLE,
    dwDesiredAccess: windows.DWORD,
    dwFileOffsetHigh: windows.DWORD,
    dwFileOffsetLow: windows.DWORD,
    dwNumberOfBytesToMa: windows.SIZE_T,
) callconv(.winapi) ?windows.LPVOID;

extern "kernel32" fn UnmapViewOfFile(
    lpBaseAddress: windows.LPCVOID,
) callconv(.winapi) windows.BOOL;

// Actual implementation below!
pub const ROMMapError = error{
    OpenError,
    FileStatError,
    EmptyFile,
    CouldNotMapFile,
    CouldNotMapRegion,
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
    platform: struct {
        file: std.fs.File,
        handle: switch (os_type) {
            .windows => std.os.windows.HANDLE,
            .posix => void,
        },
    },

    /// Maps an existing file into memory for read-only access.
    ///
    /// The path should be absolute.
    /// The mapped memory can be accessed through the `bytes` field.
    pub fn init(
        absolute_path: []const u8,
        options: struct {
            offset: usize = 0,
        },
    ) ROMMapError!ROMMap {
        var file = std.fs.openFileAbsolute(
            absolute_path,
            .{ .mode = .read_only },
        ) catch return error.OpenError;
        errdefer file.close();

        const file_stat = file.stat() catch return error.FileStatError;
        const file_size = file_stat.size;
        if (file_size == 0) {
            return error.EmptyFile;
        }

        switch (comptime os_type) {
            .windows => {
                const file_mapping = CreateFileMappingA(
                    file.handle,
                    null,
                    windows.PAGE_READONLY,
                    0,
                    0,
                    null,
                ) orelse return error.CouldNotMapFile;

                const file_map_read: windows.DWORD = 4;
                const ptr = MapViewOfFile(
                    file_mapping,
                    file_map_read,
                    0,
                    0,
                    file_size,
                ) orelse return error.CouldNotMapRegion;

                return .{
                    .bytes = @as([*]u8, @ptrCast(ptr))[0..file_size],
                    .platform = .{
                        .file = file,
                        .handle = file_mapping,
                    },
                };
            },
            .posix => {
                const ptr = std.posix.mmap(
                    null,
                    file_size,
                    std.posix.PROT.READ,
                    .{ .TYPE = .SHARED },
                    file.handle,
                    options.offset,
                ) catch return error.CouldNotMapFile;

                return .{
                    .bytes = ptr,
                    .platform = .{
                        .file = file,
                        .handle = {},
                    },
                };
            },
        }
    }

    /// Unmaps and deinitializes the memory and closes all associated file handles.
    pub fn deinit(self: *ROMMap) void {
        defer self.platform.file.close();
        switch (os_type) {
            .windows => {
                _ = UnmapViewOfFile(self.bytes.ptr);
                _ = windows.CloseHandle(self.platform.handle);
            },
            .posix => {
                std.posix.munmap(self.bytes);
            },
        }
    }
};

// ================ TESTING ================
const testing = std.testing;
const expectEqualSlices = testing.expectEqualSlices;
const expectError = testing.expectError;

test "Successful mapping" {
    const allocator = std.testing.allocator;
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const file_name = "test_data.txt";
    const file_content = "Zig is pragmatic.";

    try tmp_dir.dir.writeFile(
        .{ .sub_path = file_name, .data = file_content },
    );

    const full_path = try std.fs.path.join(allocator, &.{file_name});
    defer allocator.free(full_path);
    const absolute = try tmp_dir.dir.realpathAlloc(allocator, full_path);
    defer allocator.free(absolute);

    var mapped_file = try ROMMap.init(absolute, .{});
    defer mapped_file.deinit();

    try expectEqualSlices(u8, file_content, mapped_file.bytes);
}

test "Unsuccessful mapping with an empty file" {
    const allocator = std.testing.allocator;
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const file_name = "empty.txt";
    try tmp_dir.dir.writeFile(
        .{ .sub_path = file_name, .data = "" },
    );
    const full_path = try std.fs.path.join(allocator, &.{file_name});
    defer allocator.free(full_path);
    const absolute = try tmp_dir.dir.realpathAlloc(allocator, full_path);
    defer allocator.free(absolute);

    const err = ROMMap.init(absolute, .{});
    try expectError(error.EmptyFile, err);
}
