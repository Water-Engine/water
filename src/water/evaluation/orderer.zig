const std = @import("std");
const water = @import("water");

const search = @import("../search.zig");
const see = @import("see.zig");

const mvvlva: [6][6]i32 = .{
    .{ 205, 204, 203, 202, 201, 200 },
    .{ 305, 304, 303, 302, 301, 300 },
    .{ 405, 404, 403, 402, 401, 400 },
    .{ 505, 504, 503, 502, 501, 500 },
    .{ 605, 604, 603, 602, 601, 600 },
    .{ 705, 704, 703, 702, 701, 700 },
};

const hash_bonus: i32 = 6_000_000;
const winning_capture: i32 = 1_000_000;
const losing_capture: i32 = 0;
const quiet: i32 = 0;
const killer_one: i32 = 900_000;
const killer_two: i32 = 800_000;
const counter_move: i32 = 600_000;
const queen_promotion: i32 = 1_000_000;
const knight_promotion: i32 = 650_000;

/// Order moves heuristically.
///
/// The search board is used for state information.
///
/// The Movelist is updated in-place and is sorted in descending order based on score.
pub fn orderMoves(
    searcher: *const search.Search,
    movelist: *water.movegen.Movelist,
    hash_move: water.Move,
) void {
    for (movelist.moves[0..movelist.size]) |*move| {
        const board = searcher.search_board;
        var score: i32 = 0;

        // Award a promotion bonus for queens and rooks only (discourage less mobility)
        if (move.typeOf(water.MoveType) == .promotion) {
            if (move.promotionType() == .queen) {
                score += queen_promotion;
            } else if (move.promotionType() == .knight) {
                score += knight_promotion;
            }
        }

        if (move.orderByMove(hash_move) == .eq) {
            score += hash_bonus;
        } else if (board.isCapture(move.*)) {
            if (board.at(water.Piece, move.to()) == .none) {
                score += winning_capture + mvvlva[0][0];
            } else {
                const from_pt_idx = board.at(water.PieceType, move.to()).index();
                std.debug.assert(from_pt_idx < mvvlva.len);
                const to_pt_idx = board.at(water.PieceType, move.from()).index();
                std.debug.assert(to_pt_idx < mvvlva[from_pt_idx].len);
                score += mvvlva[to_pt_idx][from_pt_idx];

                const see_relevant = see.seeThreshold(board, move.*, -90);
                score += if (see_relevant) winning_capture else losing_capture;
            }
        } else {
            if (searcher.killers[searcher.ply][0].orderByMove(move.*) == .eq) {
                score += killer_one;
            } else if (searcher.killers[searcher.ply][1].orderByMove(move.*) == .eq) {
                score += killer_two;
            } else {
                const from = move.from();
                std.debug.assert(from.valid());
                const to = move.to();
                std.debug.assert(to.valid());

                score += quiet;
                score += searcher.history[board.side_to_move.index()][from.index()][to.index()];
            }
        }

        move.score = score;
    }

    // Use a greater than function to sort in descending order instead
    const greaterThanFn = struct {
        pub fn greaterThanFn(_: void, lhs: water.Move, rhs: water.Move) bool {
            return lhs.orderByScore(rhs) == .gt;
        }
    }.greaterThanFn;

    std.mem.sort(water.Move, movelist.moves[0..movelist.size], {}, greaterThanFn);
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "Basic unbiased move ordering" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{
        .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ",
    });
    defer board.deinit();

    var buffer: [1024]u8 = undefined;
    var discarding = std.Io.Writer.Discarding.init(&buffer);
    const writer = &discarding.writer;

    const searcher = try search.Search.init(allocator, board, writer);
    defer searcher.deinit();

    var movelist = water.movegen.Movelist{};
    water.movegen.legalmoves(searcher.search_board, &movelist, .{});

    // Order the moves and verify that the scores are sorted in descending order
    orderMoves(searcher, &movelist, water.Move.init());
    for (0..movelist.size - 1) |i| {
        const lhs = movelist.moves[i];
        const rhs = movelist.moves[i + 1];
        try expect(lhs.score >= rhs.score);
    }
}
