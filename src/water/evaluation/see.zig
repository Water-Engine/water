const std = @import("std");
const water = @import("water");

const see_weight: [6]i32 = .{ 93, 308, 346, 521, 994, 20000 };

/// Perform a classical static exchange evaluation with the board's state and given move.
///
/// Logic adapted from https://github.com/SnowballSH/Avalanche
pub fn seeBase(board: *const water.Board, move: water.Move) i32 {
    var max_depth: usize = 0;
    var defenders = water.Bitboard.init();
    var piece_bb = water.Bitboard.init();

    const to = move.to();
    var occ = board.occ();
    var gains: [16]i32 = undefined;
    var them_color = board.side_to_move.opposite();
    var blockers = occ.andBB(water.Bitboard.fromSquare(to).not());

    const pt_to_idx = board.at(water.PieceType, move.to()).index();
    std.debug.assert(pt_to_idx < see_weight.len);
    gains[0] = see_weight[pt_to_idx];

    const pt_from_idx = board.at(water.PieceType, move.from()).index();
    std.debug.assert(pt_from_idx < see_weight.len);
    var last_piece_pts = see_weight[pt_from_idx];

    var depth: usize = 1;
    outer: while (depth < gains.len) : (depth += 1) {
        gains[depth] = last_piece_pts - gains[depth - 1];
        if (them_color.isWhite()) {
            defenders = board.us(.white).andBB(blockers);
        } else {
            defenders = board.us(.black).andBB(blockers);
        }

        const piece_type = water.PieceType.pawn.index();
        const ending = water.PieceType.king.index();

        for (piece_type..ending + 1) |pt_idx| {
            last_piece_pts = see_weight[pt_idx];
            const pt = water.PieceType.fromInt(usize, pt_idx);
            piece_bb = (if (pt == .pawn) blk: {
                break :blk water.attacks.pawn(them_color.opposite(), to);
            } else blk: {
                break :blk water.attacks.attacks(pt, .none, to, blockers);
            }).andBB(defenders).andBB(board.pieces(.none, pt));
            if (piece_bb.nonzero()) {
                _ = blockers.andAssign(water.Bitboard.fromSquare(piece_bb.lsb()).not());
                them_color = them_color.opposite();
                continue :outer;
            }
        }

        max_depth = depth;
        break;
    }

    // Propagate gains
    depth = max_depth - 1;
    while (depth >= 1) : (depth -= 1) {
        gains[depth - 1] = -@max(-gains[depth - 1], gains[depth]);
    }

    return gains[0];
}

/// Performs a shallow see to see if the exchange is still winning with respect to the threshold.
///
/// Logic adapted from https://github.com/TerjeKir/weiss and https://github.com/SnowballSH/Avalanche
pub fn seeThreshold(board: *const water.Board, move: water.Move, threshold: i32) bool {
    const from = move.from();
    const to = move.to();

    const attacker = board.at(water.PieceType, from);
    std.debug.assert(attacker.index() < see_weight.len);
    const victim = board.at(water.PieceType, to);
    std.debug.assert(victim.index() < see_weight.len);

    var swap = see_weight[victim.index()] - threshold;
    if (swap < 0) return false;
    swap -= see_weight[attacker.index()];
    if (swap >= 0) return true;

    const occ = board.occ();
    var relevant_occ = occ.xorBB(
        water.Bitboard.fromSquare(from),
    ).orBB(water.Bitboard.fromSquare(to));
    var attackers = water.attacks.attackers(
        board,
        .white,
        to,
        .{ .occupied = relevant_occ, .include_king = false },
    ).orBB(water.attacks.attackers(
        board,
        .black,
        to,
        .{ .occupied = relevant_occ, .include_king = false },
    )).andBB(relevant_occ);

    const bishops = board.sliders(.diag, .none);
    const rooks = board.sliders(.ortho, .none);

    var stm = board.at(water.Piece, from).color().opposite();
    while (true) {
        _ = attackers.andAssign(relevant_occ);
        const my_attackers = attackers.andBB(board.us(stm));
        if (my_attackers.empty()) break;

        var pt_idx: usize = 0;
        while (pt_idx <= 5) : (pt_idx += 1) {
            const pt = water.PieceType.fromInt(usize, pt_idx);
            const relevant_pieces = board.pieces(.none, pt);
            if (my_attackers.andBB(relevant_pieces).nonzero()) break;
        }

        stm = stm.opposite();
        std.debug.assert(pt_idx < see_weight.len);
        swap = -swap - 1 - see_weight[pt_idx];

        if (swap >= 0) {
            if (pt_idx == 5) {
                if (attackers.andBB(board.us(stm)).nonzero()) {
                    stm = stm.opposite();
                }
            }
            break;
        }

        const pt = water.PieceType.fromInt(usize, pt_idx);
        const relevant_pieces = board.pieces(.none, pt);
        const square_idx = my_attackers.andBB(relevant_pieces);
        _ = relevant_occ.xorAssign(water.Bitboard.fromSquare(square_idx.lsb()));

        if (pt == .pawn or pt == .bishop or pt == .queen) {
            _ = attackers.orAssign(water.attacks.bishop(to, relevant_occ).andBB(bishops));
        } else if (pt == .rook or pt == .queen) {
            _ = attackers.orAssign(water.attacks.rook(to, relevant_occ).andBB(rooks));
        }
    }

    return stm != board.at(water.Piece, from).color();
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "Base static exchange evaluation" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{
        .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ",
    });
    defer board.deinit();

    // White to move
    const white_captures = [_][]const u8{ "e5f7", "e2a6", "f3f6" };
    const expected_white_evals = [_]i32{ 93, 346, -686 };
    for (white_captures, expected_white_evals) |capture, expected| {
        const move = water.uci.uciToMove(board, capture);
        const actual = seeBase(board, move);
        try expectEqual(expected, actual);
    }

    // Black to move
    try expect(try board.setFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R b KQkq - ", true));
    const black_captures = [_][]const u8{ "f6e4", "e6d5", "a6e2" };
    const expected_black_evals = [_]i32{ -215, 93, 0 };
    for (black_captures, expected_black_evals) |capture, expected| {
        const move = water.uci.uciToMove(board, capture);
        const actual = seeBase(board, move);
        try expectEqual(expected, actual);
    }
}

test "Threshold based static exchange evaluation" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{
        .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ",
    });
    defer board.deinit();

    // White to move
    const white_captures = [_][]const u8{ "e5f7", "e2a6", "f3f6" };
    const expected_white_evals = [_]bool{ false, true, false };
    for (white_captures, expected_white_evals) |capture, expected| {
        const move = water.uci.uciToMove(board, capture);
        const actual = seeThreshold(board, move, 30);
        try expectEqual(expected, actual);
    }

    // Black to move
    try expect(try board.setFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R b KQkq - ", true));
    const black_captures = [_][]const u8{ "f6e4", "e6d5", "a6e2" };
    const expected_black_evals = [_]bool{ false, true, true };
    for (black_captures, expected_black_evals) |capture, expected| {
        const move = water.uci.uciToMove(board, capture);
        const actual = seeThreshold(board, move, -90);
        try expectEqual(expected, actual);
    }
}
