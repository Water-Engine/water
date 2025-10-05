const std = @import("std");

const types = @import("../core/types.zig");
const Color = types.Color;

const bitboard = @import("../core/bitboard.zig");
const Bitboard = bitboard.Bitboard;

const board_ = @import("board.zig");
const Board = board_.Board;

const movegen = @import("../movegen/movegen.zig");

const uci = @import("../core/uci.zig");

pub const ResultType = enum {
    win,
    draw,
};

pub const ResultReason = enum {
    checkmate,
    stalemate,
    insufficient_material,
    fifty_move_rule,
    threefold_repetition,
};

pub const Result = struct {
    result: ResultType,
    reason: ResultReason,
    winner: Color = .none,
};

/// Determines the halfmove draw type, or null if the 50 move rule is not met.
///
/// Passing a precomputed movelist will greatly improve performance.
pub fn halfmove(board: *const Board, precomputed_movelist: ?*const movegen.Movelist) ?Result {
    if (board.halfmove_clock < 100) return null;

    // We can return an actual result, determine legal moves available
    var movelist = movegen.Movelist{};
    const moves = if (precomputed_movelist) |pml| pml.* else blk: {
        movegen.legalmoves(board, &movelist, .{});
        break :blk movelist;
    };

    return if (moves.empty() and board.inCheck(.{})) blk: {
        break :blk .{
            .result = .win,
            .reason = .checkmate,
            .winner = board.side_to_move.opposite(),
        };
    } else .{
        .result = .draw,
        .reason = .fifty_move_rule,
    };
}

/// Determines if the board is a draw by insufficient material.
pub fn insufficientMaterial(board: *const Board) bool {
    const count = board.occ().count();
    return if (count < 2 or count > 4) false else blk: {
        switch (count) {
            // Kings only is obviously a draw
            2 => break :blk true,

            // A position with only bishop or only knight is a draw
            3 => {
                const bishop_present = board.pieces(.none, .bishop).nonzero();
                const knight_present = board.pieces(.none, .knight).nonzero();
                if (bishop_present or knight_present) {
                    std.debug.assert(bishop_present != knight_present);
                    break :blk true;
                } else break :blk false;
            },

            // A position with two same colored bishops is a draw
            4 => {
                const white_bishops = board.pieces(.white, .bishop);
                const black_bishops = board.pieces(.black, .bishop);
                const opposite_bishops_present = white_bishops.nonzero() and black_bishops.nonzero();

                // Opposite color bishops on the same color can't mate
                if (opposite_bishops_present and white_bishops.lsb().sameColor(black_bishops.lsb())) {
                    break :blk true;
                }

                // Same color bishops on same color can't mate
                if (white_bishops.count() == 2) {
                    if (white_bishops.lsb().sameColor(white_bishops.msb())) {
                        break :blk true;
                    }
                } else if (black_bishops.count() == 2) {
                    if (black_bishops.lsb().sameColor(black_bishops.msb())) {
                        break :blk true;
                    }
                }

                break :blk false;
            },
            else => unreachable,
        }
    };
}

/// Determines if the game is over, or null if the game is not.
///
/// Passing a precomputed movelist will greatly improve performance.
pub fn gameOver(board: *const Board, precomputed_movelist: ?*const movegen.Movelist) ?Result {
    // check for each draw type
    if (halfmove(board, precomputed_movelist)) |hm_draw| {
        return hm_draw;
    } else if (insufficientMaterial(board)) {
        return .{
            .result = .draw,
            .reason = .insufficient_material,
        };
    } else if (board.isRepetition(2)) {
        return .{
            .result = .draw,
            .reason = .threefold_repetition,
        };
    }

    // Determine if the position is a checkmate or stalemate
    var movelist = movegen.Movelist{};
    const moves = if (precomputed_movelist) |pml| pml.* else blk: {
        movegen.legalmoves(board, &movelist, .{});
        break :blk movelist;
    };

    if (moves.empty()) {
        return if (board.inCheck(.{})) .{
            .result = .win,
            .reason = .checkmate,
            .winner = board.side_to_move.opposite(),
        } else .{
            .result = .draw,
            .reason = .stalemate,
        };
    }

    return null;
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "Halfmove draws" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});
    defer board.deinit();

    // Clock is less than 100 - no draw
    try expect(try board.setFen("k7/8/K7/8/8/8/8/8 w - - 0 1", true));
    board.halfmove_clock = 99;
    try expect(halfmove(board, null) == null);

    // Clock is 100, but moves are available - draw
    try expect(try board.setFen("k7/8/K7/8/8/8/8/8 w - - 0 1", true));
    board.halfmove_clock = 100;
    const result2 = halfmove(board, null).?;
    try expectEqual(result2.result, .draw);
    try expectEqual(result2.reason, .fifty_move_rule);
    try expectEqual(result2.winner, .none);

    // Clock is 100 & stalemate
    try expect(try board.setFen("7k/8/8/8/8/8/5Q2/7K b - - 0 1", true));
    board.halfmove_clock = 100;
    const result3 = halfmove(board, null).?;
    try expectEqual(result3.result, .draw);
    try expectEqual(result3.reason, .fifty_move_rule);
    try expectEqual(result3.winner, .none);

    // Clock is 100 & stalemate from precomputed
    var ml_sm = movegen.Movelist{};
    movegen.legalmoves(board, &ml_sm, .{});
    const result3_pre_ml = halfmove(board, &ml_sm).?;
    try expectEqual(result3_pre_ml.result, .draw);
    try expectEqual(result3_pre_ml.reason, .fifty_move_rule);
    try expectEqual(result3.winner, .none);

    // Clock is 100 & checkmate
    try expect(try board.setFen("r1bqkbnr/pppp1Qpp/2n5/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 3", true));
    board.halfmove_clock = 101;
    const result4 = halfmove(board, null).?;
    try expectEqual(result4.result, .win);
    try expectEqual(result4.reason, .checkmate);
    try expectEqual(result4.winner, .white);

    // Clock is 100 & checkmate from precomputed
    var ml_cm = movegen.Movelist{};
    movegen.legalmoves(board, &ml_cm, .{});
    const result4_pre_ml = halfmove(board, &ml_cm).?;
    try expectEqual(result4_pre_ml.result, .win);
    try expectEqual(result4_pre_ml.reason, .checkmate);
    try expectEqual(result4_pre_ml.winner, .white);
}

