const std = @import("std");
const water = @import("water");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var board = try water.Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    const d = try water.uci.uciBoardDiagram(board, .{});
    defer allocator.free(d);

    std.debug.print("{s}", .{d});
}
