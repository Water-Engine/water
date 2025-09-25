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

/// Splits a string at the given delimiter, with the output array size `N`.
///
/// The result is guaranteed to be of size N, and is packed with null if the parts are too short.
fn splitString(comptime N: usize, fen: []const u8, delimiter: u8) [N]?[]const u8 {
    var out: [N]?[]const u8 = @splat(null);
    var filled: usize = 0;

    var spliterator = std.mem.splitScalar(u8, fen, delimiter);
    while (spliterator.next()) |entry| : (filled += 1) {
        if (filled >= N) break;
        out[filled] = entry;
    }

    return out;
}

/// Returns the slice immediately after the given entry in the iterator.
///
/// Mutates the iterator internally, resetting it before returning.
fn entryAfter(
    comptime delimiter_type: std.mem.DelimiterType,
    spliterator: *std.mem.SplitIterator(u8, delimiter_type),
    entry: []const u8,
) ?[]const u8 {
    defer spliterator.reset();

    while (spliterator.next()) |slice| {
        if (std.mem.eql(u8, entry, slice)) {
            return spliterator.next();
        }
    }

    return null;
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
    plies: usize = 0,
    side_to_move: Color = .white,
    ep_square: Square = .none,
    halfmove_clock: usize = 0,
    fischer_random: bool = false,

    castling_path: [2][2]Bitboard = @splat(@splat(Bitboard.init())),

    /// Create a board initialized with the given fen. Initialization is unchecked.
    /// Init calls should not be directly used with user input.
    ///
    /// Copies the provided fen and manages the dupe.
    pub fn init(allocator: std.mem.Allocator, options: struct {
        fen: []const u8 = StartingFen,
        fischer_random: bool = false,
    }) !*Board {
        const b = try allocator.create(Board);
        b.* = .{
            .allocator = allocator,
            .original_fen = try allocator.dupe(u8, options.fen),
            .previous_states = try std.ArrayList(State).initCapacity(allocator, 256),
            .fischer_random = options.fischer_random,
        };
        _ = try b.setFen(options.fen, false);
        return b;
    }

    /// Deinitializes the state history and frees the fen string.
    ///
    /// THe Board pointer itself must be freed separately.
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
            .fischer_random = self.fischer_random,

            .castling_path = self.castling_path,
        };
        return b;
    }

    /// Resets the Board's fields without explicitly freeing memory.
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

    /// Enables or disables the fischer random variant for the board.
    ///
    /// Ensures the internal fen is updated accordingly.
    pub fn setFischerRandom(self: *Board, fischer_random: bool) void {
        self.fischer_random = fischer_random;
        self.setFen(self.original_fen, false);
    }

    /// Attempts to set the board fen position, reallocating the board original fen representation if requested.
    ///
    /// Returns `true` if the fen was set successfully. Unsuccessful setting does not mutate the Board.
    pub fn setFen(self: *Board, fen: []const u8, reallocate_fen: bool) !bool {
        var backup = try self.clone(self.allocator);
        self.reset();
        if (reallocate_fen) {
            self.allocator.free(self.original_fen);
            self.original_fen = try self.allocator.dupe(u8, fen);
        }

        var success: bool = true;
        const trimmed = std.mem.trim(u8, fen, " ");
        if (trimmed.len == 0) success = false;

        // Fully parse and deconstruct input
        const split_fen: [6]?[]const u8 = splitString(6, trimmed, ' ');
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

                self.placePieceNAssert(piece, square) catch {
                    success = false;
                    break;
                };

                self.key ^= Zobrist.piece(piece, square);
                square_idx += 1;
            }
        }

        // In chess 960, we may need to determine rights based off of files
        const find_rook = struct {
            fn find_rook(board: *const Board, side: CastlingRights.Side, color: Color) File {
                const king_side = side == .king;
                const king_sq = board.kingSq(color);
                const square: Square = if (king_side) .h1 else .a1;
                const sq_corner = square.flipRelative(color);
                const start = if (king_side) king_sq.next() else king_sq.prev();

                var sq = start;
                while (if (king_side) sq.lteq(sq_corner) else sq.gteq(sq_corner)) : (if (king_side) {
                    _ = sq.inc();
                } else {
                    _ = sq.dec();
                }) {
                    if (board.at(PieceType, sq) == .rook and board.at(Piece, sq).color() == color) {
                        return sq.file();
                    }
                }

                return .none;
            }
        }.find_rook;

        // The file API uses a const pointer, so we need to wrap it
        const file_gt = struct {
            fn gt(lhs: File, rhs: File) bool {
                return lhs.gt(rhs);
            }
        }.gt;

        // Set all castling rights
        for (castle) |char| {
            if (char == '-') break;

            if (!self.fischer_random) {
                switch (char) {
                    'K' => self.castling_rights.set(.white, .king, .fh),
                    'Q' => self.castling_rights.set(.white, .queen, .fa),
                    'k' => self.castling_rights.set(.black, .king, .fh),
                    'q' => self.castling_rights.set(.black, .queen, .fa),
                    else => success = false,
                }

                continue;
            }

            // The location of the rooks are important for fischer random
            const color: Color = if (std.ascii.isUpper(char)) .white else .black;
            const king_sq = self.kingSq(color);

            if (char == 'K' or char == 'k') {
                const file = find_rook(self, .king, color);
                if (!file.valid()) success = false;
                self.castling_rights.set(color, .king, file);
            } else if (char == 'Q' or char == 'q') {
                const file = find_rook(self, .queen, color);
                if (!file.valid()) success = false;
                self.castling_rights.set(color, .queen, file);
            } else {
                const file = File.fromChar(char);
                if (!file.valid()) success = false;
                const side = CastlingRights.closestSide(File, file, king_sq.file(), file_gt);
                self.castling_rights.set(color, side, file);
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
            const king_from = self.kingSqNAssert(color) catch {
                success = false;
                break;
            };

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

        // TODO: Verify position as per https://chess.stackexchange.com/questions/1482/how-do-you-know-when-a-fen-position-is-legal

        if (!success) {
            self.deinit();
            self.* = .{
                .allocator = backup.allocator,

                .original_fen = try backup.allocator.dupe(u8, backup.original_fen),
                .previous_states = try backup.previous_states.clone(backup.allocator),

                .pieces_bbs = backup.pieces_bbs,
                .occ_bbs = backup.occ_bbs,
                .mailbox = backup.mailbox,

                .key = backup.key,
                .castling_rights = backup.castling_rights,
                .plies = backup.plies,
                .side_to_move = backup.side_to_move,
                .ep_square = backup.ep_square,
                .halfmove_clock = backup.halfmove_clock,
                .fischer_random = backup.fischer_random,

                .castling_path = backup.castling_path,
            };
        }
        backup.deinit();
        self.allocator.destroy(backup);

        return success;
    }

    /// Constructs a fen string based on the board's current state.
    /// The board's original fen can be accessed directly.
    ///
    /// The caller is responsible for freeing the string.
    pub fn getFen(self: *const Board, move_counters: bool) ![]const u8 {
        var fen_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 100);
        defer fen_buffer.deinit(self.allocator);

        // Loop through the ranks in reverse order for proper reconstruction from mailbox
        var rank: usize = 7;
        while (rank >= 0) : (rank -= 1) {
            var free_space: usize = 0;

            for (0..8) |file| {
                const square = Square.fromInt(usize, rank * 8 + file);
                const piece = self.at(Piece, square);

                if (piece.valid()) {
                    if (free_space != 0) {
                        try fen_buffer.print(self.allocator, "{d}", .{free_space});
                        free_space = 0;
                    }

                    try fen_buffer.append(self.allocator, piece.asChar());
                } else {
                    free_space += 1;
                }
            }

            if (free_space != 0) {
                try fen_buffer.print(self.allocator, "{d}", .{free_space});
            }

            if (rank == 0) {
                break;
            } else {
                try fen_buffer.append(self.allocator, '/');
            }
        }

        // Append side to move information
        try fen_buffer.append(self.allocator, ' ');
        try fen_buffer.append(self.allocator, self.side_to_move.asChar());

        // Append castling rights
        try fen_buffer.append(self.allocator, ' ');
        if (self.fischer_random) {
            for ([_]Color{ .white, .black }) |color| {
                for ([_]CastlingRights.Side{ .king, .queen }) |side| {
                    if (self.castling_rights.hasSide(color, side)) {
                        const file = self.castling_rights.rookFile(color, side).asChar();
                        const file_sided = if (color == .white) blk: {
                            break :blk std.ascii.toUpper(file);
                        } else file;
                        try fen_buffer.append(self.allocator, file_sided);
                    }
                }
            }
        } else if (self.castling_rights.empty()) {
            try fen_buffer.append(self.allocator, '-');
        } else {
            try fen_buffer.appendSlice(self.allocator, self.castling_rights.asStr());
        }

        // Append the en passant square
        try fen_buffer.append(self.allocator, ' ');
        if (self.ep_square.valid()) {
            try fen_buffer.appendSlice(self.allocator, self.ep_square.asStr());
        } else {
            try fen_buffer.append(self.allocator, '-');
        }

        // Append the move counters if requested
        if (move_counters) {
            try fen_buffer.append(self.allocator, ' ');
            try fen_buffer.print(self.allocator, "{d}", .{self.halfmoves(u8)});
            try fen_buffer.append(self.allocator, ' ');
            try fen_buffer.print(self.allocator, "{d}", .{self.fullmoves(u8)});
        }

        return try fen_buffer.toOwnedSlice(self.allocator);
    }

    /// Attempts to set the board's position from an epd string.
    ///
    /// Returns `true` if the fen was set successfully. Unsuccessful setting does not mutate the Board.
    pub fn setEpd(self: *Board, epd: []const u8) !bool {
        var parts = std.mem.splitScalar(u8, epd, ' ');

        var size: usize = 0;
        while (parts.next()) |_| : (size += 1) {}
        if (size < 4) return false;
        parts.reset();

        // Parse the clocks with reasonable defaults, ignoring a trailing semicolon if present
        var half_moves: usize = 0;
        var full_moves: usize = 1;

        const hmvc = entryAfter(.scalar, &parts, "hmvc");
        if (hmvc) |num| {
            half_moves = std.fmt.parseInt(
                usize,
                if (num[num.len - 1] == ';') num[0 .. num.len - 1] else num,
                10,
            ) catch 0;
        }

        const fmvn = entryAfter(.scalar, &parts, "fmvn");
        if (fmvn) |num| {
            full_moves = std.fmt.parseInt(
                usize,
                if (num[num.len - 1] == ';') num[0 .. num.len - 1] else num,
                10,
            ) catch 1;
        }

        const fen = try std.fmt.allocPrint(
            self.allocator,
            "{s} {s} {s} {s} {d} {d}",
            .{ parts.next().?, parts.next().?, parts.next().?, parts.next().?, half_moves, full_moves },
        );
        defer self.allocator.free(fen);

        return try self.setFen(fen, true);
    }

    /// Constructs an epd string based on the board's current state.
    ///
    /// The caller is responsible for freeing the string.
    pub fn getEpd(self: *Board) ![]const u8 {
        const fen = try self.getFen(false);
        defer self.allocator.free(fen);

        return try std.fmt.allocPrint(
            self.allocator,
            "{s} hmvc {d}; fmvn {d};",
            .{ fen, self.halfmoves(usize), self.fullmoves(usize) },
        );
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

    /// For internal use only, opts for errors instead of assertions for explicit handling.
    fn placePieceNAssert(self: *Board, piece: Piece, square: Square) !void {
        var success = true;
        if (!(square.valid() and self.mailbox[square.index()] == .none)) success = false;

        const pt = piece.asType();
        const color = piece.color();
        const index = square.index();

        if (pt == .none) success = false;
        if (color == .none) success = false;

        if (!success) return types.ChessError.IllegalFenState;

        _ = self.pieces_bbs[pt.index()].set(index);
        _ = self.occ_bbs[color.index()].set(index);
        self.mailbox[index] = piece;
    }

    /// Raw piece removal without respect for rules.
    ///
    /// Asserts that the requested piece and square are valid (presence checked as well).
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

    /// Returns the square of the king of the current color.
    ///
    /// Asserts that there is a king for the given color.
    pub fn kingSq(self: *const Board, color: Color) Square {
        std.debug.assert(color.valid() and self.pieces(color, .king).bits != 0);
        return self.pieces(color, .king).lsb();
    }

    /// For internal use only, opts for errors instead of assertions for explicit handling.
    fn kingSqNAssert(self: *const Board, color: Color) !Square {
        if (!(color.valid() and self.pieces(color, .king).bits != 0)) {
            return types.ChessError.IllegalFenState;
        }
        return self.pieces(color, .king).lsb();
    }

    /// Get the occupancy bitboard for the color.
    ///
    /// Asserts that the color is a valid color
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
            .int, .comptime_int => @as(T, @intCast(self.halfmove_clock)),
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

test "String splitter" {
    const expected_smaller: [4][]const u8 = .{
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR",
        "w",
        "KQkq",
        "-",
    };
    const split_smaller = splitString(4, StartingFen, ' ');

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
    const split_exact = splitString(6, StartingFen, ' ');

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
    const split_larger = splitString(8, StartingFen, ' ');

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

test "entryAfter helper" {
    const greeks = "alpha,beta,gamma,delta";
    var it = std.mem.splitScalar(u8, greeks, ',');
    const after = entryAfter(.scalar, &it, "beta");
    try expect(after != null);
    try std.testing.expectEqualStrings("gamma", after.?);

    const fruits = "apple orange banana";
    it = std.mem.splitScalar(u8, fruits, ' ');
    try std.testing.expect(entryAfter(.scalar, &it, "grape") == null);

    const numms = "one two three";
    it = std.mem.splitScalar(u8, numms, ' ');
    try std.testing.expect(entryAfter(.scalar, &it, "three") == null);
}

test "Board initialization & copy from starting fen" {
    const allocator = testing.allocator;
    var parent = try Board.init(allocator, .{});
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

test "Chess960 board" {
    const allocator = testing.allocator;
    var board = try Board.init(
        allocator,
        .{
            .fen = "bbrknnqr/pppppppp/8/8/8/8/PPPPPPPP/BBRKNNQR w KQkq - 0 1",
            .fischer_random = true,
        },
    );

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    // All that changes here is the castling rights & fen reconstruction
    for (board.castling_rights.rooks) |rf| {
        try expectEqual(File.fc, rf[0]);
        try expectEqual(File.fh, rf[1]);
    }

    const expected_path = [_][2]u64{
        .{ 0, 112 },
        .{ 0, 8070450532247928832 },
    };
    for (expected_path, board.castling_path) |expected, c| {
        try expectEqual(expected[0], c[0].bits);
        try expectEqual(expected[1], c[1].bits);
    }

    const actual_fen = try board.getFen(true);
    defer allocator.free(actual_fen);
    try expectEqualSlices(
        u8,
        "bbrknnqr/pppppppp/8/8/8/8/PPPPPPPP/BBRKNNQR w HChc - 0 1",
        actual_fen,
    );
}

test "Fen reconstruction" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    const fen_moves = try board.getFen(true);
    defer board.allocator.free(fen_moves);

    try expectEqualSlices(u8, StartingFen, fen_moves);

    const fen_moveless = try board.getFen(false);
    defer board.allocator.free(fen_moveless);

    try expectEqualSlices(u8, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -", fen_moveless);
}

test "EPD handling" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});
    const epd = try board.getEpd();

    defer {
        board.deinit();
        allocator.destroy(board);
        allocator.free(epd);
    }

    const starting_epd = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - hmvc 0; fmvn 1;";
    try expectEqualSlices(u8, starting_epd, epd);

    try expect(try board.setEpd("r1bqk2r/p1pp1ppp/2p2n2/8/1b2P3/2N5/PPP2PPP/R1BQKB1R w KQkq - bm Bd3;"));
    const fen_default_moves = try board.getFen(true);
    defer allocator.free(fen_default_moves);
    try expectEqualSlices(
        u8,
        "r1bqk2r/p1pp1ppp/2p2n2/8/1b2P3/2N5/PPP2PPP/R1BQKB1R w KQkq - 0 1",
        fen_default_moves,
    );

    try expect(try board.setEpd("8/3r4/pr1Pk1p1/8/7P/6P1/3R3K/5R2 w - - bm Re2+; id arasan21.16; hmvc 20; fmvn 80;"));
    const fen_with_set_moves = try board.getFen(true);
    defer allocator.free(fen_with_set_moves);
    try expectEqualSlices(
        u8,
        "8/3r4/pr1Pk1p1/8/7P/6P1/3R3K/5R2 w - - 20 80",
        fen_with_set_moves,
    );

    try expect(try board.setEpd("8/3r4/pr1Pk1p1/8/7P/6P1/3R3K/5R2 w - - bm Re2+; id arasan21.16; hmvc 20 fmvn 80"));
    const fen_with_set_moves_no_semi = try board.getFen(true);
    defer allocator.free(fen_with_set_moves_no_semi);
    try expectEqualSlices(
        u8,
        "8/3r4/pr1Pk1p1/8/7P/6P1/3R3K/5R2 w - - 20 80",
        fen_with_set_moves_no_semi,
    );
}

test "Illegal fen handling" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    const ok = try board.setFen("fen: []const u8", true);
    try expect(!ok);
    try expectEqualSlices(u8, StartingFen, board.original_fen);

    // TODO: Test for illegal board positions such as non-stm king in check and illegal pawns
}
