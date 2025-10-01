const std = @import("std");
const water = @import("water");

const search = @import("water/search.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var board = try water.Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const engine = try water.engine.Engine(search.Search).init(
        allocator,
        stdout,
        .{ allocator, stdout },
    );

    // The writer must flush after engine deinitializes to prevent a concurrency issue
    defer {
        engine.deinit(.{});
        stdout.flush() catch unreachable;
    }

    engine.search(.{}, .{});
}