test "Insufficient material draws" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});
    defer board.deinit();

    try expect(try board.setFen("8/8/8/3k4/8/4K3/8/8 w - - 0 1", true));
    try expect(insufficientMaterial(board));

    try expect(try board.setFen("8/8/8/3k4/8/4KN2/8/8 w - - 0 1", true));
    try expect(insufficientMaterial(board));

    try expect(try board.setFen("8/8/8/3k4/8/4KB2/8/8 w - - 0 1", true));
    try expect(insufficientMaterial(board));

    try expect(try board.setFen("8/8/8/3k4/8/4KP2/8/8 w - - 0 1", true));
    try expect(!insufficientMaterial(board));

    try expect(try board.setFen("8/b7/8/3k4/8/5K2/8/5B2 w - - 0 1", true));
    try expect(!insufficientMaterial(board));

    try expect(try board.setFen("8/b7/8/3k4/8/4BK2/8/8 w - - 0 1", true));
    try expect(insufficientMaterial(board));

    try expect(try board.setFen("8/8/8/3k4/8/4K3/4BB2/8 w - - 0 1", true));
    try expect(!insufficientMaterial(board));

    try expect(try board.setFen("8/8/8/3k4/8/4K3/3BB3/8 w - - 0 1", true));
    try expect(!insufficientMaterial(board));

    try expect(try board.setFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", true));
    try expect(!insufficientMaterial(board));
}

test "Game over" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});
    defer board.deinit();

    // Starting position
    try expect(try board.setFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", true));
    try expect(gameOver(board, null) == null);

    // Checkmate
    try expect(try board.setFen("r1bqkbnr/pppp1Qpp/2n5/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 3", true));
    const result2 = gameOver(board, null).?;
    try expectEqual(result2.result, .win);
    try expectEqual(result2.reason, .checkmate);
    try expectEqual(result2.winner, .white);

    // Checkmate from pregenerated moves
    var ml_cm = movegen.Movelist{};
    movegen.legalmoves(board, &ml_cm, .{});
    const result2_pre_ml = gameOver(board, &ml_cm).?;
    try expectEqual(result2_pre_ml.result, .win);
    try expectEqual(result2_pre_ml.reason, .checkmate);
    try expectEqual(result2_pre_ml.winner, .white);

    // Stalemate
    try expect(try board.setFen("8/8/8/8/8/7K/5Q2/7k b - - 0 1", true));
    const result3 = gameOver(board, null).?;
    try expectEqual(result3.result, .draw);
    try expectEqual(result3.reason, .stalemate);
    try expectEqual(result3.winner, .none);

    // Stalemate from pregenerated moves
    var ml_sm = movegen.Movelist{};
    movegen.legalmoves(board, &ml_sm, .{});
    const result3_pre_ml = gameOver(board, &ml_sm).?;
    try expectEqual(result3_pre_ml.result, .draw);
    try expectEqual(result3_pre_ml.reason, .stalemate);
    try expectEqual(result3_pre_ml.winner, .none);

    // Insufficient material
    try expect(try board.setFen("8/8/8/3k4/8/4KN2/8/8 w - - 0 1", true));
    const result4 = gameOver(board, null).?;
    try expectEqual(result4.result, .draw);
    try expectEqual(result4.reason, .insufficient_material);
    try expectEqual(result4.winner, .none);

    // Fifty move rule
    try expect(try board.setFen("k7/8/K7/8/8/8/7p/8 w - - 0 1", true));
    board.halfmove_clock = 100;
    const result5 = gameOver(board, null).?;
    try expectEqual(result5.result, .draw);
    try expectEqual(result5.reason, .fifty_move_rule);
    try expectEqual(result5.winner, .none);

    // Fifty move rule from precomputed
    var ml_hm = movegen.Movelist{};
    movegen.legalmoves(board, &ml_hm, .{});
    const result5_pre_ml = gameOver(board, &ml_hm).?;
    try expectEqual(result5_pre_ml.result, .draw);
    try expectEqual(result5_pre_ml.reason, .fifty_move_rule);
    try expectEqual(result5_pre_ml.winner, .none);

    // Threefold repetition
    try expect(try board.setFen("k6K/8/8/8/8/8/7p/8 w - - 0 1", true));

    board.makeMove(uci.uciToMove(board, "h8g8"), .{});
    board.makeMove(uci.uciToMove(board, "a8b8"), .{});
    board.makeMove(uci.uciToMove(board, "g8h8"), .{});
    board.makeMove(uci.uciToMove(board, "b8a8"), .{});
    board.makeMove(uci.uciToMove(board, "h8g8"), .{});
    board.makeMove(uci.uciToMove(board, "a8b8"), .{});
    board.makeMove(uci.uciToMove(board, "g8h8"), .{});
    board.makeMove(uci.uciToMove(board, "b8a8"), .{});

    const result6 = gameOver(board, null).?;
    try expectEqual(result6.result, .draw);
    try expectEqual(result6.reason, .threefold_repetition);
    try expectEqual(result6.winner, .none);
}
