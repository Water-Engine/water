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

const castling = @import("../board/castling.zig");
const CastlingRights = castling.CastlingRights;

const move_ = @import("../core/move.zig");
const Move = move_.Move;
const MoveType = move_.MoveType;

const distance = @import("../core/distance.zig");
const uci = @import("../core/uci.zig");

const attacks = @import("attacks.zig");
const movegen = @import("movegen.zig");
const Movelist = movegen.Movelist;

pub const MovegenType = enum { all, capture, quiet };
pub const AllPieces: [6]PieceType = [_]PieceType{ .pawn, .knight, .bishop, .rook, .queen, .king };

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
    movelist: *Movelist,
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
    ).andBB(occ.not())).andBB(check_mask);

    // Generate promoting moves
    if (pawns.andBB(rank_before_promo).nonzero()) {
        var left_promo = pawns_l.andBB(rank_promo);
        var right_promo = pawns_r.andBB(rank_promo);
        var push_promo = single_push.andBB(rank_promo);

        // Skip capturing promotions in quiet
        if (options.gen_type != .quiet) {
            while (left_promo.nonzero()) {
                const index = left_promo.popLsb();
                movelist.add(Move.make(index.addToDirection(down_right), index, .{
                    .move_type = .promotion,
                    .promotion_type = .queen,
                }));
                movelist.add(Move.make(index.addToDirection(down_right), index, .{
                    .move_type = .promotion,
                    .promotion_type = .rook,
                }));
                movelist.add(Move.make(index.addToDirection(down_right), index, .{
                    .move_type = .promotion,
                    .promotion_type = .bishop,
                }));
                movelist.add(Move.make(index.addToDirection(down_right), index, .{
                    .move_type = .promotion,
                    .promotion_type = .knight,
                }));
            }

            while (right_promo.nonzero()) {
                const index = right_promo.popLsb();
                movelist.add(Move.make(index.addToDirection(down_left), index, .{
                    .move_type = .promotion,
                    .promotion_type = .queen,
                }));
                movelist.add(Move.make(index.addToDirection(down_left), index, .{
                    .move_type = .promotion,
                    .promotion_type = .rook,
                }));
                movelist.add(Move.make(index.addToDirection(down_left), index, .{
                    .move_type = .promotion,
                    .promotion_type = .bishop,
                }));
                movelist.add(Move.make(index.addToDirection(down_left), index, .{
                    .move_type = .promotion,
                    .promotion_type = .knight,
                }));
            }
        }

        // Skip quiet promotions if capture
        if (options.gen_type != .capture) {
            while (push_promo.nonzero()) {
                const index = push_promo.popLsb();
                movelist.add(Move.make(index.addToDirection(down), index, .{
                    .move_type = .promotion,
                    .promotion_type = .queen,
                }));
                movelist.add(Move.make(index.addToDirection(down), index, .{
                    .move_type = .promotion,
                    .promotion_type = .rook,
                }));
                movelist.add(Move.make(index.addToDirection(down), index, .{
                    .move_type = .promotion,
                    .promotion_type = .bishop,
                }));
                movelist.add(Move.make(index.addToDirection(down), index, .{
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
            movelist.add(Move.make(index.addToDirection(down_right), index, .{}));
        }

        while (pawns_r.nonzero()) {
            const index = pawns_r.popLsb();
            movelist.add(Move.make(index.addToDirection(down_left), index, .{}));
        }
    }

    if (options.gen_type != .capture) {
        while (single_push.nonzero()) {
            const index = single_push.popLsb();
            movelist.add(Move.make(index.addToDirection(down), index, .{}));
        }

        while (double_push.nonzero()) {
            const index = double_push.popLsb();
            movelist.add(Move.make(
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
            if (move.valid()) movelist.add(move);
        }
    }
}

/// Returns a bitboard containing all possible moves a knight on the given square can move to.
pub fn knightMoves(square: Square) Bitboard {
    return attacks.knight(square);
}

/// Returns a bitboard containing all possible moves a king on the given square can move to.
pub fn kingMoves(square: Square, seen: Bitboard, moveable_square: Bitboard) Bitboard {
    return attacks.king(square).andBB(moveable_square).andBB(seen.not());
}

/// Returns a bitboard containing all possible castling moves.
pub fn castleMoves(
    board: *const Board,
    square: Square,
    seen: Bitboard,
    pin_hv: Bitboard,
    comptime options: struct { color: Color },
) Bitboard {
    var moves = Bitboard.init();
    if (!square.backRank(options.color) or !board.castling_rights.hasEither(options.color)) {
        return moves;
    }

    for ([_]CastlingRights.Side{ .king, .queen }) |side| {
        if (!board.castling_rights.hasSide(options.color, side)) {
            continue;
        }

        // Check if the castling path is vacant
        if (board.occ().andBB(
            board.castling_path[options.color.index()][side.index()],
        ).nonzero()) {
            continue;
        }

        // Check for attacks on the king's path
        const king_to = Square.castlingKingTo(side, options.color);
        if (distance.SquaresBetween[square.index()][king_to.index()].andBB(seen).nonzero()) {
            continue;
        }

        const from_rook_bb = Bitboard.fromSquare(Square.make(
            square.rank(),
            board.castling_rights.rookFile(options.color, side),
        ));

        // Check for rook pins only in FRC
        if (board.fischer_random and pin_hv.andBB(board.us(
            board.side_to_move,
        )).andBB(from_rook_bb).nonzero()) {
            continue;
        }

        _ = moves.orAssign(from_rook_bb);
    }

    return moves;
}

/// Returns a bitboard containing all possible moves a bishop on the given square can move to.
pub fn bishopMoves(square: Square, pin_d: Bitboard, occ_all: Bitboard) Bitboard {
    return if (pin_d.andBB(Bitboard.fromSquare(square)).nonzero()) blk: {
        break :blk attacks.bishop(square, occ_all).andBB(pin_d);
    } else blk: {
        break :blk attacks.bishop(square, occ_all);
    };
}

/// Returns a bitboard containing all possible moves a rook on the given square can move to.
pub fn rookMoves(square: Square, pin_hv: Bitboard, occ_all: Bitboard) Bitboard {
    return if (pin_hv.andBB(Bitboard.fromSquare(square)).nonzero()) blk: {
        break :blk attacks.rook(square, occ_all).andBB(pin_hv);
    } else blk: {
        break :blk attacks.rook(square, occ_all);
    };
}

/// Returns a bitboard containing all possible moves a queen on the given square can move to.
pub fn queenMoves(square: Square, pin_d: Bitboard, pin_hv: Bitboard, occ_all: Bitboard) Bitboard {
    return if (pin_d.andBB(Bitboard.fromSquare(square)).nonzero()) blk: {
        break :blk attacks.bishop(square, occ_all).andBB(pin_d);
    } else if (pin_hv.andBB(Bitboard.fromSquare(square)).nonzero()) blk: {
        break :blk attacks.rook(square, occ_all).andBB(pin_hv);
    } else blk: {
        break :blk attacks.rook(square, occ_all).orBB(
            attacks.bishop(square, occ_all),
        );
    };
}

/// An enum used for mapping PieceTypes to powers of two
const PieceGenType = enum(u6) {
    pawn = 1,
    knight = 2,
    bishop = 4,
    rook = 8,
    queen = 16,
    king = 32,

    pub fn pt2pgt(comptime pt: PieceType) PieceGenType {
        return switch (pt) {
            .pawn => PieceGenType.pawn,
            .knight => PieceGenType.knight,
            .bishop => PieceGenType.bishop,
            .rook => PieceGenType.rook,
            .queen => PieceGenType.queen,
            .king => PieceGenType.king,
            .none => @compileError("No matching PieceGenType for PieceType.none"),
        };
    }

    pub fn pts2bb(comptime pts: []const PieceType) Bitboard {
        var bb = Bitboard.init();
        inline for (pts) |pt| {
            _ = bb.orAssign(Bitboard.fromInt(u6, @intFromEnum(pt2pgt(pt))));
        }
        return bb;
    }
};

/// Generates all legal moves for the current position and appends them to the movelist.
pub fn all(
    board: *const Board,
    movelist: *Movelist,
    comptime options: struct {
        color: Color,
        gen_type: MovegenType,
        pieces: []const PieceType,
    },
) void {
    const pieces = comptime PieceGenType.pts2bb(options.pieces);
    const king_sq = board.kingSq(options.color);

    const occ_us = board.us(options.color);
    const occ_opp = board.us(options.color.opposite());
    const occ_all = occ_us.orBB(occ_opp);

    const opp_empty = occ_us.not();

    const cm = movegen.checkMask(board, options.color, king_sq);
    const check_mask = cm.mask;
    const checks = cm.checks;
    std.debug.assert(checks <= 2);

    const pin_hv = movegen.pinMask(
        .rook,
        board,
        options.color,
        king_sq,
        occ_opp,
        occ_us,
    );

    const pin_d = movegen.pinMask(
        .bishop,
        board,
        options.color,
        king_sq,
        occ_opp,
        occ_us,
    );

    var moveable_square = if (comptime options.gen_type == .all) blk: {
        break :blk opp_empty;
    } else if (comptime options.gen_type == .capture) blk: {
        break :blk occ_opp;
    } else occ_all.not();

    const addMovesFromMask = struct {
        /// Adds moves to the movelist for each square in the mask.
        ///
        /// The args to the function should assume to be starting at index 1.
        pub fn addMovesFromMask(
            ml: *Movelist,
            mask: Bitboard,
            comptime function: anytype,
            args: anytype,
        ) void {
            var mask_copy = mask;
            while (mask_copy.nonzero()) {
                const from = mask_copy.popLsb();
                var generated: Bitboard = @call(.auto, function, .{from} ++ args);
                while (generated.nonzero()) {
                    const to = generated.popLsb();
                    ml.add(Move.make(from, to, .{}));
                }
            }
        }
    }.addMovesFromMask;

    if (comptime pieces.andU64(@intFromEnum(PieceGenType.king)).nonzero()) {
        const seen = movegen.seenSquares(options.color.opposite(), board, opp_empty);

        addMovesFromMask(movelist, Bitboard.fromSquare(king_sq), struct {
            pub fn afn(square: Square, seen_: Bitboard, moveable_square_: Bitboard) Bitboard {
                return kingMoves(square, seen_, moveable_square_);
            }
        }.afn, .{ seen, moveable_square });

        if (options.gen_type != .capture and checks == 0) {
            var moves_bb = castleMoves(
                board,
                king_sq,
                seen,
                pin_hv,
                .{ .color = options.color },
            );

            while (moves_bb.nonzero()) {
                const to = moves_bb.popLsb();
                movelist.add(Move.make(king_sq, to, .{ .move_type = .castling }));
            }
        }
    }

    // There can only be 2 checks in any legal position
    if (checks == 2) return;
    _ = moveable_square.andAssign(check_mask);

    // Add all the pieces to the movelist
    if (comptime pieces.andU64(@intFromEnum(PieceGenType.pawn)).nonzero()) {
        pawnMoves(
            board,
            movelist,
            check_mask,
            pin_hv,
            pin_d,
            occ_opp,
            .{ .color = options.color, .gen_type = options.gen_type },
        );
    }

    if (comptime pieces.andU64(@intFromEnum(PieceGenType.knight)).nonzero()) {
        // Remove any pinned knights
        const knights_mask = board.pieces(
            options.color,
            .knight,
        ).andBB(pin_d.orBB(pin_hv).not());

        addMovesFromMask(movelist, knights_mask, struct {
            pub fn afn(square: Square, moveable_square_: Bitboard) Bitboard {
                return knightMoves(square).andBB(moveable_square_);
            }
        }.afn, .{moveable_square});
    }

    if (comptime pieces.andU64(@intFromEnum(PieceGenType.bishop)).nonzero()) {
        // Remove any horizontally/vertically pinned bishops
        const bishops_mask = board.pieces(
            options.color,
            .bishop,
        ).andBB(pin_hv.not());

        addMovesFromMask(movelist, bishops_mask, struct {
            pub fn afn(
                square: Square,
                pin_d_: Bitboard,
                occ_all_: Bitboard,
                moveable_square_: Bitboard,
            ) Bitboard {
                return bishopMoves(
                    square,
                    pin_d_,
                    occ_all_,
                ).andBB(moveable_square_);
            }
        }.afn, .{ pin_d, occ_all, moveable_square });
    }

    if (comptime pieces.andU64(@intFromEnum(PieceGenType.rook)).nonzero()) {
        // Remove any diagonally pinned rooks
        const rooks_mask = board.pieces(
            options.color,
            .rook,
        ).andBB(pin_d.not());

        addMovesFromMask(movelist, rooks_mask, struct {
            pub fn afn(
                square: Square,
                pin_hv_: Bitboard,
                occ_all_: Bitboard,
                moveable_square_: Bitboard,
            ) Bitboard {
                return rookMoves(
                    square,
                    pin_hv_,
                    occ_all_,
                ).andBB(moveable_square_);
            }
        }.afn, .{ pin_hv, occ_all, moveable_square });
    }

    if (comptime pieces.andU64(@intFromEnum(PieceGenType.queen)).nonzero()) {
        // Only remove queens who are pinned twice
        const queens_mask = board.pieces(
            options.color,
            .queen,
        ).andBB(pin_d.andBB(pin_hv).not());

        addMovesFromMask(movelist, queens_mask, struct {
            pub fn afn(
                square: Square,
                pin_d_: Bitboard,
                pin_hv_: Bitboard,
                occ_all_: Bitboard,
                moveable_square_: Bitboard,
            ) Bitboard {
                return queenMoves(
                    square,
                    pin_d_,
                    pin_hv_,
                    occ_all_,
                ).andBB(moveable_square_);
            }
        }.afn, .{ pin_d, pin_hv, occ_all, moveable_square });
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

test "King and castling move generation" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{
        .fen = "1nbqkb1r/Pp3p2/2r2n2/2p1p2P/1PPp2PN/2N1Q2p/1BP1P1B1/R3K2R w KQk - 0 1",
    });

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    // Basic king moves from position
    try expectEqual(10280, kingMoves(
        .e1,
        Bitboard.fromInt(u64, 9006917425330126912),
        Bitboard.fromInt(u64, 18446462045653805422),
    ).bits);

    // Both castling options available
    try expectEqual(129, castleMoves(
        board,
        .e1,
        Bitboard.fromInt(u64, 9006917425330143232),
        Bitboard.fromInt(u64, 0),
        .{ .color = .white },
    ).bits);

    // Doesn't have the right on queen side
    try expect(try board.setFen("1nbqkb1r/Pp3p2/2r2n2/2p1p2P/1PPp2PN/2N1Q2p/1BP1P1B1/R3K2R w Kk - 0 1", true));
    try expectEqual(128, castleMoves(
        board,
        .e1,
        Bitboard.fromInt(u64, 9006917425330143232),
        Bitboard.fromInt(u64, 0),
        .{ .color = .white },
    ).bits);

    // King side path is blocked for black
    try expect(try board.setFen("r3kb1r/Ppq2p2/1n1b1n2/2p1p2P/1PPp2PN/4Q2p/1BP1P1B1/RN2K2R b KQkq - 0 1", true));
    try expectEqual(72057594037927936, castleMoves(
        board,
        .e8,
        Bitboard.fromInt(u64, 145177312985348607),
        Bitboard.fromInt(u64, 4521260802375680),
        .{ .color = .black },
    ).bits);

    // FRC both castling
    try expect(try board.setFischerRandom(true));
    try expect(try board.setFen("rbnnbkrq/pp1p1ppp/2p1p3/8/6Q1/N1NBB3/PPPPPPPP/R4KR1 w AGag - 0 1", true));
    try expectEqual(65, castleMoves(
        board,
        .f1,
        Bitboard.fromInt(u64, 17509994501354061824),
        Bitboard.fromInt(u64, 0),
        .{ .color = .white },
    ).bits);

    // FRC can only castle one side due to pin on king side
    try expect(try board.setFen("qnrkbn1b/pppppppp/8/8/8/3BN1B1/PPPPPPPP/QNRK2Rr w CGcg - 0 1", true));
    try expectEqual(4, castleMoves(
        board,
        .d1,
        Bitboard.fromInt(u64, 2233784315664171072),
        Bitboard.fromInt(u64, 240),
        .{ .color = .white },
    ).bits);
}

test "Bishop move generation" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{
        .fen = "rnbqkb1r/Pp3p2/5n2/2p5/1P1ppPP1/3PQN2/2P1P1pp/RNB1KB1R b KQkq - 0 1",
    });

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    const bishop_mid_c8 = bishopMoves(
        .c8,
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 13772887289031611575),
    );
    const bishop_mid_f8 = bishopMoves(
        .f8,
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 13772887289031611575),
    );

    const bishop_mid_actual: [2]Bitboard = .{ bishop_mid_c8, bishop_mid_f8 };
    const bishop_mid_expected: [2]u64 = .{ 2832480465846272, 22667548898099200 };
    for (bishop_mid_expected, bishop_mid_actual) |bb_e, bb_a| {
        try expectEqual(bb_e, bb_a.bits);
    }
}

test "Rook move generation" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{
        .fen = "rnbqkb1r/Pp3p2/5n2/2p5/1P1ppPP1/3PQN2/2P1P1pp/RNB1KB1R b KQkq - 0 1",
    });

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    const rook_mid_a8 = rookMoves(
        .a8,
        Bitboard.fromInt(u64, 4521260802375680),
        Bitboard.fromInt(u64, 13772887289031611575),
    );
    const rook_mid_h8 = rookMoves(
        .h8,
        Bitboard.fromInt(u64, 4521260802375680),
        Bitboard.fromInt(u64, 13772887289031611575),
    );

    const rook_mid_actual: [2]Bitboard = .{ rook_mid_a8, rook_mid_h8 };
    const rook_mid_expected: [2]u64 = .{ 144396663052566528, 6953699114060120064 };
    for (rook_mid_expected, rook_mid_actual) |bb_e, bb_a| {
        try expectEqual(bb_e, bb_a.bits);
    }
}

