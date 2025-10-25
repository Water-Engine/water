const std = @import("std");
const water = @import("water");

const pesto = @import("pesto.zig");
const see = @import("see.zig");
const nnue = @import("nnue.zig");

const parameters = @import("../parameters.zig");

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

/// Performs a weasel-y check if the board is a draw.
///
/// Will return true more frequently than water's arbiter.
pub fn drawish(board: *const water.Board) bool {
    const all = board.occ().bits;
    const kings = board.pieces(.none, .king).bits;
    const non_kings = all ^ kings;

    // Early exit: if no other pieces, K vs K
    if (non_kings == 0) return true;

    // Extract once - de-abstract from BB for readability
    const wb = board.pieces(.white, .bishop).bits;
    const bb = board.pieces(.black, .bishop).bits;
    const wn = board.pieces(.white, .knight).bits;
    const bn = board.pieces(.black, .knight).bits;

    const wb_c = @popCount(wb);
    const bb_c = @popCount(bb);
    const wn_c = @popCount(wn);
    const bn_c = @popCount(bn);

    const total_minor = wb_c + bb_c + wn_c + bn_c;

    // Quick discard: too much material
    if (total_minor > 3) return false;

    // K + (up to 2 knights)
    if ((wn_c <= 2 and non_kings == wn) or (bn_c <= 2 and non_kings == bn))
        return true;

    // K + (one minor each)
    if ((wn_c == 1 and bn_c == 1 and non_kings == wn | bn) or
        (wb_c == 1 and bb_c == 1 and non_kings == wb | bb) or
        (wb_c == 1 and bn_c == 1 and non_kings == wb | bn) or
        (bb_c == 1 and wn_c == 1 and non_kings == bb | wn))
        return true;

    // KNN vs KB
    if ((wn_c == 2 and bb_c == 1 and non_kings == wn | bb) or
        (bn_c == 2 and wb_c == 1 and non_kings == bn | wb))
        return true;

    // KBN vs KB
    if ((wb_c == 1 and wn_c == 1 and bb_c == 1 and non_kings == wb | wn | bb) or
        (bb_c == 1 and bn_c == 1 and wb_c == 1 and non_kings == bb | bn | wb))
        return true;

    return false;
}

/// Score the position using the manhattan and center manhattan distances.
pub fn distance(board: *const water.Board, comptime white_winning: bool) i32 {
    const white_king = board.kingSq(.white).index();
    const black_king = board.kingSq(.black).index();

    var score: i32 = 0;
    const m_dist = water.distance.manhattan[white_king][black_king];

    if (white_winning) {
        score -= m_dist * 5;
        score += water.distance.center_manhattan[black_king] * 10;
    } else {
        score += m_dist * 5;
        score -= water.distance.center_manhattan[white_king] * 10;
    }

    return score;
}

