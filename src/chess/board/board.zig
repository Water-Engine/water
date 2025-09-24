const std = @import("std");

const bitboard = @import("../core/bitboard.zig");
const Bitboard = bitboard.Bitboard;

const distance = @import("../core/distance.zig");

const types = @import("../core/types.zig");
const Color = types.Color;
const Square = types.Square;
const File = types.File;
const Rank = types.Rank;

const piece_ = @import("../core/piece.zig");
const Piece = piece_.Piece;
const PieceType = piece_.PieceType;

const move = @import("../core/move.zig");
const MoveType = move.MoveType;
const Move = move.Move;

const castling = @import("castling.zig");
const CastlingRights = castling.CastlingRights;

const state = @import("state.zig");
const Zobrist = state.Zobrist;
const State = state.State;

const attacks = @import("../movegen/attacks.zig");
pub const Attacks = attacks.Attacks;

pub const StartingFen: []const u8 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

fn split_fen_string(comptime N: usize, fen: []const u8, delimiter: u8) [N]?[]const u8 {
    var out: [N]?[]const u8 = @splat(null);
    var filled: usize = 0;

    var spliterator = std.mem.splitScalar(u8, fen, delimiter);
    while (spliterator.next()) |entry| : (filled += 1) {
        if (filled >= N) break;
        out[filled] = entry;
    }

    return out;
}

