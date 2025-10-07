const std = @import("std");
const water = @import("water");

const TestCase = struct {
    fen: []const u8,
    depth: usize,
    expected_nodes: ?usize,
};

const RunResult = struct {
    elapsed_ms: u64,
    nodes: usize,
};

fn perftQuiet(board: *water.Board, test_case: TestCase) !RunResult {
    std.debug.assert(try board.setFen(test_case.fen, true));

    const start = std.time.nanoTimestamp();
    const nodes = board.perft(test_case.depth, .{});
    const end = std.time.nanoTimestamp();

    if (test_case.expected_nodes) |expected| {
        if (nodes != expected) {
            std.log.err("Perft error on FEN \"{s}\"!\n\tExpected: {d}\n\tFound: {d}", .{ test_case.fen, expected, nodes });
            return error.PerftValidationError;
        }
    }

    const elapsed_ns = end - start;
    const elapsed_ms: i128 = @divTrunc(elapsed_ns, 1_000_000);

    return RunResult{
        .elapsed_ms = @intCast(elapsed_ms),
        .nodes = nodes,
    };
}

fn benchmark(board: *water.Board, test_cases: []const TestCase, writer: *std.Io.Writer) !void {
    const num_runs = 5;

    for (test_cases) |tc| {
        var results: [num_runs]RunResult = undefined;
        for (0..num_runs) |i| {
            results[i] = try perftQuiet(board, tc);
        }

        const nodes = results[0].nodes;
        var total_ms: u64 = 0;
        var min_ms: u64 = std.math.maxInt(u64);
        var max_ms: u64 = 0;

        for (results) |r| {
            total_ms += r.elapsed_ms;
            min_ms = @min(min_ms, r.elapsed_ms);
            max_ms = @max(max_ms, r.elapsed_ms);
        }

        const avg_ms: f64 = @as(f64, @floatFromInt(total_ms)) / @as(f64, @floatFromInt(num_runs));
        const avg_nps: f64 = if (avg_ms == 0) 0 else (@as(f64, @floatFromInt(nodes)) * 1000.0) / avg_ms;

        try writer.print(
            "depth {d:<2} nodes {d:<12} | avg time: {d:>5.1}ms (min: {d:>4}, max: {d:>4}) | avg nps: {d:>9.0} | fen: {s}\n",
            .{ tc.depth, nodes, avg_ms, min_ms, max_ms, avg_nps, tc.fen },
        );
        try writer.flush();
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    std.debug.print("Running perft(6) to mitigate cold-start performance hit...\n", .{});
    _ = board.perft(6, .{});
    std.debug.print("Done. Commencing benchmark...\n\n", .{});

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    errdefer stdout.flush() catch {};

    // Test a variety of classical positions
    std.debug.print("Benchmarking Classical Positions:\n", .{});
    const classical_positions: []const TestCase = &.{
        .{ .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .depth = 7, .expected_nodes = 3195901860 },
        .{ .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ", .depth = 5, .expected_nodes = 193690690 },
        .{ .fen = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - ", .depth = 7, .expected_nodes = 178633661 },
        .{ .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", .depth = 6, .expected_nodes = 706045033 },
        .{ .fen = "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", .depth = 5, .expected_nodes = 89941194 },
        .{ .fen = "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 1", .depth = 5, .expected_nodes = 164075551 },
    };

    try benchmark(board, classical_positions, stdout);

    // Test a variety of FRC positions
    std.debug.print("\nBenchmarking FRC Positions:\n", .{});
    std.debug.assert(try board.setFischerRandom(true));
    const frc_positions: []const TestCase = &.{
        .{ .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w AHah - 0 1", .depth = 6, .expected_nodes = 119060324 },
        .{ .fen = "1rqbkrbn/1ppppp1p/1n6/p1N3p1/8/2P4P/PP1PPPP1/1RQBKRBN w FBfb - 0 9", .depth = 6, .expected_nodes = 191762235 },
        .{ .fen = "rbbqn1kr/pp2p1pp/6n1/2pp1p2/2P4P/P7/BP1PPPP1/R1BQNNKR w HAha - 0 9", .depth = 6, .expected_nodes = 924181432 },
        .{ .fen = "rqbbknr1/1ppp2pp/p5n1/4pp2/P7/1PP5/1Q1PPPPP/R1BBKNRN w GAga - 0 9", .depth = 6, .expected_nodes = 308553169 },
        .{ .fen = "4rrb1/1kp3b1/1p1p4/pP1Pn2p/5p2/1PR2P2/2P1NB1P/2KR1B2 w D - 0 21", .depth = 6, .expected_nodes = 872323796 },
        .{ .fen = "1rkr3b/1ppn3p/3pB1n1/6q1/R2P4/4N1P1/1P5P/2KRQ1B1 b Dbd - 0 14", .depth = 6, .expected_nodes = 2678022813 },
        .{ .fen = "qbbnrkr1/p1pppppp/1p4n1/8/2P5/6N1/PPNPPPPP/1BRKBRQ1 b FCge - 1 3", .depth = 6, .expected_nodes = 521301336 },
        .{ .fen = "rr6/2kpp3/1ppnb1p1/p2Q1q1p/P4P1P/1PNN2P1/2PP4/1K2RR2 b E - 2 19", .depth = 4, .expected_nodes = 2237725 },
        .{ .fen = "rr6/2kpp3/1ppnb1p1/p4q1p/P4P1P/1PNN2P1/2PP2Q1/1K2RR2 w E - 1 19", .depth = 4, .expected_nodes = 2098209 },
        .{ .fen = "rr6/2kpp3/1ppnb1p1/p4q1p/P4P1P/1PNN2P1/2PP2Q1/1K2RR2 w E - 1 19", .depth = 5, .expected_nodes = 79014522 },
        .{ .fen = "rr6/2kpp3/1ppnb1p1/p4q1p/P4P1P/1PNN2P1/2PP2Q1/1K2RR2 w E - 1 19", .depth = 6, .expected_nodes = 2998685421 },
    };

    try benchmark(board, frc_positions, stdout);

    try stdout.flush();
}