/// A dynamic evaluator for managing pesto and NNUE evaluations.
pub const Evaluator = struct {
    pesto: pesto.PeSTOEval = .{},
    nnue: nnue.NNUE = .{},

    /// Reloads the PeSTO evaluation terms from the board.
    ///
    /// Prefer more incremental updates than direct calls here.
    pub fn refresh(
        self: *Evaluator,
        board: *const water.Board,
        comptime options: enum { nnue, pesto, full },
    ) void {
        if (comptime options != .nnue) {
            self.pesto.refresh(board);
        }

        if (comptime options != .pesto) {
            self.nnue.refresh(board);
        }
    }

    /// Applies score changes for a piece on a square.
    fn updateScore(
        self: *Evaluator,
        piece: water.Piece,
        square: water.Square,
        comptime delta: enum(i32) { add, sub },
    ) void {
        std.debug.assert(piece.valid() and square.valid());
        const color = piece.color();

        const pt_idx = piece.asType().index();
        const sq_idx = square.index();
        const sq_idx_adj = sq_idx ^ (56 * (1 - color.asInt(usize)));

        // Update the accumulator
        self.nnue.toggle(
            piece,
            sq_idx,
            comptime switch (delta) {
                .add => .on,
                .sub => .off,
            },
        );

        // Update the pesto tables
        const sign = 1 - 2 * color.asInt(i32);
        switch (comptime delta) {
            .add => {
                self.pesto.score_mg += (pesto.material[pt_idx][0] + pesto.pst[pt_idx][0][sq_idx_adj]) * sign;
                self.pesto.score_eg_mat += pesto.material[pt_idx][1] * sign;
                self.pesto.score_eg_non_mat += pesto.pst[pt_idx][1][sq_idx_adj] * sign;
            },
            .sub => {
                self.pesto.score_mg -= (pesto.material[pt_idx][0] + pesto.pst[pt_idx][0][sq_idx_adj]) * sign;
                self.pesto.score_eg_mat -= pesto.material[pt_idx][1] * sign;
                self.pesto.score_eg_non_mat -= pesto.pst[pt_idx][1][sq_idx_adj] * sign;
            },
        }
    }

    /// Incrementally updates the evaluation by making a move.
    ///
    /// Must be called before updating the board.
    pub fn makeMove(
        self: *Evaluator,
        board: *const water.Board,
        move: water.Move,
    ) void {
        const stm = board.side_to_move;
        const from = move.from();
        const to = move.to();
        std.debug.assert(stm.valid() and from.valid() and to.valid());

        const captured_piece = board.at(water.Piece, to);
        const moved_piece = board.at(water.Piece, from);
        std.debug.assert(moved_piece != .none);
        self.updateScore(moved_piece, from, .sub);

        switch (move.typeOf(water.MoveType)) {
            .normal => {
                if (captured_piece != .none) {
                    self.updateScore(
                        captured_piece,
                        to,
                        .sub,
                    );
                }
                self.updateScore(moved_piece, to, .add);
            },
            .promotion => {
                if (captured_piece != .none) {
                    self.updateScore(
                        captured_piece,
                        to,
                        .sub,
                    );
                }

                self.updateScore(
                    water.Piece.make(stm, move.promotionType()),
                    to,
                    .add,
                );
            },
            .en_passant => {
                const captured_sq = board.ep_square.ep();
                std.debug.assert(captured_sq.valid());
                self.updateScore(moved_piece, to, .add);
                self.updateScore(
                    water.Piece.make(stm.opposite(), .pawn),
                    captured_sq,
                    .sub,
                );
            },
            .castling => {
                const side = water.CastlingRights.closestSide(
                    water.Square,
                    to,
                    from,
                    water.Square.order,
                );

                const king_to = water.Square.castlingKingTo(side, stm);
                const rook_from = to;
                const rook_to = water.Square.castlingRookTo(side, stm);
                std.debug.assert(king_to.valid() and rook_from.valid() and rook_to.valid());

                const friendly_king = water.Piece.make(stm, .king);
                const friendly_rook = water.Piece.make(stm, .rook);

                self.updateScore(friendly_king, king_to, .add);
                self.updateScore(friendly_rook, rook_from, .sub);
                self.updateScore(friendly_rook, rook_to, .add);
            },
            .null_move => {},
        }
    }

    /// Incrementally updates the evaluation by unmaking a move.
    ///
    /// Must be called after updating the board.
    pub fn unmakeMove(
        self: *Evaluator,
        board: *const water.Board,
        move: water.Move,
        captured_piece: water.Piece,
    ) void {
        const stm = board.side_to_move;
        const from = move.from();
        const to = move.to();
        std.debug.assert(stm.valid() and from.valid() and to.valid());

        const moved_piece = board.at(water.Piece, from);
        std.debug.assert(moved_piece != .none);
        self.updateScore(moved_piece, from, .add);

        switch (move.typeOf(water.MoveType)) {
            .normal => {
                self.updateScore(moved_piece, to, .sub);
                if (captured_piece != .none) {
                    self.updateScore(captured_piece, to, .add);
                }
            },
            .promotion => {
                self.updateScore(
                    water.Piece.make(stm, move.promotionType()),
                    to,
                    .sub,
                );

                if (captured_piece.asType() != .none) {
                    self.updateScore(captured_piece, to, .add);
                }
            },
            .en_passant => {
                const captured_sq = to.ep();
                std.debug.assert(moved_piece.asType() == .pawn and captured_sq.valid());

                self.updateScore(
                    water.Piece.make(stm, .pawn),
                    to,
                    .sub,
                );

                self.updateScore(
                    water.Piece.make(stm.opposite(), .pawn),
                    captured_sq,
                    .add,
                );
            },
            .castling => {
                const side = water.CastlingRights.closestSide(
                    water.Square,
                    to,
                    from,
                    water.Square.order,
                );

                const king_to = water.Square.castlingKingTo(side, stm);
                const rook_from = to;
                const rook_to = water.Square.castlingRookTo(side, stm);
                std.debug.assert(king_to.valid() and rook_from.valid() and rook_to.valid());

                const friendly_king = water.Piece.make(stm, .king);
                const friendly_rook = water.Piece.make(stm, .rook);

                self.updateScore(friendly_king, king_to, .sub);
                self.updateScore(friendly_rook, rook_from, .add);
                self.updateScore(friendly_rook, rook_to, .sub);
            },
            .null_move => {},
        }
    }

    /// Performs a static evaluation for the stm on the given board.
    pub fn evaluate(self: *Evaluator, board: *const water.Board) i32 {
        const color = board.side_to_move;
        const p = phase(board);
        const has_pawns = board.pieces(.none, .pawn).nonzero();
        var result: i32 = 0;
        const halfmove_clock: i32 = @intCast(board.halfmove_clock);

        if (p >= 3 or has_pawns) {
            result = self.nnue.evaluate(board);
        } else {
            var mg_score: i32 = 0;
            var mg_phase: i32 = 0;
            var eg_score: i32 = 0;
            var eg_phase: i32 = 0;

            // Taper the eval as a starting position is at phase 24
            mg_phase = @min(p, 24);
            eg_phase = 24 - mg_phase;

            mg_score = self.pesto.score_mg;
            eg_score = self.pesto.score_eg_mat;

            while (true) {
                // Late endgame consideration only
                if (p <= 4 and p >= 1 and !has_pawns) {
                    // Consider a side winning iff the other side only has a king
                    if (board.pieces(.black, .king).eqBB(board.us(.black))) {
                        eg_score += distance(board, true);
                        eg_score += @divTrunc(self.pesto.score_eg_non_mat, 2);
                        eg_score = @max(100, eg_score - halfmove_clock);
                        break;
                    } else if (board.pieces(.white, .king).eqBB(board.us(.white))) {
                        eg_score += distance(board, false);
                        eg_score += @divTrunc(self.pesto.score_eg_non_mat, 2);
                        eg_score = @min(-100, eg_score + halfmove_clock);
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
        }

        if (p <= 5 and @abs(result) >= 16 and drawish(board)) {
            const drawish_heuristic: i32 = 8;
            result = @divTrunc(result, drawish_heuristic);
        }

        // Decay the result to account for a stagnant position
        const material_normalized: i32 = @divTrunc(materialPhase(board), 32);
        result = @divTrunc(result * (700 + material_normalized - halfmove_clock * 5), 1024);

        return result;
    }
};

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

test "Weak draw detection" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    const positions = [_]struct { fen: []const u8, kind_of_draw: bool }{
        .{ .fen = water.board.starting_fen, .kind_of_draw = false },
        .{ .fen = "8/8/8/8/8/8/8/K6k w - - 0 1", .kind_of_draw = true },
        .{ .fen = "8/8/7k/8/8/8/8/Kn6 w - - 0 1", .kind_of_draw = true },
        .{ .fen = "8/8/7k/8/8/8/8/KNn5 w - - 0 1", .kind_of_draw = true },
        .{ .fen = "8/8/8/8/8/8/8/KNkn4 w - - 0 1", .kind_of_draw = true },
        .{ .fen = "8/8/8/8/8/8/8/KBkb4 w - - 0 1", .kind_of_draw = true },
        .{ .fen = "8/8/8/8/8/8/8/KBkn4 w - - 0 1", .kind_of_draw = true },
        .{ .fen = "8/8/8/8/8/8/8/KNkb4 w - - 0 1", .kind_of_draw = true },
        .{ .fen = "8/8/8/8/8/8/8/KNNkb3 w - - 0 1", .kind_of_draw = true },
        .{ .fen = "8/8/8/8/8/8/8/K1Bnnk3 w - - 0 1", .kind_of_draw = true },
        .{ .fen = "8/8/8/8/8/8/8/KNBkb3 w - - 0 1", .kind_of_draw = true },
        .{ .fen = "8/8/8/8/8/8/8/KBnkn4 w - - 0 1", .kind_of_draw = true },
        .{ .fen = "8/8/8/8/8/8/8/KBkq4 w - - 0 1", .kind_of_draw = false },
    };

    for (positions) |pos| {
        try expect(try board.setFen(pos.fen, true));
        try expectEqual(pos.kind_of_draw, drawish(board));
    }
}

test "Board incremental evaluation branches" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{ .fen = "r3k2r/p1ppqpb1/bnP1pnp1/4N3/Pp2P3/2N2Q2/1PPBBPpP/R3K2R b KQkq a3 0 1" });
    defer board.deinit();

    var refresh_eval = Evaluator{};
    refresh_eval.refresh(board, .full);
    var incremental_eval = Evaluator{};
    incremental_eval.refresh(board, .full);

    // The above fen is special, black is able to:
    // - Move normally with capture or not (a6e2 and b6d5)
    // - Promote with capture or not (g2g1 and g2h1)
    // - Castle both ways (e8h8 and e8a8)
    // - Capture en passant (b4a3)

    // To ensure consistent evaluations, go through all legal moves
    var movelist = water.movegen.Movelist{};
    water.movegen.legalmoves(board, &movelist, .{});

    for (movelist.items()) |move| {
        incremental_eval.makeMove(board, move);
        const capture = board.makeMove(move, .{ .return_captured = true });
        refresh_eval.refresh(board, .full);

        try expectEqual(
            refresh_eval.evaluate(board),
            incremental_eval.evaluate(board),
        );

        board.unmakeMove(move);
        incremental_eval.unmakeMove(board, move, capture);
        refresh_eval.refresh(board, .full);

        try expectEqual(
            refresh_eval.evaluate(board),
            incremental_eval.evaluate(board),
        );
    }
}

test "Full evaluation function" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{
        .fen = "6k1/p4r1p/p1p1b1p1/4p3/2P4Q/1q3p1P/5PPK/8 w - - 1 33",
    });
    defer board.deinit();

    // This is a pv from a from a random sprt test
    const pv = [_][]const u8{
        "g2g4", "b3d1", "h4g3", "d1f1",  "h3h4", "f1g2",
        "g3g2", "f3g2", "c4c5", "g2g1q", "h2g1", "a6a5",
        "g1f1", "a5a4", "h4h5", "g6h5",  "g4h5", "a4a3",
        "h5h6", "a3a2", "f1e1",
    };

    var eval = Evaluator{};
    eval.refresh(board, .full);

    const expected_evals = [_]i32{
        687,   -708,  701,  -684, 752,  -691, -79,   -776, 799,
        -1750, 757,   -808, 805,  -817, 848,  -1094, 1081, -1118,
        1156,  -1165, 1149,
    };

    for (pv, 0..) |move_str, i| {
        const move = water.uci.uciToMove(board, move_str);
        eval.makeMove(board, move);
        board.makeMove(move, .{});
        try expectEqual(expected_evals[i], eval.evaluate(board));
    }
}
