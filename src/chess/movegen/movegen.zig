const std = @import("std");

const types = @import("../core/types.zig");
const Square = types.Square;
const File = types.File;
const Rank = types.Rank;
const Color = types.Color;

const bitboard = @import("../core/bitboard.zig");
const Bitboard = bitboard.Bitboard;

const piece_ = @import("../core/piece.zig");
const Piece = piece_.Piece;
const PieceType = piece_.PieceType;

const board_ = @import("../board/board.zig");
const Board = board_.Board;

const move_ = @import("../core/move.zig");
const Move = move_.Move;
const MoveType = move_.MoveType;

const distance = @import("../core/distance.zig");

const generators = @import("generators.zig");
const attacks = @import("attacks.zig");

pub const DefaultCheckMask = Bitboard.fromInt(u64, std.math.maxInt(u64));
pub const MaxMoves: usize = 256;

/// A zero allocation static initialized array with the ability to store up to 256 moves.
///
/// Out of bounds checks are asserted.
pub const Movelist = struct {
    moves: [MaxMoves]Move = @splat(Move.init()),
    size: usize = 0,

    /// Returns the first move in the internal list.
    pub fn front(self: *const Movelist) Move {
        return self.moves[0];
    }

    /// Returns the last move in the internal list.
    pub fn back(self: *const Movelist) Move {
        return self.moves[self.size - 1];
    }

    /// Retrieves the move at the given index.
    pub fn at(self: *const Movelist, index: usize) Move {
        std.debug.assert(index < self.size);
        return self.moves[index];
    }

    /// Linearly searches the Movelist for the given move.
    ///
    /// Returns null if the move is not found.
    pub fn find(self: *const Movelist, move: Move) ?usize {
        for (self.moves[0..self.size], 0..) |m, i| {
            if (move.eqMove(m)) return i;
        }
        return null;
    }

    /// Resets the size and internal moves to their starting values.
    pub fn reset(self: *Movelist) void {
        self.moves = @splat(Move.init());
        self.size = 0;
    }

    /// Appends a move to the Movelist.
    pub fn add(self: *Movelist, move: Move) void {
        std.debug.assert(self.size < MaxMoves);
        self.moves[self.size] = move;
        self.size += 1;
    }

    /// Returns a reference to the first N moves.
    ///
    /// The length must be compile time known, for non-comptime slices, use:
    ///
    /// `ml.moves[0..ml.size]` where ml is the Movelist.
    pub fn slice(self: *const Movelist, comptime N: usize) *const [N]Move {
        std.debug.assert(N <= self.size);
        return self.moves[0..N];
    }
};

/// Generates the check mask where the attacker path from the king and enemy piece is set.
///
/// The number of checks is also tracked and returned.
pub fn checkMask(board: *const Board, color: Color, square: Square) struct {
    mask: Bitboard,
    checks: usize,
} {
    const opponent_knights = board.pieces(color.opposite(), .knight);
    const opponent_bishops = board.pieces(color.opposite(), .bishop);
    const opponent_rooks = board.pieces(color.opposite(), .rook);
    const opponent_queens = board.pieces(color.opposite(), .queen);
    const opponent_pawns = board.pieces(color.opposite(), .pawn);

    var checks: usize = 0;

    const knight_attacks = attacks.knight(square).andBB(opponent_knights);
    checks += @intFromBool(knight_attacks.nonzero());
    var mask = knight_attacks;

    const pawn_attacks = attacks.pawn(board.side_to_move, square).andBB(opponent_pawns);
    checks += @intFromBool(pawn_attacks.nonzero());
    _ = mask.orAssign(pawn_attacks);

    const bishop_attacks = attacks.bishop(
        square,
        board.occ(),
    ).andBB(opponent_bishops.orBB(opponent_queens));
    if (bishop_attacks.nonzero()) {
        _ = mask.orAssign(distance.SquaresBetween[square.index()][bishop_attacks.lsb().index()]);
        checks += 1;
    }

    const rook_attacks = attacks.rook(
        square,
        board.occ(),
    ).andBB(opponent_rooks.orBB(opponent_queens));
    if (rook_attacks.nonzero()) {
        if (rook_attacks.count() > 1) {
            checks = 2;
            return .{ .mask = mask, .checks = checks };
        }

        _ = mask.orAssign(distance.SquaresBetween[square.index()][rook_attacks.lsb().index()]);
        checks += 1;
    }

    return .{
        .mask = if (mask.empty()) DefaultCheckMask else mask,
        .checks = checks,
    };
}

