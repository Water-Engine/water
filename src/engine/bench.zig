const std = @import("std");
const water = @import("water");

const searcher_ = @import("search/searcher.zig");
const tt = @import("evaluation/tt.zig");
const parameters = @import("parameters.zig");

const TestCase = struct {
    fen: []const u8,
    depth: usize,
};

const RunResult = struct {
    elapsed_ms: u64,
    nodes: usize,
};

fn benchmark(board: *water.Board, test_cases: []const TestCase, writer: *std.Io.Writer) !void {
    const num_runs = 5;

    var garbage_buffer: [1024]u8 = undefined;
    var garbage = std.Io.Writer.Discarding.init(&garbage_buffer);
    const garbage_writer = &garbage.writer;

    for (test_cases) |tc| {
        _ = try board.setFen(tc.fen, true);
        var searcher = try searcher_.Searcher.init(board.allocator, board, garbage_writer);
        defer searcher.deinit();

        var results: [num_runs]RunResult = undefined;
        for (0..num_runs) |i| {
            tt.global_tt.clear();
            const start = std.time.milliTimestamp();
            try searcher.search(null, tc.depth);
            const end = std.time.milliTimestamp();

            results[i] = .{
                .elapsed_ms = @intCast(end - start),
                .nodes = searcher.nodes,
            };
        }

        var total_nodes: usize = 0;
        var min_nodes: usize = std.math.maxInt(usize);
        var max_nodes: usize = 0;

        var total_ms: u64 = 0;
        var min_ms: u64 = std.math.maxInt(u64);
        var max_ms: u64 = 0;

        for (results) |r| {
            total_ms += r.elapsed_ms;
            min_ms = @min(min_ms, r.elapsed_ms);
            max_ms = @max(max_ms, r.elapsed_ms);

            total_nodes += r.nodes;
            min_nodes = @min(min_nodes, r.nodes);
            max_nodes = @max(max_nodes, r.nodes);
        }

        const avg_ms: f64 = @as(f64, @floatFromInt(total_ms)) / @as(f64, @floatFromInt(num_runs));
        const avg_nodes: f64 = @as(f64, @floatFromInt(total_nodes)) / @as(f64, @floatFromInt(num_runs));
        const avg_nps: f64 = blk: {
            if (avg_ms == 0) {
                break :blk 0;
            } else {
                break :blk (avg_nodes * @as(f64, @floatFromInt(std.time.ms_per_s))) / avg_ms;
            }
        };

        try writer.print(
            "depth {d:<2} avg nodes {d:<12} (min: {d:>8}, max: {d:>8}) | avg time: {d:>5.1}ms (min: {d:>4}, max: {d:>4}) | avg nps: {d:>9.0} | fen: {s}\n",
            .{ tc.depth, avg_nodes, min_nodes, max_nodes, avg_ms, min_ms, max_ms, avg_nps, tc.fen },
        );
        try writer.flush();
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    searcher_.reloadQLMR();
    tt.global_tt = try .init(allocator, null);
    defer tt.global_tt.deinit();

    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    errdefer stdout.flush() catch {};

    // Test a variety of classical positions
    std.debug.print("Benchmarking Classical Positions:\n", .{});
    const classical_positions: []const TestCase = &.{
        .{ .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .depth = 7 },
        .{ .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ", .depth = 5 },
        .{ .fen = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - ", .depth = 7 },
        .{ .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", .depth = 4 },
        .{ .fen = "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", .depth = 5 },
        .{ .fen = "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 1", .depth = 5 },
    };

    try benchmark(board, classical_positions, stdout);

    // Test a variety of FRC positions
    std.debug.print("\nBenchmarking FRC Positions:\n", .{});
    std.debug.assert(try board.setFischerRandom(true));
    const frc_positions: []const TestCase = &.{
        .{ .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w AHah - 0 1", .depth = 6 },
        .{ .fen = "1rqbkrbn/1ppppp1p/1n6/p1N3p1/8/2P4P/PP1PPPP1/1RQBKRBN w FBfb - 0 9", .depth = 6 },
        .{ .fen = "rbbqn1kr/pp2p1pp/6n1/2pp1p2/2P4P/P7/BP1PPPP1/R1BQNNKR w HAha - 0 9", .depth = 6 },
        .{ .fen = "rqbbknr1/1ppp2pp/p5n1/4pp2/P7/1PP5/1Q1PPPPP/R1BBKNRN w GAga - 0 9", .depth = 6 },
        .{ .fen = "4rrb1/1kp3b1/1p1p4/pP1Pn2p/5p2/1PR2P2/2P1NB1P/2KR1B2 w D - 0 21", .depth = 6 },
        .{ .fen = "1rkr3b/1ppn3p/3pB1n1/6q1/R2P4/4N1P1/1P5P/2KRQ1B1 b Dbd - 0 14", .depth = 6 },
        .{ .fen = "qbbnrkr1/p1pppppp/1p4n1/8/2P5/6N1/PPNPPPPP/1BRKBRQ1 b FCge - 1 3", .depth = 6 },
        .{ .fen = "rr6/2kpp3/1ppnb1p1/p2Q1q1p/P4P1P/1PNN2P1/2PP4/1K2RR2 b E - 2 19", .depth = 4 },
        .{ .fen = "rr6/2kpp3/1ppnb1p1/p4q1p/P4P1P/1PNN2P1/2PP2Q1/1K2RR2 w E - 1 19", .depth = 4 },
        .{ .fen = "rr6/2kpp3/1ppnb1p1/p4q1p/P4P1P/1PNN2P1/2PP2Q1/1K2RR2 w E - 1 19", .depth = 5 },
        .{ .fen = "rr6/2kpp3/1ppnb1p1/p4q1p/P4P1P/1PNN2P1/2PP2Q1/1K2RR2 w E - 1 19", .depth = 6 },
    };

    try benchmark(board, frc_positions, stdout);

    try stdout.flush();
}
