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

pub fn bench(board: *water.Board, fen: []const u8, depth: usize, expected_nodes: ?usize) !void {
    std.debug.assert(try board.setFen(fen, true));

    const start = std.time.nanoTimestamp();
    const nodes = board.perft(depth);
    const end = std.time.nanoTimestamp();

    if (expected_nodes) |expected| {
        if (nodes != expected) {
            std.debug.print("Perft error!\n\tExpected: {d}\n\tFound: {d}", .{ expected, nodes });
            unreachable;
        }
    }

    const elapsed = @as(f128, @floatFromInt(end - start)) / 1_000_000.0;
    const nps = (@as(f128, @floatFromInt(nodes)) * 1000.0) / (elapsed + 1.0);

    var out_buffer = try std.ArrayList(u8).initCapacity(board.allocator, 500);
    defer out_buffer.deinit(board.allocator);

    try out_buffer.print(
        board.allocator,
        "depth {d: <2} time {d: <5} nodes {d: <12} nps {d: <9} fen {s: <87}",
        .{ depth, elapsed, nodes, nps, fen },
    );

    std.debug.print("{s}", .{out_buffer.items});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var board = try water.Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    var perft = try PerftDebugger.init(board, "");
    defer perft.deinit();

    try bench(
        board,
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        7,
        null,
    );
}