/// Generate the pin mask for the specified non-queen slider.
/// Returns a mask where the ray between the king and pinner are set.
///
/// Use `pt = .rook` for horizontal and vertical pins.
///
/// Use `pt = .bishop` for diagonal pins.
///
/// Asserts that pt is either a rook or bishop.
pub fn pinMask(
    comptime pt: PieceType,
    board: *const Board,
    color: Color,
    square: Square,
    occ_them: Bitboard,
    occ_us: Bitboard,
) Bitboard {
    if (!(pt == .bishop or pt == .rook)) @compileError("Pins can only be generated for rooks and bishops");

    const opponent_pt_queen = board.piecesMany(
        color.opposite(),
        &[_]PieceType{ pt, .queen },
    );

    var pt_attacks = attacks.slider(
        pt,
        square,
        occ_them,
    ).andBB(opponent_pt_queen);
    var pin = Bitboard.init();

    while (pt_attacks.nonzero()) {
        const possible_pin = distance.SquaresBetween[square.index()][pt_attacks.popLsb().index()];
        if (possible_pin.andBB(occ_us).count() == 1) {
            _ = pin.orAssign(possible_pin);
        }
    }

    return pin;
}

/// Calculates a mask of the squares seen by the given color on the board.
pub fn seenSquares(comptime C: Color, board: *const Board, enemy_empty: Bitboard) Bitboard {
    const king_sq = board.kingSq(C.opposite());
    const map_king_atk = attacks.king(king_sq).andBB(enemy_empty);

    if (map_king_atk.empty() and !board.fischer_random) return Bitboard.init();

    const occ = board.occ().xorBB(Bitboard.fromSquare(king_sq));
    const queens = board.pieces(C, .queen);
    const pawns = board.pieces(C, .pawn);
    var knights = board.pieces(C, .knight);
    var bishops = board.pieces(C, .bishop).orBB(queens);
    var rooks = board.pieces(C, .rook).orBB(queens);

    var seen = attacks.pawnLeftAttacks(C, pawns).orBB(
        attacks.pawnRightAttacks(C, pawns),
    );

    while (knights.nonzero()) {
        _ = seen.orAssign(attacks.knight(knights.popLsb()));
    }

    while (bishops.nonzero()) {
        _ = seen.orAssign(attacks.bishop(bishops.popLsb(), occ));
    }

    while (rooks.nonzero()) {
        _ = seen.orAssign(attacks.rook(rooks.popLsb(), occ));
    }

    _ = seen.orAssign(attacks.king(board.kingSq(C)));
    return seen;
}

