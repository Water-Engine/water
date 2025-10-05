const std = @import("std");
const water = @import("water");

const search = @import("avalanche/search/search.zig");
const commands = @import("avalanche/commands.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const engine = try water.engine.Engine(search.Search).init(
        allocator,
        stdout,
        .{ allocator, board, stdout },
    );
    engine.welcome = "Water by the Water Engine developers (see AUTHORS file)";

    // The writer must flush after engine deinitializes to prevent a concurrency issue
    defer {
        engine.deinit(.{});
        stdout.flush() catch unreachable;
    }

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    try engine.launch(
        stdin,
        .{ .go_command = commands.GoCommand, .opt_command = commands.OptCommand },
    );
}

test {
    _ = @import("avalanche/commands.zig");

    _ = @import("avalanche/search/search.zig");
    _ = @import("avalanche/search/mcts.zig");

    _ = @import("avalanche/evaluation/orderer.zig");
    _ = @import("avalanche/evaluation/see.zig");
    _ = @import("avalanche/evaluation/tt.zig");
}
