const std = @import("std");
const water = @import("water");

const tt = @import("engine/evaluation/tt.zig");
const search = @import("engine/search/searcher.zig");
const commands = @import("engine/commands.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    search.reloadQLMR();
    tt.global_tt = try tt.TranspositionTable.init(allocator, null);

    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const engine = try water.engine.Engine(search.Searcher).init(
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
        .{
            .go_command = commands.GoCommand,
            .opt_command = commands.OptCommand,
            .uci_command = commands.UciCommand,
            .other_commands = &.{
                commands.NewGameCommand,
                commands.DebugCommand,
            },
        },
    );
}

test {
    _ = @import("engine/commands.zig");
    _ = @import("engine/parameters.zig");

    _ = @import("engine/search/searcher.zig");
    _ = @import("engine/search/search.zig");

    _ = @import("engine/evaluation/evaluator.zig");
    _ = @import("engine/evaluation/orderer.zig");
    _ = @import("engine/evaluation/pesto.zig");
    _ = @import("engine/evaluation/see.zig");
    _ = @import("engine/evaluation/tt.zig");

    _ = @import("engine/evaluation//nnue/network.zig");
}
