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

const move_ = @import("../core/move.zig");
const MoveType = move_.MoveType;
const Move = move_.Move;

const castling = @import("castling.zig");
const CastlingRights = castling.CastlingRights;

const state = @import("state.zig");
const Zobrist = state.Zobrist;
const State = state.State;

const attacks = @import("../movegen/attacks.zig");

const movegen = @import("../movegen/movegen.zig");

const uci = @import("../core/uci.zig");

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
    /// The Board pointer itself must be freed separately.
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
    /// Will not modify the board if the fen cannot be updated correctly.
    /// You must use this function before setting an FRC fen.
    ///
    /// Using this in the middle of a game resets the board to its original fen position.
    pub fn setFischerRandom(self: *Board, fischer_random: bool) !bool {
        const previous_frc = self.fischer_random;
        self.fischer_random = fischer_random;

        // Since setFen can error, we want to restore state before propagating an error
        errdefer self.fischer_random = previous_frc;

        const success = try self.setFen(self.original_fen, false);
        if (!success) self.fischer_random = previous_frc;
        return success;
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
            const valid = movegen.isEpSquareValid(self, self.side_to_move, self.ep_square);
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

        // Both sides cannot be in check
        const white_checked = self.inCheckNAssert(.{ .color = .white }) catch blk: {
            success = false;
            break :blk true;
        };
        const black_checked = self.inCheckNAssert(.{ .color = .black }) catch blk: {
            success = false;
            break :blk true;
        };

        if (white_checked and black_checked) {
            success = false;
        }

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

    /// Returns the specified piece bitboard, use `Color.none` for side agnostic bitboard.
    ///
    /// Asserts that the provided piece type is valid.
    pub fn pieces(self: *const Board, color: Color, piece_type: PieceType) Bitboard {
        std.debug.assert(piece_type.valid());
        return if (color == .none) blk: {
            break :blk self.pieces_bbs[piece_type.index()];
        } else blk: {
            break :blk self.pieces_bbs[piece_type.index()].andBB(self.occ_bbs[color.index()]);
        };
    }

    /// Returns the specified combined piece bitboards, use `Color.none` for side agnostic bitboard.
    ///
    /// Asserts that the provided piece types are valid.
    pub fn piecesMany(self: *const Board, color: Color, piece_types: []const PieceType) Bitboard {
        var result = Bitboard.init();
        for (piece_types) |pt| {
            _ = result.orAssign(self.pieces(color, pt));
        }

        return result;
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

    /// Checks if a move is a capture, including en passant.
    ///
    /// Moves are naively checked meaning legality is not considered.
    pub fn isCapture(self: *const Board, move: Move) bool {
        const valid_at = self.at(Piece, move.to()).valid();
        const valid_type = move.typeOf(MoveType) == .castling or move.typeOf(MoveType) == .enpassant;
        return valid_at and valid_type;
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

    /// Makes a LEGAL move on the board.
    /// The `exact` option forces the ep square to only be true if capture is legal.
    ///
    /// A moves legality should be verified externally.
    /// For external verification, check if the move is in the list of current legal moves.
    ///
    /// Only asserts that the side to move aligns with the piece to move.
    pub fn makeMove(self: *Board, move: Move, comptime options: struct {
        exact: bool = false,
    }) void {
        std.debug.assert(self.at(Piece, move.from()).lt(.black_pawn) == (self.side_to_move == .white));

        const capture = self.at(Piece, move.to()) != .none and move.typeOf(MoveType) != .castling;
        const captured = self.at(Piece, move.to());
        const pt_from = self.at(PieceType, move.from());

        self.previous_states.append(self.allocator, .{
            .hash = self.key,
            .castling = self.castling_rights,
            .enpassant = self.ep_square,
            .half_moves = @intCast(self.halfmove_clock),
            .captured_piece = captured,
        }) catch unreachable;

        self.halfmove_clock += 1;
        self.plies += 1;

        if (self.ep_square.valid()) self.key ^= Zobrist.enPassant(self.ep_square.file());
        self.ep_square = .none;

        const sq_gt = struct {
            pub fn gt(s1: Square, s2: Square) bool {
                return s1.gt(s2);
            }
        }.gt;

        // Handle direct captures (excludes EP)
        if (capture) {
            self.removePiece(captured, move.to());

            self.halfmove_clock = 0;
            self.key ^= Zobrist.piece(captured, move.to());

            // If the rook is captured, then the respective rights must be removed
            if (captured.asType() == .rook and move.to().rank().backRank(self.side_to_move.opposite())) {
                const king_sq = self.kingSq(self.side_to_move.opposite());
                const file = CastlingRights.closestSide(
                    Square,
                    move.to(),
                    king_sq,
                    sq_gt,
                );

                if (self.castling_rights.rookFile(
                    self.side_to_move.opposite(),
                    file,
                ) == move.to().file()) {
                    self.key ^= Zobrist.castlingIdx(
                        self.castling_rights.pop(usize, self.side_to_move.opposite(), file),
                    );
                }
            }
        }

        // Handle other special piece moves
        if (pt_from == .king and self.castling_rights.hasEither(self.side_to_move)) {
            self.key ^= Zobrist.castling(self.castling_rights.hash());
            self.castling_rights.clearColor(self.side_to_move);
            self.key ^= Zobrist.castling(self.castling_rights.hash());
        } else if (pt_from == .rook and move.from().backRank(self.side_to_move)) {
            const king_sq = self.kingSq(self.side_to_move);
            const file = CastlingRights.closestSide(
                Square,
                move.from(),
                king_sq,
                sq_gt,
            );

            if (self.castling_rights.rookFile(self.side_to_move, file) == move.from().file()) {
                self.key ^= Zobrist.castlingIdx(self.castling_rights.pop(
                    usize,
                    self.side_to_move,
                    file,
                ));
            }
        } else if (pt_from == .pawn) {
            self.halfmove_clock = 0;

            // A distance of 16 means a double push
            if (distance.ValueDist[move.to().index()][move.from().index()] == 16) {
                const ep_mask = attacks.pawn(self.side_to_move, move.to().ep());

                // Add en passant only if enemy pawns are attacking the square
                if (ep_mask.andBB(self.pieces(self.side_to_move.opposite(), .pawn)).nonzero()) {
                    var found: i32 = -1;

                    // Check if the enemy can legally capture ep
                    if (comptime options.exact) {
                        const piece = self.at(Piece, move.from());
                        found = 0;

                        // Simulate piece removal so masks are calculated properly
                        self.removePiece(piece, move.from());
                        self.placePiece(piece, move.to());

                        self.side_to_move = self.side_to_move.opposite();
                        const valid = movegen.isEpSquareValid(self, self.side_to_move, move.to().ep());
                        if (valid) found = 1;

                        self.side_to_move = self.side_to_move.opposite();
                        self.removePiece(piece, move.to());
                        self.placePiece(piece, move.from());
                    }

                    if (found != 0) {
                        std.debug.assert(self.at(Piece, move.to().ep()) == .none);
                        self.ep_square = move.to().ep();
                        self.key ^= Zobrist.enPassant(move.to().ep().file());
                    }
                }
            }
        }

        // Handle actual piece removal
        if (move.typeOf(MoveType) == .castling) {
            std.debug.assert(self.at(PieceType, move.from()) == .king);
            std.debug.assert(self.at(PieceType, move.to()) == .rook);

            const side: CastlingRights.Side = if (move.to().gt(move.from())) .king else .queen;
            const rook_to = Square.castlingRookTo(side, self.side_to_move);
            const king_to = Square.castlingKingTo(side, self.side_to_move);

            const king = self.at(Piece, move.from());
            const rook = self.at(Piece, move.to());

            self.removePiece(king, move.from());
            self.removePiece(rook, move.to());

            std.debug.assert(king == Piece.make(self.side_to_move, .king));
            std.debug.assert(rook == Piece.make(self.side_to_move, .rook));

            self.placePiece(king, king_to);
            self.placePiece(rook, rook_to);

            self.key ^= Zobrist.piece(king, move.from()) ^ Zobrist.piece(king, king_to);
            self.key ^= Zobrist.piece(rook, move.to()) ^ Zobrist.piece(rook, rook_to);
        } else if (move.typeOf(MoveType) == .promotion) {
            const piece_pawn = Piece.make(self.side_to_move, .pawn);
            const piece_prom = Piece.make(self.side_to_move, move.promotionType());

            self.removePiece(piece_pawn, move.from());
            self.placePiece(piece_prom, move.to());

            self.key ^= Zobrist.piece(piece_pawn, move.from()) ^ Zobrist.piece(piece_prom, move.to());
        } else {
            std.debug.assert(self.at(Piece, move.from()) != .none);
            std.debug.assert(self.at(Piece, move.to()) == .none);

            const piece = self.at(Piece, move.from());

            self.removePiece(piece, move.from());
            self.placePiece(piece, move.to());

            self.key ^= Zobrist.piece(piece, move.from()) ^ Zobrist.piece(piece, move.to());
        }

        // Handle ep captures as the first capture handler ignores it
        if (move.typeOf(MoveType) == .en_passant) {
            std.debug.assert(self.at(PieceType, move.to().ep()) == .pawn);

            const piece = Piece.make(self.side_to_move.opposite(), .pawn);
            self.removePiece(piece, move.to().ep());

            self.key ^= Zobrist.piece(piece, move.to().ep());
        }

        self.key ^= Zobrist.sideToMove();
        self.side_to_move = self.side_to_move.opposite();
    }

    /// Unmakes a LEGAL move on the board.
    ///
    /// A moves legality should be verified externally.
    ///
    /// Asserts that the board has a state history.
    pub fn unmakeMove(self: *Board, move: Move) void {
        const prev = self.previous_states.getLastOrNull();
        if (prev) |previous_state| {
            self.ep_square = previous_state.enpassant;
            self.castling_rights = previous_state.castling;
            self.halfmove_clock = previous_state.half_moves;
            self.side_to_move = self.side_to_move.opposite();
            self.plies -= 1;

            if (move.typeOf(MoveType) == .castling) {
                const king_side = move.to().gt(move.from());
                const rook_from_sq = Square.make(
                    move.from().rank(),
                    if (king_side) .ff else .fd,
                );
                const king_to_sq = Square.make(
                    move.from().rank(),
                    if (king_side) .fg else .fc,
                );

                std.debug.assert(self.at(PieceType, rook_from_sq) == .rook);
                std.debug.assert(self.at(PieceType, king_to_sq) == .king);

                const rook = self.at(Piece, rook_from_sq);
                const king = self.at(Piece, king_to_sq);

                self.removePiece(rook, rook_from_sq);
                self.removePiece(king, king_to_sq);

                std.debug.assert(king == Piece.make(self.side_to_move, .king));
                std.debug.assert(rook == Piece.make(self.side_to_move, .rook));

                self.placePiece(king, move.from());
                self.placePiece(rook, move.to());
            } else if (move.typeOf(MoveType) == .promotion) {
                const pawn = Piece.make(self.side_to_move, .pawn);
                const piece = self.at(Piece, move.to());

                std.debug.assert(piece.asType() == move.promotionType());
                std.debug.assert(piece.asType() != .pawn);
                std.debug.assert(piece.asType() != .king);
                std.debug.assert(piece.asType() != .none);

                self.removePiece(piece, move.to());
                self.placePiece(pawn, move.from());

                if (previous_state.captured_piece != .none) {
                    std.debug.assert(self.at(Piece, move.to()) == .none);
                    self.placePiece(previous_state.captured_piece, move.to());
                }
            } else {
                std.debug.assert(self.at(Piece, move.to()) != .none);
                std.debug.assert(self.at(Piece, move.from()) == .none);

                const piece = self.at(Piece, move.to());

                self.removePiece(piece, move.to());
                self.placePiece(piece, move.from());

                if (move.typeOf(MoveType) == .en_passant) {
                    const pawn = Piece.make(self.side_to_move.opposite(), .pawn);
                    const pawn_to = self.ep_square.xor(Square.fromInt(usize, 8));

                    std.debug.assert(self.at(Piece, pawn_to) == .none);

                    self.placePiece(pawn, pawn_to);
                } else if (previous_state.captured_piece != .none) {
                    std.debug.assert(self.at(Piece, move.to()) == .none);

                    self.placePiece(previous_state.captured_piece, move.to());
                }
            }

            self.key = previous_state.hash;
            _ = self.previous_states.pop();
        } else unreachable;
    }

    /// Makes a null move.
    ///
    /// Switches the side and updates core state only.
    pub fn makeNullMove(self: *Board) void {
        self.previous_states.append(self.allocator, .{
            .hash = self.key,
            .castling = self.castling_rights,
            .enpassant = self.ep_square,
            .half_moves = @intCast(self.halfmove_clock),
            .captured_piece = .none,
        }) catch unreachable;

        self.key ^= Zobrist.sideToMove();
        if (self.ep_square.valid()) {
            self.key ^= Zobrist.enPassant(self.ep_square.file());
        }

        self.ep_square = .none;
        self.side_to_move = self.side_to_move.opposite();
        self.plies += 1;
    }

    /// Unmakes a null move.
    ///
    /// Switches the side and updates core state only.
    pub fn unmakeNullMove(self: *Board) void {
        const prev = self.previous_states.pop();

        if (prev) |previous_state| {
            self.ep_square = previous_state.enpassant;
            self.castling_rights = previous_state.castling;
            self.halfmove_clock = previous_state.half_moves;
            self.key = previous_state.hash;

            self.plies -= 1;
            self.side_to_move = self.side_to_move.opposite();
        }
    }

    /// Perform a perft test to the given depth.
    ///
    /// Indicating `check_checks` tests `givesCheck` against `inCheck`.
    pub fn perft(self: *Board, depth: usize, comptime options: struct {
        check_checks: bool = false,
    }) usize {
        var moves = movegen.Movelist{};
        movegen.legalmoves(self, &moves, .{});

        if (depth <= 1) {
            return moves.size;
        }

        var nodes: usize = 0;
        for (moves.moves[0..moves.size]) |move| {
            // Verify alignment of checks if asked
            if (comptime options.check_checks) {
                const gives_check = self.givesCheck(move).check();
                self.makeMove(move, .{});
                const in_check = self.inCheck(.{});

                if (gives_check != in_check) {
                    std.log.err(
                        "Move: {d}, givesCheck(...) = {} but inCheck(...) = {}",
                        .{ move.move, gives_check, in_check },
                    );
                    unreachable;
                }

                nodes += self.perft(depth - 1, options);
                self.unmakeMove(move);
                continue;
            }

            // Otherwise just perform normal perft
            self.makeMove(move, .{});
            nodes += self.perft(depth - 1, options);
            self.unmakeMove(move);
        }

        return nodes;
    }

    /// Checks if the current position is a repetition.
    ///
    /// Only returns true if the position has been seen at `count` times.
    pub fn isRepetition(self: *const Board, count: usize) bool {
        std.debug.assert(count > 0);
        var seen_count: usize = 0;

        // Repetitions cannot cross halfmoves, walk backwards
        const numel: i32 = @intCast(self.previous_states.items.len);
        var i = numel - 2;

        while (i >= 0 and i >= numel - @as(i32, @intCast(self.halfmove_clock)) - 1) : (i -= 2) {
            if (self.previous_states.items[@intCast(i)].hash == self.key) {
                seen_count += 1;
            }

            if (seen_count == count) return true;
        }

        return false;
    }

    /// Determines if the given color is in check.
    ///
    /// If the color is null, uses the side to move.
    pub fn inCheck(self: *const Board, comptime options: struct {
        color: ?Color = null,
    }) bool {
        const color = if (options.color) |c| c else self.side_to_move;
        return attacks.isAttacked(self, color.opposite(), self.kingSq(color));
    }

    /// For internal use only, opts for errors instead of assertions for explicit handling.
    fn inCheckNAssert(self: *const Board, comptime options: struct {
        color: ?Color = null,
    }) !bool {
        const color = if (options.color) |c| c else self.side_to_move;
        return attacks.isAttacked(self, color.opposite(), try self.kingSqNAssert(color));
    }

    /// Check if the move gives a check.
    pub fn givesCheck(self: *const Board, move: Move) state.CheckType {
        std.debug.assert(self.at(Piece, move.from()).color() == self.side_to_move);
        const sniper = struct {
            pub fn sniper(board: *const Board, king_sq_: Square, occ_: Bitboard) Bitboard {
                const b_atks = attacks.bishop(king_sq_, occ_).andBB(
                    board.piecesMany(board.side_to_move, &[_]PieceType{ .bishop, .queen }),
                );
                const r_atks = attacks.rook(king_sq_, occ_).andBB(
                    board.piecesMany(board.side_to_move, &[_]PieceType{ .rook, .queen }),
                );

                return b_atks.orBB(r_atks);
            }
        }.sniper;

        const from = move.from();
        const to = move.to();

        const king_sq = self.kingSq(self.side_to_move.opposite());
        const pt = self.at(PieceType, from);

        const from_bb = Bitboard.fromSquare(from);
        const to_bb = Bitboard.fromSquare(to);

        const from_king = switch (pt) {
            .pawn => attacks.pawn(self.side_to_move.opposite(), king_sq),
            .knight => attacks.knight(king_sq),
            .bishop => attacks.bishop(king_sq, self.occ()),
            .rook => attacks.rook(king_sq, self.occ()),
            .queen => attacks.queen(king_sq, self.occ()),
            else => Bitboard.init(),
        };

        if (from_king.andBB(to_bb).nonzero()) return .direct;

        // Check for a discovered check
        const relevant_occ = self.occ().xorBB(from_bb);
        var sniper_bb = sniper(self, king_sq, relevant_occ);
        while (sniper_bb.nonzero()) {
            const index = sniper_bb.popLsb();
            const relevant_between = distance.SquaresBetween[king_sq.index()][index.index()].andBB(to_bb);
            return if (relevant_between.empty() or move.typeOf(MoveType) == .castling) blk: {
                break :blk .discovery;
            } else .none;
        }

        // Handle all move types now
        return switch (move.typeOf(MoveType)) {
            .normal => .none,
            .promotion => blk: {
                const promoting_attacks = switch (move.promotionType()) {
                    .knight => attacks.knight(to),
                    .bishop => attacks.bishop(to, relevant_occ),
                    .rook => attacks.rook(to, relevant_occ),
                    .queen => attacks.queen(to, relevant_occ),
                    else => unreachable,
                };

                const relevant_attacks = promoting_attacks.andBB(
                    self.pieces(self.side_to_move.opposite(), .king),
                );
                break :blk if (relevant_attacks.nonzero()) .direct else .none;
            },
            .en_passant => blk: {
                const capture_sq = Square.make(from.rank(), to.file());
                sniper_bb = sniper(
                    self,
                    king_sq,
                    relevant_occ.xorBB(Bitboard.fromSquare(capture_sq)).orBB(to_bb),
                );

                break :blk if (sniper_bb.nonzero()) .discovery else .none;
            },
            .castling => blk: {
                const rook_to = Square.castlingRookTo(
                    if (to.gt(from)) .king else .queen,
                    self.side_to_move,
                );
                const relevant_attacks = attacks.rook(
                    king_sq,
                    self.occ(),
                ).andBB(Bitboard.fromSquare(rook_to));
                break :blk if (relevant_attacks.nonzero()) .discovery else .none;
            },
            else => unreachable,
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

    // A board should be able to be changed from FRC to Classic and back
    var future_frc = try Board.init(allocator, .{
        .fen = "brknqbnr/pppppppp/8/8/8/8/PPPPPPPP/BRKNQBNR w KQkq - 0 1",
    });

    defer {
        future_frc.deinit();
        allocator.destroy(future_frc);
    }

    try expect(try future_frc.setFischerRandom(true));
    const frc_fen = try future_frc.getFen(true);
    defer allocator.free(frc_fen);
    try expectEqualSlices(
        u8,
        "brknqbnr/pppppppp/8/8/8/8/PPPPPPPP/BRKNQBNR w HBhb - 0 1",
        frc_fen,
    );

    try expect(try future_frc.setFischerRandom(false));
    const classical_fen = try future_frc.getFen(true);
    defer allocator.free(classical_fen);
    try expectEqualSlices(
        u8,
        "brknqbnr/pppppppp/8/8/8/8/PPPPPPPP/BRKNQBNR w KQkq - 0 1",
        classical_fen,
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

    // Completely garbage input
    try expect(!try board.setFen("fen: []const u8", true));
    try expectEqualSlices(u8, StartingFen, board.original_fen);

    // Check case where both sides are in check
    try expect(!try board.setFen("rnb1kbnr/pppp1ppp/3p4/8/1q6/3P1P2/PPP1QPPP/RNB1KBNR w KQkq - 0 1", true));
    try expectEqualSlices(u8, StartingFen, board.original_fen);
}

test "Move Making" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    // From starting position
    const opening = uci.uciToMove(board, "e2e4");
    try expectEqual(5060803636482931868, board.key);

    board.makeMove(opening, .{});
    try expectEqual(9384546495678726550, board.key);
    try expect(board.side_to_move == .black);

    board.unmakeMove(opening);
    try expectEqual(5060803636482931868, board.key);
    try expect(board.side_to_move == .white);
    try expect(board.ep_square == .none);

    // From classical castling position
    try expect(try board.setFen("rnbqkbnr/pppppppp/8/8/8/3BPP1N/PPPP2PP/RNBQK2R w KQkq - 0 1", true));
    const classical_castle = uci.uciToMove(board, "e1g1");
    try expectEqual(13502998632615454432, board.key);

    board.makeMove(classical_castle, .{});
    try expectEqual(14200186636676038128, board.key);

    board.unmakeMove(classical_castle);
    try expectEqual(13502998632615454432, board.key);

    // En passant move - legal capture possible
    try expect(try board.setFen("rnbqk1nr/pp2pp1p/7b/B5pP/1p1pP3/8/PPPK1P1P/RNBQ2NR w kq - 0 1", true));
    const double_push_ep = uci.uciToMove(board, "c2c4");
    try expectEqual(16818045822105834089, board.key);

    board.makeMove(double_push_ep, .{});
    try expectEqual(7312930370676297740, board.key);
    try expect(board.ep_square == .c3);

    board.unmakeMove(double_push_ep);
    try expectEqual(16818045822105834089, board.key);
    try expect(board.ep_square == .none);

    // En passant move - illegal capture possible (Exact off)
    try expect(try board.setFen("rnbq2nr/pp2pp1p/7b/B2k2pP/p2p4/4P3/PPP1KP1P/RNBQ2NR w - - 0 1", true));
    const illegal_ep_no_exact = uci.uciToMove(board, "c2c4");
    try expectEqual(7387365850737516480, board.key);

    board.makeMove(illegal_ep_no_exact, .{});
    try expectEqual(16905456255022161317, board.key);
    try expect(board.ep_square == .c3);

    board.unmakeMove(illegal_ep_no_exact);
    try expectEqual(7387365850737516480, board.key);
    try expect(board.ep_square == .none);

    // En passant move - illegal capture possible (Exact on)
    try expect(try board.setFen("rnbq2nr/pp2pp1p/7b/B2k2pP/p2p4/4P3/PPP1KP1P/RNBQ2NR w - - 0 1", true));
    const illegal_ep_exact = uci.uciToMove(board, "c2c4");
    try expectEqual(7387365850737516480, board.key);

    board.makeMove(illegal_ep_exact, .{ .exact = true });
    try expectEqual(16908392331399410887, board.key);
    try expect(board.ep_square == .none);

    board.unmakeMove(illegal_ep_exact);
    try expectEqual(7387365850737516480, board.key);
    try expect(board.ep_square == .none);

    // From FRC starting position
    try expect(try board.setFischerRandom(true));
    try expect(try board.setFen("brknqbnr/pppppppp/8/8/8/8/PPPPPPPP/BRKNQBNR w HBhb - 0 1", true));
    const double_push_ep_frc = uci.uciToMove(board, "c2c4");
    try expectEqual(2063133069522446414, board.key);

    board.makeMove(double_push_ep_frc, .{});
    try expectEqual(10412928980166411081, board.key);

    board.unmakeMove(
        double_push_ep_frc,
    );
    try expectEqual(2063133069522446414, board.key);

    // From FRC castling position
    try expect(try board.setFen("brnbkrnq/pppppppp/8/8/8/1BPN4/PP1PPPPP/BR2KRNQ w BFbf - 0 1", true));
    const frc_castle = uci.uciToMove(board, "e1b1");
    try expectEqual(15836352940436779965, board.key);

    board.makeMove(frc_castle, .{});
    try expectEqual(13334023313799364008, board.key);

    board.unmakeMove(frc_castle);
    try expectEqual(15836352940436779965, board.key);
}

test "Null move making" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    // From starting position
    try expectEqual(5060803636482931868, board.key);

    board.makeNullMove();
    try expectEqual(13757846718353144213, board.key);
    try expect(board.side_to_move == .black);

    board.unmakeNullMove();
    try expectEqual(5060803636482931868, board.key);
    try expect(board.side_to_move == .white);

    // From other position
    try expect(try board.setFen("8/3r4/pr1Pk1p1/8/7P/6P1/3R3K/5R2 w - - 20 80", true));
    try expectEqual(8960625063001898923, board.key);

    board.makeNullMove();
    try expectEqual(9551202073125010082, board.key);

    board.unmakeNullMove();
    try expectEqual(8960625063001898923, board.key);

    // From FRC starting position
    try expect(try board.setFischerRandom(true));
    try expect(try board.setFen("brknqbnr/pppppppp/8/8/8/8/PPPPPPPP/BRKNQBNR w HBhb - 0 1", true));
    try expectEqual(2063133069522446414, board.key);

    board.makeNullMove();
    try expectEqual(16462800901167951175, board.key);

    board.unmakeNullMove();
    try expectEqual(2063133069522446414, board.key);
}

test "Shallow perft" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{
        .fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - ",
    });

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    const expected_nodes: [4]usize = .{
        48, 2039, 97862, 4085603,
    };

    for (expected_nodes, 1..5) |expected, i| {
        try expectEqual(expected, board.perft(i, .{ .check_checks = true }));
    }
}

test "Repetition tracking" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    try expect(!board.isRepetition(1));
    const knight_move_white_to = Move.make(.g1, .f3, .{});
    const knight_move_black_to = Move.make(.g8, .f6, .{});
    const knight_move_white_back = Move.make(.f3, .g1, .{});
    const knight_move_black_back = Move.make(.f6, .g8, .{});

    board.makeMove(knight_move_white_to, .{});
    board.makeMove(knight_move_black_to, .{});
    board.makeMove(knight_move_white_back, .{});
    board.makeMove(knight_move_black_back, .{});

    try expect(board.isRepetition(1));
    try expect(!board.isRepetition(2));
}

test "Check detection" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});

    defer {
        board.deinit();
        allocator.destroy(board);
    }

    try expect(!board.inCheck(.{}));
    try expect(!board.inCheck(.{ .color = .white }));
    try expect(!board.inCheck(.{ .color = .black }));

    // Black is in check
    try expect(try board.setFen("rnbqkbnr/pppp1ppp/3p4/8/8/5P2/PPPPQPPP/RNB1KBNR b KQkq - 0 1", true));
    try expect(board.inCheck(.{}));
    try expect(board.inCheck(.{ .color = .black }));
    try expect(!board.inCheck(.{ .color = .white }));
}