/// A chess board representation, valid for standard chess only.
///
/// The internal 'original_fen' and 'previous_states' are heap allocated.
/// They are assumed to be owned by the instance and are freed with deinit.
/// Directly assigning values to these fields is unsafe.
pub const Board = struct {
    allocator: std.mem.Allocator,

    original_fen: []const u8,
    previous_states: std.ArrayList(State),

    pieces_bbs: [6]Bitboard = @splat(Bitboard.init()),
    occ_bbs: [2]Bitboard = @splat(Bitboard.init()),
    mailbox: [64]Piece = @splat(Piece.init()),

    key: u64 = 0,
    castling_rights: CastlingRights = .{},
    plies: u16 = 0,
    side_to_move: Color = .white,
    ep_square: Square = .none,
    halfmove_clock: u8 = 0,

    castling_path: [2][2]Bitboard = @splat(@splat(Bitboard.init())),

    pub fn init(allocator: std.mem.Allocator, fen: []const u8) !*Board {
        const b = try allocator.create(Board);
        b.* = .{
            .allocator = allocator,
            .original_fen = try allocator.dupe(u8, fen),
            .previous_states = try std.ArrayList(State).initCapacity(allocator, 256),
        };
        _ = try b.setFen(fen, false);
        return b;
    }

    pub fn deinit(self: *Board) void {
        self.previous_states.deinit(self.allocator);
        self.allocator.free(self.original_fen);
    }

    /// Performs a deep copy of the board.
    ///
    /// Allocations are handled by the provided allocator only.
    pub fn clone(self: *const Board, allocator: std.mem.Allocator) !*Board {
        const b = try allocator.create(Board);
        b.* = .{
            .allocator = allocator,

            .original_fen = try allocator.dupe(u8, self.original_fen),
            .previous_states = try self.previous_states.clone(allocator),

            .pieces_bbs = self.pieces_bbs,
            .occ_bbs = self.occ_bbs,
            .mailbox = self.mailbox,

            .key = self.key,
            .castling_rights = self.castling_rights,
            .plies = self.plies,
            .side_to_move = self.side_to_move,
            .ep_square = self.ep_square,
            .halfmove_clock = self.halfmove_clock,

            .castling_path = self.castling_path,
        };
        return b;
    }

    pub fn reset(self: *Board) void {
        self.previous_states.clearRetainingCapacity();

        self.pieces_bbs = @splat(Bitboard.init());
        self.occ_bbs = @splat(Bitboard.init());
        self.mailbox = @splat(Piece.none);

        self.key = 0;
        self.castling_rights.clear();
        self.plies = 1;
        self.side_to_move = .white;
        self.ep_square = .none;
        self.halfmove_clock = 0;
    }

    /// Attempts to set the board fen position, reallocating the board original fen representation if requested.
    ///
    /// Returns `true` if the fen was set successfully
    pub fn setFen(self: *Board, fen: []const u8, reallocate_fen: bool) !bool {
        self.reset();
        if (reallocate_fen) {
            self.allocator.free(self.original_fen);
            self.original_fen = try self.allocator.dupe(u8, fen);
        }

        var success: bool = true;
        const trimmed = std.mem.trim(u8, fen, " ");
        if (trimmed.len == 0) success = false;

        // Fully parse and deconstruct input
        const split_fen: [6]?[]const u8 = split_fen_string(6, trimmed, ' ');
        const pos: []const u8 = if (split_fen[0]) |first| first else "";
        const stm: []const u8 = if (split_fen[1]) |first| first else "w";
        const castle: []const u8 = if (split_fen[2]) |first| first else "-";
        const ep: []const u8 = if (split_fen[3]) |first| first else "-";
        const hmc: []const u8 = if (split_fen[4]) |first| first else "0";
        const fmc: []const u8 = if (split_fen[5]) |first| first else "1";

        if (pos.len == 0) success = false;
        if (!std.mem.eql(u8, stm, "w") and !std.mem.eql(u8, stm, "b")) success = false;

        self.halfmove_clock = std.fmt.parseInt(u8, hmc, 10) catch 0;
        self.plies = std.fmt.parseInt(u16, fmc, 10) catch 1;
        self.plies = self.plies * 2 - 2;

        if (!std.mem.eql(u8, ep, "-")) {
            const sq = Square.fromStr(ep);
            if (!sq.valid()) success = false;

            self.ep_square = sq;
        }

        self.side_to_move = if (std.mem.eql(u8, stm, "w")) .white else .black;
        if (self.side_to_move.isBlack()) {
            self.plies += 1;
        } else {
            self.key ^= Zobrist.sideToMove();
        }

        // Set all piece positions
        var square_idx: usize = 56;
        for (pos) |char| {
            if (std.ascii.isDigit(char)) {
                square_idx += (char - '0');
            } else if (char == '/') {
                square_idx -= 16;
            } else {
                const piece = Piece.fromChar(char);
                const square = Square.fromInt(usize, square_idx);
                if (!piece.valid() or !square.valid() or self.at(Piece, square) != .none) {
                    success = false;
                }

                self.placePiece(piece, square);
                self.key ^= Zobrist.piece(piece, square);
                square_idx += 1;
            }
        }

        // Set all castling rights
        for (castle) |char| {
            if (char == '-') break;

            switch (char) {
                'K' => self.castling_rights.set(.white, .king, .fh),
                'Q' => self.castling_rights.set(.white, .queen, .fa),
                'k' => self.castling_rights.set(.black, .king, .fh),
                'q' => self.castling_rights.set(.black, .queen, .fa),
                else => success = false,
            }
        }

        self.key ^= Zobrist.castling(self.castling_rights.hash());

        // Verify the en passant square
        const white_ep = self.side_to_move.isWhite() and self.ep_square.rank() == .r6;
        const black_ep = self.side_to_move.isBlack() and self.ep_square.rank() == .r3;
        if (self.ep_square.valid() and !(white_ep or black_ep)) {
            self.ep_square = .none;
        }

        if (self.ep_square.valid()) {
            // TODO: Ensure ep square is valid with the context of the given position
            const valid = true;

            if (!valid) self.ep_square = .none else self.key ^= Zobrist.enPassant(self.ep_square.file());
        }

        std.debug.assert(self.key == Zobrist.fromBoard(self));

        // Set castling path
        for ([_]Color{ .white, .black }) |color| {
            const king_from = self.kingSq(color);

            for ([_]CastlingRights.Side{ .king, .queen }) |side| {
                if (!self.castling_rights.hasSide(color, side)) continue;

                const rook_from = Square.make(
                    king_from.rank(),
                    self.castling_rights.rookFile(color, side),
                );

                const king_to = Square.castlingKingTo(side, color);
                const rook_to = Square.castlingRookTo(side, color);

                const rook_distance_bb = distance.SquaresBetween[rook_from.index()][rook_to.index()];
                const king_distance_bb = distance.SquaresBetween[king_from.index()][king_to.index()];
                const distance_between_bbs = rook_distance_bb.orBB(king_distance_bb);

                const king_from_bb = Bitboard.fromSquare(king_from);
                const rook_from_bb = Bitboard.fromSquare(rook_from);
                const from_bbs = king_from_bb.orBB(rook_from_bb).not();

                self.castling_path[color.index()][side.index()] = distance_between_bbs.andBB(from_bbs);
            }
        }

        return success;
    }

    /// Returns the specified piece bitboard, use Color.none for side agnostic bitboard.
    pub fn pieces(self: *const Board, color: Color, piece_type: PieceType) Bitboard {
        std.debug.assert(piece_type.valid());
        return if (color == .none) blk: {
            break :blk self.pieces_bbs[piece_type.index()];
        } else blk: {
            break :blk self.pieces_bbs[piece_type.index()].andBB(self.occ_bbs[color.index()]);
        };
    }

    /// Returns the Piece or PieceType at the given square.
    pub fn at(self: *const Board, comptime T: type, square: Square) T {
        if (T != Piece and T != PieceType) @compileError("T must be of type Piece or PieceType");
        std.debug.assert(square.valid());

        const piece_at = self.mailbox[square.index()];
        return if (T == PieceType) piece_at.asType() else piece_at;
    }

    /// Raw piece set without respect for rules.
    fn placePiece(self: *Board, piece: Piece, square: Square) void {
        std.debug.assert(square.valid() and self.mailbox[square.index()] == .none);

        const pt = piece.asType();
        const color = piece.color();
        const index = square.index();

        std.debug.assert(pt != .none);
        std.debug.assert(color != .none);

        _ = self.pieces_bbs[pt.index()].set(index);
        _ = self.occ_bbs[color.index()].set(index);
        self.mailbox[index] = piece;
    }

    /// Raw piece removal without respect for rules.
    fn removePiece(self: *Board, piece: Piece, square: Square) void {
        std.debug.assert(piece != .none);
        std.debug.assert(square.valid() and self.mailbox[square.index()] == piece);

        const pt = piece.asType();
        const color = piece.color();
        const index = square.index();

        std.debug.assert(pt != .none);
        std.debug.assert(color != .none);

        _ = self.pieces_bbs[pt.index()].remove(index);
        _ = self.occ_bbs[color.index()].remove(index);
        self.mailbox[index] = .none;
    }

    pub fn kingSq(self: *const Board, color: Color) Square {
        std.debug.assert(color.valid() and self.pieces(color, .king).bits != 0);
        return self.pieces(color, .king).lsb();
    }

    /// Get the occupancy bitboard for the color.
    pub fn us(self: *const Board, color: Color) Bitboard {
        std.debug.assert(color.valid());
        return self.occ_bbs[color.index()];
    }

    /// Get the occupancy bitboard for the opposite color.
    pub fn them(self: *const Board, color: Color) Bitboard {
        return self.us(color.opposite());
    }

    /// Get the occupancy bitboard for both colors.
    ///
    /// Faster than calling all() or us(Color::WHITE) | us(Color::BLACK). Less indirection.
    pub fn occ(self: *const Board) Bitboard {
        return self.occ_bbs[0].orBB(self.occ_bbs[1]);
    }

    /// Returns the number of halfmoves as the given integer type.
    pub fn halfmoves(self: *const Board, comptime T: type) T {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @as(T, self.halfmove_clock),
            else => @compileError("T must be an integer type"),
        };
    }

    /// Returns the number of fullmoves as the given integer type.
    pub fn fullmoves(self: *const Board, comptime T: type) T {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => 1 + @divFloor(@as(T, @intCast(self.plies)), 2),
            else => @compileError("T must be an integer type"),
        };
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

