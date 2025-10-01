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

    const engine = try water.engine.Engine(search.Search).init(
        allocator,
        .{allocator},
    );
    defer engine.deinit(.{});
}