test "Queen move generation" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{
        .fen = "1nbqkb1r/Pp3p2/2r2n2/2p1p2P/1PPp2PN/4Q3/2P1P1pp/RNB1KB1R w KQk - 0 1",
    });

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    const queen_mid = queenMoves(
        .e3,
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 0),
        Bitboard.fromInt(u64, 13700834712922150071),
    );

    try expectEqual(141082040940612, queen_mid.bits);
}

test "PieceGenType compile time computation" {
    const pawns = comptime PieceGenType.pts2bb(&[_]PieceType{.pawn});
    try expectEqual(@intFromEnum(PieceGenType.pawn), pawns.bits);

    const all_types = comptime PieceGenType.pts2bb(&AllPieces);
    try expectEqual(63, all_types.bits);
}

test "Generate all legal moves" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    // Legal moves from starting position
    var ml = Movelist{};
    all(
        board,
        &ml,
        .{
            .color = .white,
            .gen_type = .all,
            .pieces = &AllPieces,
        },
    );
    try expectEqual(20, ml.size);

    const expected_starting: [20]u16 = .{
        528, 593, 658, 723, 788, 853, 918, 983,
        536, 601, 666, 731, 796, 861, 926, 991,
        80,  82,  405, 407,
    };
    for (expected_starting, ml.slice(20)) |expected, move| {
        try expectEqual(expected, move.move);
    }

    // Position from https://www.chessprogramming.org/Perft_Results
    ml.reset();
    try expect(try board.setFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ", true));
    all(
        board,
        &ml,
        .{
            .color = .white,
            .gen_type = .all,
            .pieces = &AllPieces,
        },
    );
    try expectEqual(48, ml.size);

    const expected_mid: [48]u16 = .{
        259,  261,  49408, 49415, 919,  2284, 528,  593,
        918,  2283, 536,   926,   1153, 1155, 1176, 1185,
        2323, 2330, 2334,  2346,  2350, 2355, 2357, 706,
        724,  733,  742,   751,   771,  773,  787,  794,
        801,  808,  1,     2,     3,    453,  454,  1363,
        1364, 1366, 1367,  1373,  1374, 1381, 1383, 1389,
    };
    for (expected_mid, ml.slice(48)) |expected, move| {
        try expectEqual(expected, move.move);
    }

    // Same position, but only quiet moves for white
    ml.reset();
    all(
        board,
        &ml,
        .{
            .color = .white,
            .gen_type = .quiet,
            .pieces = &AllPieces,
        },
    );
    try expectEqual(40, ml.size);

    const expected_mid_white_quiets: [40]u16 = .{
        259,  261,  49408, 49415, 528,  593,  918,  2283,
        536,  926,  1153,  1155,  1176, 1185, 2323, 2330,
        2334, 2346, 706,   724,   733,  742,  751,  771,
        773,  787,  794,   801,   1,    2,    3,    453,
        454,  1363, 1364,  1366,  1373, 1374, 1381, 1383,
    };
    for (expected_mid_white_quiets, ml.slice(40)) |expected, move| {
        try expectEqual(expected, move.move);
    }

    // Same position, but only captures and for black
    ml.reset();
    all(
        board,
        &ml,
        .{
            .color = .black,
            .gen_type = .capture,
            .pieces = &AllPieces,
        },
    );
    try expectEqual(7, ml.size);

    const expected_mid_black_captures: [7]u16 = .{
        1618, 1486, 2851, 2659, 2908, 2915, 2572,
    };
    for (expected_mid_black_captures, ml.slice(7)) |expected, move| {
        try expectEqual(expected, move.move);
    }

    // FRC Position for black
    ml.reset();
    try expect(try board.setFischerRandom(true));
    try expect(try board.setFen("1rqbkrbn/1ppppp1p/1n6/p1N3p1/8/2P4P/PP1PPPP1/1RQBKRBN w FBfb - 0 9", true));
    all(
        board,
        &ml,
        .{
            .color = .black,
            .gen_type = .all,
            .pieces = &AllPieces,
        },
    );
    try expectEqual(17, ml.size);

    const expected_frc: [17]u16 = .{
        2072, 2462, 3242, 3307, 3372, 3437, 3567, 3299,
        3364, 3429, 3559, 2648, 2650, 2659, 2680, 4078,
        3704,
    };
    for (expected_frc, ml.slice(17)) |expected, move| {
        try expectEqual(expected, move.move);
    }
}