test "Fen splitter" {
    const expected_smaller: [4][]const u8 = .{
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR",
        "w",
        "KQkq",
        "-",
    };
    const split_smaller = split_fen_string(4, StartingFen, ' ');

    try expect(expected_smaller.len == split_smaller.len);
    for (expected_smaller, split_smaller) |es, ss| {
        try expectEqualSlices(u8, es, ss.?);
    }

    const expected_exact: [6][]const u8 = .{
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR",
        "w",
        "KQkq",
        "-",
        "0",
        "1",
    };
    const split_exact = split_fen_string(6, StartingFen, ' ');

    try expect(expected_exact.len == split_exact.len);
    for (expected_exact, split_exact) |ee, se| {
        try expectEqualSlices(u8, ee, se.?);
    }

    const expected_larger: [8]?[]const u8 = .{
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR",
        "w",
        "KQkq",
        "-",
        "0",
        "1",
        null,
        null,
    };
    const split_larger = split_fen_string(8, StartingFen, ' ');

    try expect(expected_larger.len == split_larger.len);
    for (expected_larger, split_larger) |el, sl| {
        if (el) |el_unwrap| {
            if (sl) |sl_unwrap| {
                try expectEqualSlices(u8, el_unwrap, sl_unwrap);
            } else {
                try expect(false);
            }
        } else {
            try expect(el == null and sl == null);
        }
    }
}

