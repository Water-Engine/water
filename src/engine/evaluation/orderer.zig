const std = @import("std");
const water = @import("water");

const searcher_ = @import("../search/searcher.zig");
const see = @import("see.zig");

const mvvlva: [6][6]i32 = .{
    .{ 205, 204, 203, 202, 201, 200 },
    .{ 305, 304, 303, 302, 301, 300 },
    .{ 405, 404, 403, 402, 401, 400 },
    .{ 505, 504, 503, 502, 501, 500 },
    .{ 605, 604, 603, 602, 601, 600 },
    .{ 705, 704, 703, 702, 701, 700 },
};

pub const hash_bonus: i32 = 6_000_000;
pub const winning_capture_bonus: i32 = 1_000_000;
pub const losing_capture_bonus: i32 = 0;
pub const quiet_bonus: i32 = 0;
pub const killer_one_bonus: i32 = 900_000;
pub const killer_two_bonus: i32 = 800_000;
pub const counter_move_bonus: i32 = 600_000;
pub const queen_promotion_bonus: i32 = 1_000_000;
pub const knight_promotion_bonus: i32 = 650_000;

/// Order moves heuristically.
///
/// The search board is used for state information.
///
/// The Movelist is updated in-place and is sorted in descending order based on score.
///
/// Heavily inspired by https://github.com/SnowballSH/Avalanche
pub fn orderMoves(
    searcher: *const searcher_.Searcher,
    movelist: *water.movegen.Movelist,
    hash_move: ?water.Move,
    comptime is_null: bool,
) void {
    for (movelist.moves[0..movelist.size]) |*move| {
        const board = searcher.search_board;
        var score: i32 = 0;

        // Award a promotion bonus for queens and rooks only (discourage less mobility)
        if (move.typeOf(water.MoveType) == .promotion) {
            if (move.promotionType() == .queen) {
                score += queen_promotion_bonus;
            } else if (move.promotionType() == .knight) {
                score += knight_promotion_bonus;
            }
        }

        if (hash_move != null and move.order(hash_move.?, .mv) == .eq) {
            score += hash_bonus;
        } else if (board.isCapture(move.*)) {
            if (board.at(water.Piece, move.to()) == .none) {
                score += winning_capture_bonus + mvvlva[0][0];
            } else {
                const from_pt_idx = board.at(water.PieceType, move.from()).index();
                std.debug.assert(from_pt_idx < mvvlva.len);
                const to_pt_idx = board.at(water.PieceType, move.to()).index();
                std.debug.assert(to_pt_idx < mvvlva[from_pt_idx].len);
                score += mvvlva[to_pt_idx][from_pt_idx];

                const see_relevant: i32 = @intFromBool(see.seeThreshold(board, move.*, -90));
                score += see_relevant * winning_capture_bonus + (1 - see_relevant) * losing_capture_bonus;
            }
        } else {
            var last = if (searcher.ply > 0) searcher.history.moves[searcher.ply - 1] else water.Move.init();
            std.debug.assert(blk: {
                if (searcher.ply == 0) {
                    break :blk true;
                }
                break :blk last.from().valid() and last.to().valid();
            });
            if (searcher.killers[searcher.ply][0].order(move.*, .mv) == .eq) {
                score += killer_one_bonus;
            } else if (searcher.killers[searcher.ply][1].order(move.*, .mv) == .eq) {
                score += killer_two_bonus;
            } else if (searcher.ply >= 1 and searcher.counter_moves[
                board.side_to_move.asInt(usize)
            ][last.from().index()][last.to().index()].order(move.*, .mv) == .eq) {
                score += counter_move_bonus;
            } else {
                score += quiet_bonus;
                std.debug.assert(move.valid());

                const stm_idx = board.side_to_move.index();
                const move_from_idx = move.from().index();
                const move_to_idx = move.to().index();

                const heuristic_offset = (stm_idx << 12) | (move_from_idx << 6) | move_to_idx;

                if (heuristic_offset < searcher.history.heuristic.len) {
                    @branchHint(.likely);
                    const heuristic_value = searcher.history.heuristic[heuristic_offset];
                    score += heuristic_value;
                }

                if (comptime !is_null) {
                    if (searcher.ply >= 1) {
                        inline for ([_]usize{ 0, 1, 3 }) |plies_ago| {
                            if (searcher.ply >= plies_ago + 1) {
                                const prev = searcher.history.moves[searcher.ply - plies_ago - 1];
                                const moved_piece = searcher.history.moved_pieces[searcher.ply - plies_ago - 1];

                                const moved_piece_idx = moved_piece.index();
                                const prev_idx = prev.to().index();

                                const continuation_offset = (moved_piece_idx << 18) | (prev_idx << 12) | (move_from_idx << 6) | move_to_idx;

                                if (continuation_offset < searcher.continuation.len) {
                                    @branchHint(.likely);
                                    const continuation_value = searcher.continuation[continuation_offset];
                                    score += @intFromBool(prev.valid()) * continuation_value;
                                }
                            }
                        }
                    }
                }
            }
        }

        move.score = score;
    }

    // Use a greater than function to sort in descending order instead
    const greaterThanFn = struct {
        pub fn greaterThanFn(_: void, lhs: water.Move, rhs: water.Move) bool {
            return lhs.order(rhs, .sc) == .gt;
        }
    }.greaterThanFn;

    std.mem.sort(water.Move, movelist.moves[0..movelist.size], {}, greaterThanFn);
}

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

    const searcher = try searcher_.Searcher.init(allocator, board, writer);
    defer searcher.deinit();

    var movelist = water.movegen.Movelist{};
    water.movegen.legalmoves(searcher.search_board, &movelist, .{});

    // Order the moves and verify that the scores are sorted in descending order
    orderMoves(searcher, &movelist, water.Move.init(), false);
    for (0..movelist.size - 1) |i| {
        const lhs = movelist.moves[i];
        const rhs = movelist.moves[i + 1];
        try expect(lhs.score >= rhs.score);
    }
}