/// Determines if the provided square is a possible ep square based on the current position.
pub fn isEpSquareValid(board: *const Board, color: Color, ep: Square) bool {
    const stm = board.side_to_move;

    const occ_us = board.us(stm);
    const occ_opp = board.us(stm.opposite());
    const king_sq = board.kingSq(stm);

    const cm = checkMask(board, color, king_sq);
    const pin_hv = pinMask(.rook, board, color, king_sq, occ_opp, occ_us);
    const pin_diag = pinMask(.bishop, board, color, king_sq, occ_opp, occ_us);

    const pawns = board.pieces(stm, .pawn);
    const pawns_lr = pawns.andBB(pin_hv.not());
    const contenders = generators.epMoves(
        board,
        cm.mask,
        pin_diag,
        pawns_lr,
        ep,
        stm,
    );

    var found = false;
    for (contenders) |move| {
        if (move.move != 0) {
            found = true;
            break;
        }
    }
    return found;
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

test "Movelist creation and operations" {
    var ml = Movelist{};
    ml.size = MaxMoves;
    for (ml.slice(MaxMoves - 1)) |move| {
        try expectEqual(0, move.move);
    }

    ml.reset();
    ml.add(Move.make(.e2, .e3, .{}));

    try expect(ml.find(Move.make(.e2, .e3, .{})) != null);
    try expect(ml.find(Move.make(.e2, .e4, .{})) == null);

    try expectEqual(ml.front().move, ml.back().move);
    try expect(ml.at(0).move == Move.make(.e2, .e3, .{}).move);
}

test "Check and pin masks" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{
        .fen = "8/3r4/pr1Pk1p1/8/7P/6P1/3R3K/5R2 w - - 20 80",
    });

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    // Expected check mask values from https://github.com/Disservin/chess-library
    const expected_check_masks_white: [64]u64 = .{
        18446744073709551615, 2207646876160,        18446744073709551615, 18446744073709551615,
        18446744073709551615, 18446744073709551615, 18446744073709551615, 18446744073709551615,
        18446744073709551615, 2207646875648,        18446744073709551615, 18446744073709551615,
        18446744073709551615, 18446744073709551615, 18446744073709551615, 18446744073709551615,
        18446744073709551615, 2207646744576,        18446744073709551615, 18446744073709551615,
        18446744073709551615, 18446744073709551615, 18446744073709551615, 18446744073709551615,
        18446744073709551615, 2207613190144,        18446744073709551615, 18446744073709551615,
        18446744073709551615, 18446744073709551615, 18446744073709551615, 18446744073709551615,
        18446744073709551615, 3298534883328,        18446744073709551615, 18446744073709551615,
        18446744073709551615, 70368744177664,       18446744073709551615, 70368744177664,
        2199023255552,        18446744073709551615, 2199023255552,        0,
        18446744073709551615, 18446744073709551615, 18446744073709551615, 18446744073709551615,
        3940649673949184,     0,                    2251799813685248,     18446744073709551615,
        2251799813685248,     6755399441055744,     15762598695796736,    33776997205278720,
        18446744073709551615, 565148976676864,      18446744073709551615, 2251799813685248,
        18446744073709551615, 18446744073709551615, 18446744073709551615, 18446744073709551615,
    };

    const expected_checks_white: [64]usize = .{
        0, 1, 0, 0, 0, 0, 0, 0,
        0, 1, 0, 0, 0, 0, 0, 0,
        0, 1, 0, 0, 0, 0, 0, 0,
        0, 1, 0, 0, 0, 0, 0, 0,
        0, 2, 0, 0, 0, 1, 0, 1,
        1, 0, 1, 2, 0, 0, 0, 0,
        1, 2, 1, 0, 1, 1, 1, 1,
        0, 1, 0, 1, 0, 0, 0, 0,
    };

    for (0..64) |i| {
        const cm = checkMask(
            board,
            .white,
            Square.fromInt(usize, i),
        );

        try expectEqual(expected_check_masks_white[i], cm.mask.bits);
        try expectEqual(expected_checks_white[i], cm.checks);
    }

    const expected_check_masks_black: [64]u64 = .{
        62,                   60,                   56,                   0,
        32,                   18446744073709551615, 32,                   96,
        3584,                 3072,                 2048,                 18446744073709551615,
        2048,                 4194304,              14336,                4225024,
        18446744073709551615, 18446744073709551615, 18446744073709551615, 2048,
        18446744073709551615, 8224,                 2147483648,           18446744073709551615,
        18446744073709551615, 18446744073709551615, 18446744073709551615, 526336,
        18446744073709551615, 2105376,              18446744073709551615, 18446744073709551615,
        18446744073709551615, 18446744073709551615, 8796093022208,        134744064,
        8796093022208,        538976288,            18446744073709551615, 18446744073709551615,
        18446744073709551615, 18446744073709551615, 18446744073709551615, 34494482432,
        18446744073709551615, 137977929760,         18446744073709551615, 18446744073709551615,
        18446744073709551615, 18446744073709551615, 18446744073709551615, 18446744073709551615,
        18446744073709551615, 35322350018592,       18446744073709551615, 18446744073709551615,
        18446744073709551615, 18446744073709551615, 18446744073709551615, 18446744073709551615,
        18446744073709551615, 9042521604759584,     18446744073709551615, 18446744073709551615,
    };

    const expected_checks_black: [64]usize = .{
        1, 1, 1, 2, 1, 0, 1, 1,
        1, 1, 1, 0, 1, 2, 1, 2,
        0, 0, 0, 1, 0, 1, 1, 0,
        0, 0, 0, 1, 0, 1, 0, 0,
        0, 0, 1, 1, 1, 1, 0, 0,
        0, 0, 0, 1, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 1, 0, 0,
    };

    for (0..64) |i| {
        const cm = checkMask(
            board,
            .black,
            Square.fromInt(usize, i),
        );

        try expectEqual(expected_check_masks_black[i], cm.mask.bits);
        try expectEqual(expected_checks_black[i], cm.checks);
    }

    // Expected pin mask values from https://github.com/Disservin/chess-library
    const expected_white_rook_pins: [64]u64 = .{
        0, 0, 0, 0,                0,              0, 0, 0,
        0, 0, 0, 2260630401187840, 0,              0, 0, 0,
        0, 0, 0, 2260630400663552, 0,              0, 0, 0,
        0, 0, 0, 2260630266445824, 0,              0, 0, 0,
        0, 0, 0, 2260595906707456, 0,              0, 0, 0,
        0, 0, 0, 0,                15393162788864, 0, 0, 0,
        0, 0, 0, 0,                0,              0, 0, 0,
        0, 0, 0, 0,                0,              0, 0, 0,
    };

    for (0..64) |i| {
        const pm = pinMask(
            .rook,
            board,
            .white,
            Square.fromInt(usize, i),
            board.us(.black),
            board.us(.white),
        );

        try expectEqual(expected_white_rook_pins[i], pm.bits);
    }

    try expect(try board.setFen("rnbqk1nr/pp2p2p/2pp1pp1/1B6/3P3b/4P3/PPP2PPP/RNBQK1NR w KQkq - 0 1", true));
    const expected_black_bishop_pins: [64]u64 = .{
        0, 0, 0, 0,             0,                0, 0, 0,
        0, 0, 0, 0,             0,                0, 0, 0,
        0, 0, 0, 0,             0,                0, 0, 0,
        0, 0, 0, 0,             0,                0, 0, 0,
        0, 0, 0, 0,             0,                0, 0, 0,
        0, 0, 0, 0,             0,                0, 0, 0,
        0, 0, 0, 4406636445696, 0,                0, 0, 0,
        0, 0, 0, 0,             2256206450130944, 0, 0, 0,
    };

    for (0..64) |i| {
        const pm = pinMask(
            .bishop,
            board,
            .black,
            Square.fromInt(usize, i),
            board.us(.white),
            board.us(.black),
        );

        try expectEqual(expected_black_bishop_pins[i], pm.bits);
    }
}