test "Board initialization & copy from starting fen" {
    const allocator = testing.allocator;
    var parent = try Board.init(allocator, StartingFen);
    try expectEqualSlices(u8, StartingFen, parent.original_fen);
    var board = try parent.clone(allocator);

    parent.previous_states.appendAssumeCapacity(.{
        .hash = 0,
        .captured_piece = .none,
        .castling = .{},
        .enpassant = .none,
        .half_moves = 0,
    });
    try expect(parent.previous_states.items.len == 1);
    try expect(board.previous_states.items.len == 0);

    // Uninitialize test objects before proceeding
    parent.deinit();
    allocator.destroy(parent);
    defer {
        board.deinit();
        allocator.destroy(board);
    }

    try expectEqualSlices(u8, StartingFen, board.original_fen);
    try expect(board.previous_states.items.len == 0);

    // Verify agnostic piece bitboard setting
    const expected_pieces_bbs = [_]u64{
        71776119061282560,   4755801206503243842, 2594073385365405732,
        9295429630892703873, 576460752303423496,  1152921504606846992,
    };
    for (expected_pieces_bbs, board.pieces_bbs, 0..) |expected, bb, idx| {
        try expectEqual(expected, bb.bits);

        const current = Piece.fromInt(usize, idx);
        try expectEqual(
            expected,
            board.pieces(.none, current.asType()).bits,
        );
    }

    // Verify colored piece bitboard retrieval
    const expected_color_bbs = [2][6]u64{
        .{ 65280, 66, 36, 129, 8, 16 },
        .{
            71776119061217280,
            4755801206503243776,
            2594073385365405696,
            9295429630892703744,
            576460752303423488,
            1152921504606846976,
        },
    };
    for (expected_color_bbs, 0..) |expected, color_idx| {
        for (0..6) |piece_idx| {
            const color = Color.fromInt(usize, color_idx);
            const piece = Piece.fromInt(usize, piece_idx);

            try expectEqual(
                expected[piece_idx],
                board.pieces(color, piece.asType()).bits,
            );
        }
    }

    // Verify occupancy bitboards
    const expected_occs = [_]u64{ 65535, 18446462598732840960 };
    for (expected_occs, board.occ_bbs) |expected, bb| {
        try expectEqual(expected, bb.bits);
    }

    try expectEqual(expected_occs[0], board.us(.white).bits);
    try expectEqual(expected_occs[0], board.them(.black).bits);
    try expectEqual(expected_occs[1], board.us(.black).bits);
    try expectEqual(expected_occs[1], board.them(.white).bits);

    try expectEqual(expected_occs[0] | expected_occs[1], board.occ().bits);

    // Verify mailbox representation and placed piece correctness
    const expected_pieces = [_]Piece{
        .white_rook, .white_knight, .white_bishop, .white_queen, .white_king, .white_bishop, .white_knight, .white_rook,
        .white_pawn, .white_pawn,   .white_pawn,   .white_pawn,  .white_pawn, .white_pawn,   .white_pawn,   .white_pawn,
        .none,       .none,         .none,         .none,        .none,       .none,         .none,         .none,
        .none,       .none,         .none,         .none,        .none,       .none,         .none,         .none,
        .none,       .none,         .none,         .none,        .none,       .none,         .none,         .none,
        .none,       .none,         .none,         .none,        .none,       .none,         .none,         .none,
        .black_pawn, .black_pawn,   .black_pawn,   .black_pawn,  .black_pawn, .black_pawn,   .black_pawn,   .black_pawn,
        .black_rook, .black_knight, .black_bishop, .black_queen, .black_king, .black_bishop, .black_knight, .black_rook,
    };
    for (expected_pieces, board.mailbox, 0..) |expected, p, i| {
        try expectEqual(expected, p);
        try expectEqual(expected, board.at(Piece, Square.fromInt(usize, i)));
    }

    const expected_piece_types = [_]PieceType{
        .rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook,
        .pawn, .pawn,   .pawn,   .pawn,  .pawn, .pawn,   .pawn,   .pawn,
        .none, .none,   .none,   .none,  .none, .none,   .none,   .none,
        .none, .none,   .none,   .none,  .none, .none,   .none,   .none,
        .none, .none,   .none,   .none,  .none, .none,   .none,   .none,
        .none, .none,   .none,   .none,  .none, .none,   .none,   .none,
        .pawn, .pawn,   .pawn,   .pawn,  .pawn, .pawn,   .pawn,   .pawn,
        .rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook,
    };
    for (expected_piece_types, board.mailbox, 0..) |expected, p, i| {
        try expectEqual(expected, p.asType());
        try expectEqual(expected, board.at(PieceType, Square.fromInt(usize, i)));
    }

    try expectEqual(Square.e1, board.kingSq(.white));
    try expectEqual(Square.e8, board.kingSq(.black));

    // Verify state information
    try expectEqual(5060803636482931868, board.key);

    for (board.castling_rights.rooks) |rf| {
        try expectEqual(File.fa, rf[0]);
        try expectEqual(File.fh, rf[1]);
    }

    try expectEqual(0, board.halfmove_clock);
    try expectEqual(0, board.halfmoves(u8));
    try expectEqual(0, board.plies);
    try expectEqual(1, board.fullmoves(u8));

    try expectEqual(Color.white, board.side_to_move);
    try expectEqual(Square.none, board.ep_square);

    const expected_path = [_][2]u64{
        .{ 14, 96 },
        .{ 1008806316530991104, 6917529027641081856 },
    };
    for (expected_path, board.castling_path) |expected, c| {
        try expectEqual(expected[0], c[0].bits);
        try expectEqual(expected[1], c[1].bits);
    }
}
