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

const attacks = @import("attacks.zig");
const movegen = @import("movegen.zig");

/// Generates the (up to) two possible moves that could capture en passant.
///
/// Asserts that the position is actually an ep contender.
pub fn epMoves(
    board: *const Board,
    check_mask: Bitboard,
    pin_diag: Bitboard,
    pawns_lr: Bitboard,
    ep: Square,
    color: Color,
) [2]Move {
    const black_ep = ep.rank() == .r3 and board.side_to_move == .black;
    const white_ep = ep.rank() == .r6 and board.side_to_move == .white;
    std.debug.assert(black_ep or white_ep);

    var moves: [2]Move = @splat(Move.init());
    var idx: usize = 0;

    const down = Square.Direction.make(.south, color);
    const ep_pawn_sq = ep.addToDirection(down);

    const on_check_mask = check_mask.andBB(Bitboard.fromSquare(
        ep_pawn_sq,
    ).orBB(Bitboard.fromSquare(ep)));
    if (on_check_mask.empty()) return moves;

    const king_sq = board.kingSq(color);
    const king_mask = Bitboard.fromSquare(king_sq).andBB(Bitboard.fromRank(ep_pawn_sq.rank()));
    var ep_bb = attacks.pawn(color.opposite(), ep).andBB(pawns_lr);
    const enemy_queen_rook = board.piecesMany(
        color.opposite(),
        &[_]PieceType{ .rook, .queen },
    );

    // Two pawns can potentially take an ep square in a given position
    while (ep_bb.nonzero()) {
        const from = ep_bb.popLsb();
        const to = ep;

        // The move is illegal if the ep not in pin masked but we have pp
        if (Bitboard.fromSquare(from).andBB(pin_diag).nonzero() and pin_diag.andBB(
            Bitboard.fromSquare(ep),
        ).empty()) {
            continue;
        }
        const connecting_pawns = Bitboard.fromSquare(ep_pawn_sq).orBB(Bitboard.fromSquare(from));

        // Check if taking up exposes a check
        const possible_pin = king_mask.nonzero() and enemy_queen_rook.nonzero();
        const qr_attacks = attacks.rook(
            king_sq,
            board.occ().xorBB(connecting_pawns),
        ).andBB(enemy_queen_rook).nonzero();
        if (possible_pin and qr_attacks) break;

        moves[idx] = Move.make(from, to, .{ .move_type = .en_passant });
        idx += 1;
    }

    return moves;
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

test "Ep move generator" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    // From starting position, white shouldn't be able to take ep on rank 6
    const no_moves_starting = epMoves(
        board,
        Bitboard.fromInt(u64, 18446744073709551615),
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 65280),
        .e6,
        .white,
    );

    for (no_moves_starting) |move| {
        try expectEqual(0, move.move);
    }

    // Custom position where white has a single ep option
    try expect(try board.setFen("rnbqk1nr/pp2pp1p/2pp3b/1B4pP/3PP3/8/PPPK1P1P/RNBQ2NR w kq g6 0 1", true));
    const single_option = epMoves(
        board,
        Bitboard.fromInt(u64, 18446744073709551615),
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 550158509824),
        .g6,
        .white,
    );

    const expected_single_option: [2]Move = .{ Move.fromMove(35310), Move.fromMove(0) };

    for (expected_single_option, single_option) |expected, move| {
        try expectEqual(expected.move, move.move);
    }

    // Custom position where black has two ep options but cant use them because of a check
    try expect(try board.setFen("rnbqk1nr/pp2pp1p/7b/1B4pP/1pPpP3/8/PP1K1P1P/RNBQ2NR b kq c3 0 1", true));
    const no_moves_pinned = epMoves(
        board,
        Bitboard.fromInt(u64, 2256206450130944),
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 50384295876886528),
        .c3,
        .black,
    );

    for (no_moves_pinned) |move| {
        try expectEqual(0, move.move);
    }

    // Custom position where black has two valid ep options
    try expect(try board.setFen("rnbqk1nr/pp2pp1p/7b/B5pP/1pPpP3/8/PP1K1P1P/RNBQ2NR b kq c3 0 1", true));
    const two_options = epMoves(
        board,
        Bitboard.fromInt(u64, 18446744073709551615),
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 50384295876886528),
        .c3,
        .black,
    );

    const expected_two_options: [2]Move = .{ Move.fromMove(34386), Move.fromMove(34514) };

    for (expected_two_options, two_options) |expected, move| {
        try expectEqual(expected.move, move.move);
    }
}