test "Seen squares" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    // Expected values from https://github.com/Disservin/chess-library
    const opening = seenSquares(.white, board, board.us(.black).not());
    try expectEqual(0, opening.bits);

    try expect(try board.setFen("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", true));
    const complex = seenSquares(.white, board, board.us(.black).not());
    try expectEqual(7075169857099529727, complex.bits);
}

test "Ep square validity" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    // No ep from starting position
    try expect(!isEpSquareValid(board, .white, .e6));

    // White has a single ep move
    try expect(try board.setFen("rnbqk1nr/pp2pp1p/2pp3b/1B4pP/3PP3/8/PPPK1P1P/RNBQ2NR w kq g6 0 1", true));
    try expect(isEpSquareValid(board, .white, .g6));

    // Black has two ep options but can't use them because of a check
    try expect(try board.setFen("rnbqk1nr/pp2pp1p/7b/1B4pP/1pPpP3/8/PP1K1P1P/RNBQ2NR b kq c3 0 1", true));
    try expect(!isEpSquareValid(board, .black, .c3));

    // Black has two ep options and can use them
    try expect(try board.setFen("rnbqk1nr/pp2pp1p/7b/B5pP/1pPpP3/8/PP1K1P1P/RNBQ2NR b kq c3 0 1", true));
    try expect(isEpSquareValid(board, .black, .c3));
}
