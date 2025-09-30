const std = @import("std");
const water = @import("water");

const PerftDebugger = struct {
    board: *water.Board,
    file_out: []const u8,
    items: std.ArrayList(u8),
    count: usize = 0,

    pub fn init(board: *water.Board, file_out: []const u8) !PerftDebugger {
        return .{
            .board = board,
            .file_out = file_out,
            .items = try std.ArrayList(u8).initCapacity(board.allocator, 10000),
        };
    }

    pub fn deinit(self: *PerftDebugger) void {
        const stream = self.items.toOwnedSlice(self.board.allocator) catch unreachable;
        var file = std.fs.cwd().createFile(self.file_out, .{}) catch unreachable;
        _ = file.write(stream) catch unreachable;
    }

    pub fn perftDebug(self: *PerftDebugger, depth: usize) usize {
        var moves = water.movegen.Movelist{};
        water.movegen.legalmoves(self.board, &moves, .{});

        if (depth <= 1) {
            for (moves.moves[0..moves.size]) |move| {
                self.items.print(self.board.allocator, "{d}, ", .{move.move}) catch unreachable;
                if ((self.count + 1) % 16 == 0) {
                    self.items.append(self.board.allocator, '\n') catch unreachable;
                }
                self.count += 1;
            }
            return moves.size;
        }

        var nodes: usize = 0;
        for (moves.moves[0..moves.size]) |move| {
            self.items.print(self.board.allocator, "{d}, ", .{move.move}) catch unreachable;
            if ((self.count + 1) % 16 == 0) {
                self.items.append(self.board.allocator, '\n') catch unreachable;
            }
            self.count += 1;

            self.board.makeMove(move, .{});
            nodes += self.perft(depth - 1);
            self.board.unmakeMove(move);
        }

        return nodes;
    }
};

const TestCase = struct {
    fen: []const u8,
    depth: usize,
    expected_nodes: ?usize,
};

pub fn bench(board: *water.Board, test_case: TestCase) !void {
    std.debug.assert(try board.setFen(test_case.fen, true));

    const start = std.time.nanoTimestamp();
    const nodes = board.perft(test_case.depth, .{});
    const end = std.time.nanoTimestamp();

    if (test_case.expected_nodes) |expected| {
        if (nodes != expected) {
            std.debug.print("Perft error!\n\tExpected: {d}\n\tFound: {d}", .{ expected, nodes });
            unreachable;
        }
    }

    const elapsed_float = @as(f128, @floatFromInt(end - start)) / 1_000_000.0;
    const nps_float = (@as(f128, @floatFromInt(nodes)) * 1000.0) / (elapsed_float + 1.0);

    const elapsed: u64 = @intFromFloat(elapsed_float);
    const nps: u64 = @intFromFloat(nps_float);

    var out_buffer = try std.ArrayList(u8).initCapacity(board.allocator, 500);
    defer out_buffer.deinit(board.allocator);

    try out_buffer.print(
        board.allocator,
        "depth {d:<2} time {d:<5} nodes {d:<12} nps {d:<9} fen {s:<87}",
        .{ test_case.depth, elapsed, nodes, nps, test_case.fen },
    );

    std.debug.print("{s}\n", .{out_buffer.items});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var board = try water.Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    // Test a variety of classical positions
    std.debug.print("Classical Positions:\n", .{});
    const classical_positions: [6]TestCase = .{
        .{ .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .depth = 7, .expected_nodes = 3195901860 },
        .{ .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ", .depth = 5, .expected_nodes = 193690690 },
        .{ .fen = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - ", .depth = 7, .expected_nodes = 178633661 },
        .{ .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", .depth = 6, .expected_nodes = 706045033 },
        .{ .fen = "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", .depth = 5, .expected_nodes = 89941194 },
        .{ .fen = "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 1", .depth = 5, .expected_nodes = 164075551 },
    };

    for (classical_positions) |tc| {
        try bench(board, tc);
    }

    // Test a variety of FRC positions
    std.debug.print("\nFRC Positions:\n", .{});
    if (!(board.setFischerRandom(true) catch false)) unreachable;
    const frc_positions: [13]TestCase = .{
        .{ .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w AHah - 0 1", .depth = 6, .expected_nodes = 119060324 },
        .{ .fen = "1rqbkrbn/1ppppp1p/1n6/p1N3p1/8/2P4P/PP1PPPP1/1RQBKRBN w FBfb - 0 9", .depth = 6, .expected_nodes = 191762235 },
        .{ .fen = "rbbqn1kr/pp2p1pp/6n1/2pp1p2/2P4P/P7/BP1PPPP1/R1BQNNKR w HAha - 0 9", .depth = 6, .expected_nodes = 924181432 },
        .{ .fen = "rqbbknr1/1ppp2pp/p5n1/4pp2/P7/1PP5/1Q1PPPPP/R1BBKNRN w GAga - 0 9", .depth = 6, .expected_nodes = 308553169 },
        .{ .fen = "4rrb1/1kp3b1/1p1p4/pP1Pn2p/5p2/1PR2P2/2P1NB1P/2KR1B2 w D - 0 21", .depth = 6, .expected_nodes = 872323796 },
        .{ .fen = "1rkr3b/1ppn3p/3pB1n1/6q1/R2P4/4N1P1/1P5P/2KRQ1B1 b Dbd - 0 14", .depth = 6, .expected_nodes = 2678022813 },
        .{ .fen = "qbbnrkr1/p1pppppp/1p4n1/8/2P5/6N1/PPNPPPPP/1BRKBRQ1 b FCge - 1 3", .depth = 6, .expected_nodes = 521301336 },
        .{ .fen = "rr6/2kpp3/1ppn2p1/p2b1q1p/P4P1P/1PNN2P1/2PP4/1K2R2R b E - 1 20", .depth = 2, .expected_nodes = 1438 },
        .{ .fen = "rr6/2kpp3/1ppn2p1/p2b1q1p/P4P1P/1PNN2P1/2PP4/1K2RR2 w E - 0 20", .depth = 3, .expected_nodes = 37340 },
        .{ .fen = "rr6/2kpp3/1ppnb1p1/p2Q1q1p/P4P1P/1PNN2P1/2PP4/1K2RR2 b E - 2 19", .depth = 4, .expected_nodes = 2237725 },
        .{ .fen = "rr6/2kpp3/1ppnb1p1/p4q1p/P4P1P/1PNN2P1/2PP2Q1/1K2RR2 w E - 1 19", .depth = 4, .expected_nodes = 2098209 },
        .{ .fen = "rr6/2kpp3/1ppnb1p1/p4q1p/P4P1P/1PNN2P1/2PP2Q1/1K2RR2 w E - 1 19", .depth = 5, .expected_nodes = 79014522 },
        .{ .fen = "rr6/2kpp3/1ppnb1p1/p4q1p/P4P1P/1PNN2P1/2PP2Q1/1K2RR2 w E - 1 19", .depth = 6, .expected_nodes = 2998685421 },
    };

    for (frc_positions) |tc| {
        try bench(board, tc);
    }
}
