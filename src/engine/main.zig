const std = @import("std");
const builtin = @import("builtin");
const water = @import("water");

const tt = @import("evaluation/tt.zig");
const search = @import("search/searcher.zig");
const commands = @import("commands.zig");

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
        stdout.flush() catch {};
    }

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    try engine.launch(stdin, .{
        .go_command = commands.GoCommand,
        .opt_command = commands.OptCommand,
        .uci_command = commands.UciCommand,
        .other_commands = &.{
            commands.NewGameCommand,
            commands.DebugCommand,
            commands.EvalCommand,
        },
    }, .{
        .windows_pread_workaround = builtin.os.tag == .windows,
    });
}

test {
    _ = @import("commands.zig");
    _ = @import("parameters.zig");

    _ = @import("search/searcher.zig");
    _ = @import("search/algorithm.zig");

    _ = @import("evaluation/evaluator.zig");
    _ = @import("evaluation/orderer.zig");
    _ = @import("evaluation/pesto.zig");
    _ = @import("evaluation/see.zig");
    _ = @import("evaluation/tt.zig");
    _ = @import("evaluation/nnue.zig");
}
