const std = @import("std");
const water = @import("water");

const pst = @import("pst.zig");
const see = @import("see.zig");

pub const mate_score: i32 = 888888;
pub const max_mate: i32 = 256;

/// Determines if a score is close to the mate score.
pub fn mateish(score: i32) bool {
    return score >= mate_score - max_mate or score <= -mate_score + max_mate;
}

/// Determines the phase of the board. The starting phase is know to be 24.
pub fn phase(board: *const water.Board) i32 {
    var p: i32 = 0;
    p += @intCast(board.pieces(
        .none,
        .knight,
    ).orBB(board.pieces(.none, .bishop)).count());
    p += 2 * @as(i32, @intCast(board.pieces(.none, .rook).count()));
    p += 4 * @as(i32, @intCast(board.pieces(.none, .queen).count()));
    return p;
}

/// Determines the material phase based on the static exchange evaluator biases.
///
/// Pawns and Kings are not considered in the material phase.
pub fn materialPhase(board: *const water.Board) i32 {
    var p: i32 = 0;
    p += see.see_weight[1] * @as(i32, @intCast(board.pieces(.none, .knight).count()));
    p += see.see_weight[2] * @as(i32, @intCast(board.pieces(.none, .bishop).count()));
    p += see.see_weight[3] * @as(i32, @intCast(board.pieces(.none, .rook).count()));
    p += see.see_weight[4] * @as(i32, @intCast(board.pieces(.none, .queen).count()));
    return p;
}

/// Performs a weasily check if the board is a draw.
///
/// Will return true more frequently than water's arbiter.
///
/// Directly from https://github.com/SnowballSH/Avalanche
pub fn drawish(board: *const water.Board) bool {
    const all = board.occ().bits;
    const kings = board.pieces(.none, .king).bits;

    if (kings == all) {
        return true;
    }

    const white_bishops = board.pieces(.white, .bishop).bits;
    const black_bishops = board.pieces(.black, .bishop).bits;
    const white_knights = board.pieces(.white, .knight).bits;
    const black_knights = board.pieces(.black, .knight).bits;

    const white_bishop_count: usize = @popCount(white_bishops);
    const black_bishop_count: usize = @popCount(black_bishops);
    const white_knight_count: usize = @popCount(white_knights);
    const black_knight_count: usize = @popCount(black_knights);

    // KN vs K or KNN vs K
    if (white_knight_count <= 2 and white_knights | kings == all) {
        return true;
    }

    if (black_knight_count <= 2 and black_knights | kings == all) {
        return true;
    }

    // KN vs KN
    if (white_knight_count == 1 and black_knight_count == 1 and white_knights | black_knights | kings == all) {
        return true;
    }

    // KB vs KB
    if (white_bishop_count == 1 and black_bishop_count == 1 and white_bishops | black_bishops | kings == all) {
        return true;
    }

    // KB vs KN
    if (white_bishop_count == 1 and black_knight_count == 1 and white_bishops | black_knights | kings == all) {
        return true;
    }

    if (black_bishop_count == 1 and white_knight_count == 1 and black_bishops | white_knights | kings == all) {
        return true;
    }

    // KNN vs KB
    if (white_knight_count == 2 and black_bishop_count == 1 and white_knights | black_bishops | kings == all) {
        return true;
    }

    if (black_knight_count == 2 and white_bishop_count == 1 and black_knights | white_bishops | kings == all) {
        return true;
    }

    // KBN vs KB
    if (white_bishop_count == 1 and white_knight_count == 1 and black_bishop_count == 1 and white_bishops | white_knights | black_bishops | kings == all) {
        return true;
    }

    if (black_bishop_count == 1 and black_knight_count == 1 and white_bishop_count == 1 and black_bishops | black_knights | white_bishops | kings == all) {
        return true;
    }

    return false;
}

