const std = @import("std");
const water = @import("water");

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
const winning_capture_bonus: i32 = 1_000_000;
const losing_capture_bonus: i32 = 0;
const quiet_bonus: i32 = 0;
const queen_promotion_bonus: i32 = 1_000_000;
const knight_promotion_bonus: i32 = 650_000;

/// Order moves heuristically.
///
/// The search board is used for state information.
///
/// The Movelist is updated in-place and is sorted in descending order based on score.
pub fn orderMoves(
    board: *const water.Board,
    movelist: *water.movegen.Movelist,
    hash_move: ?water.Move,
) void {
    for (movelist.moves[0..movelist.size]) |*move| {
        var score: i32 = 0;

        // Award a promotion bonus for queens and rooks only (discourage less mobility)
        if (move.typeOf(water.MoveType) == .promotion) {
            if (move.promotionType() == .queen) {
                score += queen_promotion_bonus;
            } else if (move.promotionType() == .knight) {
                score += knight_promotion_bonus;
            }
        }

        if (hash_move != null and move.orderByMove(hash_move.?) == .eq) {
            score += hash_bonus;
        } else if (board.isCapture(move.*)) {
            if (board.at(water.Piece, move.to()) == .none) {
                score += winning_capture_bonus + mvvlva[0][0];
            } else {
                const from_pt_idx = board.at(water.PieceType, move.to()).index();
                std.debug.assert(from_pt_idx < mvvlva.len);
                const to_pt_idx = board.at(water.PieceType, move.from()).index();
                std.debug.assert(to_pt_idx < mvvlva[from_pt_idx].len);
                score += mvvlva[to_pt_idx][from_pt_idx];

                const see_relevant = see.seeThreshold(board, move.*, -90);
                score += if (see_relevant) winning_capture_bonus else losing_capture_bonus;
            }
        } else {
            score += quiet_bonus;
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

test "Basic move ordering" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{
        .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ",
    });
    defer board.deinit();

    var movelist = water.movegen.Movelist{};
    water.movegen.legalmoves(board, &movelist, .{});

    // Order the moves and verify that the scores are sorted in descending order
    orderMoves(board, &movelist, null);
    for (0..movelist.size - 1) |i| {
        const lhs = movelist.moves[i];
        const rhs = movelist.moves[i + 1];
        try expect(lhs.score >= rhs.score);
    }
}
