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
const uci = @import("../core/uci.zig");

const attacks = @import("attacks.zig");
const movegen = @import("movegen.zig");
const Movelist = movegen.Movelist;

pub const MovegenType = enum { all, capture, quiet };

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

/// Generates all pawn moves for the current position and appends them to the movelist.
pub fn pawnMoves(
    board: *const Board,
    moves: *Movelist,
    check_mask: Bitboard,
    pin_hv: Bitboard,
    pin_diag: Bitboard,
    occ_them: Bitboard,
    comptime options: struct {
        color: Color,
        gen_type: MovegenType,
    },
) void {
    // Options are compile time, generate comptime constants oriented for color
    const up = comptime Square.Direction.make(.north, options.color);
    const up_left = comptime Square.Direction.make(.north_west, options.color);
    const up_right = comptime Square.Direction.make(.north_east, options.color);

    const down = comptime Square.Direction.make(.south, options.color);
    const down_left = comptime Square.Direction.make(.south_west, options.color);
    const down_right = comptime Square.Direction.make(.south_east, options.color);

    const rank_before_promo = comptime Bitboard.fromRank(Rank.r7.orient(options.color));
    const rank_promo = comptime Bitboard.fromRank(Rank.r8.orient(options.color));
    const rank_double_push = comptime Bitboard.fromRank(Rank.r3.orient(options.color));

    const pawns = board.pieces(options.color, .pawn);
    const occ = board.occ();

    // Generate pawns that can take on left or right
    const pawns_lr = pawns.andBB(pin_hv.not());
    const pinned_pawns_lr = pawns_lr.andBB(pin_diag);
    const unpinned_pawns_lr = pawns_lr.andBB(pin_diag.not());

    var pawns_l = attacks.shift(up_left, unpinned_pawns_lr).orBB(
        attacks.shift(up_left, pinned_pawns_lr).andBB(pin_diag),
    );
    _ = pawns_l.andAssign(occ_them.andBB(check_mask));

    var pawns_r = attacks.shift(up_right, unpinned_pawns_lr).orBB(
        attacks.shift(up_right, pinned_pawns_lr).andBB(pin_diag),
    );
    _ = pawns_r.andAssign(occ_them.andBB(check_mask));

    // Generate pawns that can move forward
    const pawns_hv = pawns.andBB(pin_diag.not());
    const pinned_pawns_hv = pawns_hv.andBB(pin_hv);
    const unpinned_pawns_hv = pawns_hv.andBB(pin_hv.not());

    const pinned_single_push = attacks.shift(
        up,
        pinned_pawns_hv,
    ).andBB(pin_hv).andBB(occ.not());

    const unpinned_single_push = attacks.shift(
        up,
        unpinned_pawns_hv,
    ).andBB(occ.not());

    var single_push = pinned_single_push.orBB(unpinned_single_push).andBB(check_mask);
    var double_push = attacks.shift(
        up,
        unpinned_single_push.andBB(rank_double_push),
    ).andBB(occ.not()).orBB(attacks.shift(
        up,
        pinned_single_push.andBB(rank_double_push),
    ).andBB(occ.not()).andBB(check_mask));

    // Generate promoting moves
    if (pawns.andBB(rank_before_promo).nonzero()) {
        var left_promo = pawns_l.andBB(rank_promo);
        var right_promo = pawns_r.andBB(rank_promo);
        var push_promo = single_push.andBB(rank_promo);

        // Skip capturing promotions in quiet
        if (options.gen_type != .quiet) {
            while (left_promo.nonzero()) {
                const index = left_promo.popLsb();
                moves.add(Move.make(index.addToDirection(down_right), index, .{
                    .move_type = .promotion,
                    .promotion_type = .queen,
                }));
                moves.add(Move.make(index.addToDirection(down_right), index, .{
                    .move_type = .promotion,
                    .promotion_type = .rook,
                }));
                moves.add(Move.make(index.addToDirection(down_right), index, .{
                    .move_type = .promotion,
                    .promotion_type = .bishop,
                }));
                moves.add(Move.make(index.addToDirection(down_right), index, .{
                    .move_type = .promotion,
                    .promotion_type = .knight,
                }));
            }

            while (right_promo.nonzero()) {
                const index = right_promo.popLsb();
                moves.add(Move.make(index.addToDirection(down_left), index, .{
                    .move_type = .promotion,
                    .promotion_type = .queen,
                }));
                moves.add(Move.make(index.addToDirection(down_left), index, .{
                    .move_type = .promotion,
                    .promotion_type = .rook,
                }));
                moves.add(Move.make(index.addToDirection(down_left), index, .{
                    .move_type = .promotion,
                    .promotion_type = .bishop,
                }));
                moves.add(Move.make(index.addToDirection(down_left), index, .{
                    .move_type = .promotion,
                    .promotion_type = .knight,
                }));
            }
        }

        // Skip quiet promotions if capture
        if (options.gen_type != .capture) {
            while (push_promo.nonzero()) {
                const index = push_promo.popLsb();
                moves.add(Move.make(index.addToDirection(down), index, .{
                    .move_type = .promotion,
                    .promotion_type = .queen,
                }));
                moves.add(Move.make(index.addToDirection(down), index, .{
                    .move_type = .promotion,
                    .promotion_type = .rook,
                }));
                moves.add(Move.make(index.addToDirection(down), index, .{
                    .move_type = .promotion,
                    .promotion_type = .bishop,
                }));
                moves.add(Move.make(index.addToDirection(down), index, .{
                    .move_type = .promotion,
                    .promotion_type = .knight,
                }));
            }
        }
    }

    // Remove our contended pawns
    _ = single_push.andAssign(rank_promo.not());
    _ = pawns_l.andAssign(rank_promo.not());
    _ = pawns_r.andAssign(rank_promo.not());

    // Generate all remaining pawn moves
    if (options.gen_type != .quiet) {
        while (pawns_l.nonzero()) {
            const index = pawns_l.popLsb();
            moves.add(Move.make(index.addToDirection(down_right), index, .{}));
        }

        while (pawns_r.nonzero()) {
            const index = pawns_r.popLsb();
            moves.add(Move.make(index.addToDirection(down_left), index, .{}));
        }
    }

    if (options.gen_type != .capture) {
        while (single_push.nonzero()) {
            const index = single_push.popLsb();
            moves.add(Move.make(index.addToDirection(down), index, .{}));
        }

        while (double_push.nonzero()) {
            const index = double_push.popLsb();
            moves.add(Move.make(
                index.addToDirection(down).addToDirection(down),
                index,
                .{},
            ));
        }
    }

    // Only check ep if not in quiet
    if (comptime options.gen_type == .quiet) return else if (board.ep_square.valid()) {
        const contenders = epMoves(
            board,
            check_mask,
            pin_diag,
            pawns_lr,
            board.ep_square,
            options.color,
        );

        for (contenders) |move| {
            if (move.valid()) moves.add(move);
        }
    }
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

test "Pawn move generation" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    // White moves from opening position
    var ml = Movelist{};
    pawnMoves(
        board,
        &ml,
        Bitboard.fromInt(u64, 18446744073709551615),
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 18446462598732840960),
        .{ .gen_type = .all, .color = .white },
    );
    try expectEqual(16, ml.size);

    const expected_openings: [16]u16 = .{
        528, 593, 658, 723, 788, 853, 918, 983,
        536, 601, 666, 731, 796, 861, 926, 991,
    };
    for (ml.slice(16), 0..) |move, i| {
        try expectEqual(expected_openings[i], move.move);
    }

    // Black moves in mid-game position
    ml.reset();
    try expect(try board.setFen("rnbqkb1r/Pp3p2/5n2/2p5/1P1ppPP1/3PQN2/2P1P1pp/RNB1KB1R b KQkq - 0 1", true));
    pawnMoves(
        board,
        &ml,
        Bitboard.fromInt(u64, 18446744073709551615),
        Bitboard.fromInt(u64, 4521260802375680),
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 281476624553143),
        .{ .gen_type = .all, .color = .black },
    );
    try expectEqual(17, ml.size);

    const expected_mid: [17]u16 = .{
        29575, 25479, 21383, 17287, 29573, 25477, 21381, 17285,
        29574, 25478, 21382, 17286, 1748,  2201,  2202,  3177,
        3169,
    };
    for (ml.slice(17), 0..) |move, i| {
        try expectEqual(expected_mid[i], move.move);
    }

    // White moves - quiet moves only
    ml.reset();
    try expect(try board.setFen("1nbqkb1r/Pp3p2/2r2n2/2p5/1P1ppPP1/3PQN2/2P1P1pp/RNB1KB1R w KQk - 0 1", true));
    pawnMoves(
        board,
        &ml,
        Bitboard.fromInt(u64, 18446744073709551615),
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 13700552616415641600),
        .{ .gen_type = .quiet, .color = .white },
    );
    try expectEqual(9, ml.size);

    const expected_quiets: [9]u16 = .{
        31800, 27704, 23608, 19512, 658, 1633, 1893, 1958, 666,
    };
    for (ml.slice(9), 0..) |move, i| {
        try expectEqual(expected_quiets[i], move.move);
    }

    // Black moves - capture moves only
    ml.reset();
    try expect(try board.setFen("1nbqkb1r/Pp3p2/2r2n2/2p5/1P1ppPP1/3PQN2/2P1P1pp/RNB1KB1R b KQk - 0 1", true));
    pawnMoves(
        board,
        &ml,
        Bitboard.fromInt(u64, 18446744073709551615),
        Bitboard.fromInt(u64, 4521260802375680),
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 281476624553143),
        .{ .gen_type = .capture, .color = .black },
    );
    try expectEqual(10, ml.size);

    const expected_captures: [10]u16 = .{
        29575, 25479, 21383, 17287, 29573, 25477, 21381, 17285,
        1748,  2201,
    };
    for (ml.slice(10), 0..) |move, i| {
        try expectEqual(expected_captures[i], move.move);
    }
}