/// Score the position using the manhattan and center manhattan distances.
pub fn distance(board: *const water.Board, comptime white_winning: bool) i32 {
    const white_king = board.kingSq(.white).index();
    const black_king = board.kingSq(.black).index();

    var score: i32 = 0;
    const m_dist = water.manhattan_distance[white_king][black_king];

    if (white_winning) {
        score -= m_dist * 5;
        score += water.center_manhattan_distance[black_king] * 10;
    } else {
        score += m_dist * 5;
        score -= water.center_manhattan_distance[white_king] * 10;
    }

    return score;
}

/// A dynamic evaluator for managing pesto and NNUE evaluations.
///
/// Implementation heavily inspired from https://github.com/SnowballSH/Avalanche
pub const Evaluator = struct {
    pesto: pst.PeSTOEval = .{},
    needs_pesto: bool = false,

    /// Reloads the PeSTO evaluation terms from the board.
    ///
    /// Prefer more incremental updates than direct calls here.
    pub fn refresh(
        self: *Evaluator,
        board: *const water.Board,
        comptime options: enum { nnue, pesto, full },
    ) void {
        if (comptime options != .nnue) {
            self.pesto = pst.pestoEval(board);
        }

        if (comptime options != .pesto) {}
    }

    /// Performs a static evaluation for the stm on the given board.
    pub fn evaluate(self: *Evaluator, board: *const water.Board, comptime use_nnue: bool) i32 {
        const color = board.side_to_move;

        // TODO: If the pesto was turned off last evaluation, reload and re-enable
        // if (!self.needs_pesto) {
        //     self.needs_pesto = true;
        //     self.refresh(board, .pesto);
        // }
        self.refresh(board, .pesto);

        // TODO: Integrate NNUE evaluation
        _ = use_nnue;

        const p = phase(board);
        var result: i32 = 0;

        var mg_phase: i32 = 0;
        var eg_phase: i32 = 0;
        var mg_score: i32 = 0;
        var eg_score: i32 = 0;

        // Taper the eval as a starting position is at phase 24
        mg_phase = p;
        if (mg_phase > 24) {
            mg_phase = 24;
        }
        eg_phase = 24 - mg_phase;

        mg_score = self.pesto.score_mg;
        eg_score = self.pesto.score_eg_mat;

        const half_moves: i32 = if (board.previous_states.getLastOrNull()) |state| blk: {
            break :blk @intCast(state.half_moves);
        } else 0;

        while (true) {
            // Late endgame consideration only
            if (p <= 4 and p >= 1 and board.pieces(.none, .pawn).empty()) {
                // Consider a side winning iff the other side only has a king
                if (board.pieces(.black, .king).eqBB(board.us(.black))) {
                    eg_score += distance(board, true);
                    eg_score += @divTrunc(self.pesto.score_eg_non_mat, 2);
                    eg_score = @max(100, eg_score - half_moves);
                    break;
                } else if (board.pieces(.white, .king).eqBB(board.us(.white))) {
                    eg_score += distance(board, false);
                    eg_score += @divTrunc(self.pesto.score_eg_non_mat, 2);
                    eg_score = @min(-100, eg_score + half_moves);
                    break;
                }
            }

            eg_score += self.pesto.score_eg_non_mat;
            break;
        }

        // Normalize the score with the determined phases
        if (color.isWhite()) {
            result = @divTrunc(mg_score * mg_phase + eg_score * eg_phase, 24);
        } else {
            result = -@divTrunc(mg_score * mg_phase + eg_score * eg_phase, 24);
        }

        if (p <= 5 and @abs(result) >= 16 and drawish(board)) {
            const drawish_heuristic: i32 = 8;
            result = @divTrunc(result, drawish_heuristic);
        }

        // Scale the result
        const material_normalized: i32 = @divTrunc(materialPhase(board), 32);
        result = @divTrunc(result * (700 + material_normalized - half_moves * 5), 1024);

        return result;
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "Board phase calculations" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    try expectEqual(24, phase(board));
    try expectEqual(6688, materialPhase(board));

    try expect(try board.setFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ", true));
    try expectEqual(24, phase(board));
    try expectEqual(6688, materialPhase(board));

    try expect(try board.setFen("8/3r4/pr1Pk1p1/8/7P/6P1/3R3K/5R2 w - - 20 80", true));
    try expectEqual(8, phase(board));
    try expectEqual(2084, materialPhase(board));
}

test "Board distance evaluation" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    try expectEqual(-5, distance(board, true));
    try expectEqual(5, distance(board, false));

    try expect(try board.setFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ", true));
    try expectEqual(-5, distance(board, true));
    try expectEqual(5, distance(board, false));

    try expect(try board.setFen("8/3r4/pr1Pk1p1/8/7P/6P1/3R3K/5R2 w - - 20 80", true));
    try expectEqual(-25, distance(board, true));
    try expectEqual(-15, distance(board, false));
}

test "Board evaluation" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    var eval = Evaluator{};

    try expectEqual(0, eval.evaluate(board, false));
    try expect(try board.setFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1", true));
    eval.refresh(board, .pesto);
    try expectEqual(0, eval.evaluate(board, false));

    try expect(try board.setFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ", true));
    eval.refresh(board, .pesto);
    try expectEqual(49, eval.evaluate(board, false));
    try expect(try board.setFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R b KQkq - ", true));
    eval.refresh(board, .pesto);
    try expectEqual(-49, eval.evaluate(board, false));

    try expect(try board.setFen("8/3r4/pr1Pk1p1/8/7P/6P1/3R3K/5R2 w - - 20 80", true));
    eval.refresh(board, .pesto);
    try expectEqual(100, eval.evaluate(board, false));
    try expect(try board.setFen("8/3r4/pr1Pk1p1/8/7P/6P1/3R3K/5R2 b - - 20 80", true));
    eval.refresh(board, .pesto);
    try expectEqual(-100, eval.evaluate(board, false));
}

test "Weak draw detection" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    // Start position
    try expect(!drawish(board));

    // K vs K
    try expect(try board.setFen("8/8/8/8/8/8/8/K6k w - - 0 1", true));
    try expect(drawish(board));

    // KN vs K
    try expect(try board.setFen("8/8/7k/8/8/8/8/Kn6 w - - 0 1", true));
    try expect(drawish(board));

    // KNN vs K
    try expect(try board.setFen("8/8/7k/8/8/8/8/KNn5 w - - 0 1", true));
    try expect(drawish(board));

    // KN vs KN
    try expect(try board.setFen("8/8/8/8/8/8/8/KNkn4 w - - 0 1", true));
    try expect(drawish(board));

    // KB vs KB
    try expect(try board.setFen("8/8/8/8/8/8/8/KBkb4 w - - 0 1", true));
    try expect(drawish(board));

    // KB vs KN
    try expect(try board.setFen("8/8/8/8/8/8/8/KBkn4 w - - 0 1", true));
    try expect(drawish(board));

    // KN vs KB
    try expect(try board.setFen("8/8/8/8/8/8/8/KNkb4 w - - 0 1", true));
    try expect(drawish(board));

    // KNN vs KB
    try expect(try board.setFen("8/8/8/8/8/8/8/KNNkb3 w - - 0 1", true));
    try expect(drawish(board));

    // KB vs KNN
    try expect(try board.setFen("8/8/8/8/8/8/8/K1Bnnk3 w - - 0 1", true));
    try expect(drawish(board));

    // KBN vs KB
    try expect(try board.setFen("8/8/8/8/8/8/8/KNBkb3 w - - 0 1", true));
    try expect(drawish(board));

    // KB vs KBN
    try expect(try board.setFen("8/8/8/8/8/8/8/KBnkn4 w - - 0 1", true));
    try expect(drawish(board));

    // Not drawish example
    try expect(try board.setFen("8/8/8/8/8/8/8/KBkq4 w - - 0 1", true));
    try expect(!drawish(board));
}
