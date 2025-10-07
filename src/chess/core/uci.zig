const std = @import("std");

const types = @import("types.zig");
const Square = types.Square;
const File = types.File;
const Rank = types.Rank;
const Color = types.Color;

const piece_ = @import("piece.zig");
const Piece = piece_.Piece;
const PieceType = piece_.PieceType;

const board_ = @import("../board/board.zig");
const Board = board_.Board;

const move_ = @import("move.zig");
const Move = move_.Move;
const MoveType = move_.MoveType;

const distance = @import("distance.zig");

/// Converts a move into its corresponding string representation.
/// Castling moves are corrected to the same rank and classical files if not in FRC.
///
/// The caller is responsible for freeing the returned string.
pub fn moveToUci(allocator: std.mem.Allocator, move: Move, fischer_random: bool) ![]const u8 {
    var buffer = std.Io.Writer.Allocating.init(allocator);
    defer buffer.deinit();
    var writer = &buffer.writer;

    try printMoveUci(move, fischer_random, writer);
    return try allocator.dupe(u8, writer.buffered());
}

/// Prints a move to the output writer.
/// Castling moves are corrected to the same rank and classical files if not in FRC.
///
/// The caller is responsible for freeing the returned string.
pub fn printMoveUci(move: Move, fischer_random: bool, writer: *std.Io.Writer) !void {
    const from = move.from();
    var to = move.to();

    if (!fischer_random and move.typeOf(MoveType) == .castling) {
        to = Square.make(from.rank(), if (to.order(from) == .gt) .fg else .fc);
    }

    try writer.print("{s}", .{from.asStr()});
    try writer.print("{s}", .{to.asStr()});
    if (move.typeOf(MoveType) == .promotion) {
        try writer.print("{c}", .{move.promotionType().asChar()});
    }
}

/// Uses the board's current state to convert a UCI move string to a move.
/// Castling moves are corrected to the same rank and classical files if not in FRC.
///
/// Does not check for opponent piece presence, 'legality' is a loose term here.
pub fn uciToMove(board: *const Board, uci: []const u8) Move {
    if (uci.len < 4) return Move.init();

    // We can safely index into the string because of the above bounds check
    const source = Square.fromStr(uci[0..2]);
    const target = Square.fromStr(uci[2..4]);

    if (!source.valid() or !target.valid()) return Move.init();

    const pt_source = board.at(PieceType, source);
    const piece_target = board.at(Piece, target);

    // Handle castling moves in the two handled variants
    if (board.fischer_random) {
        if (pt_source == .king and piece_target.asType() == .rook and piece_target.color() == board.side_to_move) {
            return Move.make(source, target, .{ .move_type = .castling });
        }
    } else {
        if (pt_source == .king and distance.ChebyshevDist[target.index()][source.index()] == 2) {
            const corrected_target = Square.make(source.rank(), if (target.order(source) == .gt) .fh else .fa);
            return Move.make(source, corrected_target, .{ .move_type = .castling });
        }
    }

    // En passant case
    if (pt_source == .pawn and target.order(board.ep_square) == .eq) {
        return Move.make(source, target, .{ .move_type = .en_passant });
    }

    // Promoting case
    if (pt_source == .pawn and uci.len == 5 and target.backRank(board.side_to_move.opposite())) {
        const promotion = PieceType.fromChar(uci[4]);

        if (promotion == .none or promotion == .king or promotion == .pawn) {
            return Move.init();
        } else {
            return Move.make(source, target, .{
                .move_type = .promotion,
                .promotion_type = promotion,
            });
        }
    }

    // If we made it this far it's either a normal move or malformed
    return if (uci.len == 4) blk: {
        break :blk Move.make(source, target, .{});
    } else Move.init();
}

/// Loosely check if a string is a valid UCI move.
///
/// Does not check any legality, only confirming character presence and length.
pub fn isUciMove(move_str: []const u8) bool {
    var is_uci = false;

    if (move_str.len >= 4) {
        // zig fmt: off
        is_uci = File.fromChar(move_str[0]).valid()
            and std.ascii.isDigit(move_str[1])
            and File.fromChar(move_str[2]).valid()
            and std.ascii.isDigit(move_str[3]);
        // zig fmt: on
    }

    if (move_str.len == 5) {
        const is_promotion = std.mem.containsAtLeast(
            u8,
            "nbrq",
            1,
            move_str[4..5],
        );
        is_uci &= is_promotion;
    }

    return if (move_str.len > 5) false else is_uci;
}

/// Prints the board's diagram similar to uci compatible engine's 'd' command.
///
/// The caller is responsible for freeing the returned string.
pub fn uciBoardDiagram(board: *const Board, options: struct {
    black_at_top: ?bool = null,
    highlighted_move: ?Move = null,
}) ![]const u8 {
    var buffer = std.Io.Writer.Allocating.init(board.allocator);
    defer buffer.deinit();
    const writer = &buffer.writer;

    const highlight_move_square: Square = if (options.highlighted_move) |hm| hm.to() else .none;
    const black_at_top = if (options.black_at_top) |bat| blk: {
        break :blk bat;
    } else board.side_to_move == .white;

    for (0..8) |y| {
        const rank = if (black_at_top) 7 - y else y;
        try writer.print("+---+---+---+---+---+---+---+---+\n", .{});

        for (0..8) |x| {
            const file = if (black_at_top) x else 7 - x;
            const square = Square.make(
                Rank.fromInt(usize, rank),
                File.fromInt(usize, file),
            );

            if (!square.valid()) continue;

            const highlight = highlight_move_square.order(square) == .eq;
            const piece = board.at(Piece, square);
            const piece_char = if (piece.valid()) piece.asChar() else ' ';

            if (highlight) {
                try writer.print("|({c})", .{piece_char});
            } else {
                try writer.print("| {c} ", .{piece_char});
            }
        }

        try writer.print("| {d}\n", .{rank + 1});
    }

    try writer.print("+---+---+---+---+---+---+---+---+\n", .{});
    if (black_at_top) {
        try writer.print("  a   b   c   d   e   f   g   h  \n\n", .{});
    } else {
        try writer.print("  h   g   f   e   d   c   b   a  \n\n", .{});
    }

    const current_fen = try board.getFen(true);
    defer board.allocator.free(current_fen);
    try writer.print("Fen         : {s}\n", .{current_fen});
    try writer.print("Hash        : {d}", .{board.key});

    return try board.allocator.dupe(u8, writer.buffered());
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

test "Converting uci moves to strings" {
    const allocator = testing.allocator;

    // Normal move conversion
    const normal_move = Move.make(.a1, .a2, .{});
    const normal_move_str = try moveToUci(allocator, normal_move, false);
    defer allocator.free(normal_move_str);
    try expectEqualSlices(u8, "a1a2", normal_move_str);

    // Null move conversion
    const null_move = Move.make(.a1, .a1, .{ .move_type = .null_move });
    const null_move_str = try moveToUci(allocator, null_move, false);
    defer allocator.free(null_move_str);
    try expectEqualSlices(u8, "b1b1", null_move_str);

    // Promoting move conversion
    const promoting_move = Move.make(.e7, .e8, .{
        .move_type = .promotion,
        .promotion_type = .queen,
    });
    const promoting_move_str = try moveToUci(allocator, promoting_move, false);
    defer allocator.free(promoting_move_str);
    try expectEqualSlices(u8, "e7e8q", promoting_move_str);

    // En passant move conversion
    const ep_move = Move.make(.e5, .e6, .{ .move_type = .en_passant });
    const ep_move_str = try moveToUci(allocator, ep_move, false);
    defer allocator.free(ep_move_str);
    try expectEqualSlices(u8, "e5e6", ep_move_str);

    // Castling move conversion
    const malformed_castling_move = Move.make(.e5, .e3, .{ .move_type = .castling });
    const malformed_castling_move_str = try moveToUci(allocator, malformed_castling_move, false);
    defer allocator.free(malformed_castling_move_str);
    try expectEqualSlices(u8, "e5c5", malformed_castling_move_str);

    const proper_castling_move = Move.make(.a5, .g5, .{ .move_type = .castling });
    const proper_castling_move_str = try moveToUci(allocator, proper_castling_move, false);
    defer allocator.free(proper_castling_move_str);
    try expectEqualSlices(u8, "a5g5", proper_castling_move_str);

    // Castling move conversion in Chess960 (No castling correction)
    const castling_move = Move.make(.e5, .e3, .{ .move_type = .castling });
    const castling_move_str = try moveToUci(allocator, castling_move, true);
    defer allocator.free(castling_move_str);
    try expectEqualSlices(u8, "e5e3", castling_move_str);
}

test "Converting strings to uci moves" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});
    defer board.deinit();

    // Malformed moves
    try expectEqual(0, uciToMove(board, "").move);
    try expectEqual(0, uciToMove(board, "uci: []const u8").move);
    try expectEqual(0, uciToMove(board, "e7e8bp").move);

    // Standard classical moves
    const pawn = uciToMove(board, "e2e3");
    try expectEqual(788, pawn.move);

    try expect(try board.setFen("rnbqkbnr/pppppppp/8/8/2B5/4PN2/PPPP1PPP/RNBQK2R w KQkq - 0 1", true));
    const castle = uciToMove(board, "e1g1");
    try expectEqual(49415, castle.move);

    const illegal_king_move = uciToMove(board, "e1h1");
    try expectEqual(263, illegal_king_move.move);

    try expect(try board.setFen("rnbqkbnr/pppp1p1p/8/4pPp1/8/8/PPPPP1PP/RNBQKBNR w KQkq e6 0 1", true));
    const ep = uciToMove(board, "f5e6");
    try expectEqual(35180, ep.move);

    const illegal_pawn_move = uciToMove(board, "f5g6");
    try expectEqual(2414, illegal_pawn_move.move);

    try expect(try board.setFen("rnbqkbn1/ppppppP1/8/8/8/8/PPPPPP1P/RNBQKBNR w KQkq - 0 1", true));
    const promoting = uciToMove(board, "f7e8q");
    try expectEqual(32124, promoting.move);

    // Fischer random chess moves (Castling different only)
    try expect(try board.setFischerRandom(true));
    try expect(try board.setFen("rnbqkbnr/pppppppp/8/8/2B5/4PN2/PPPP1PPP/RNBQK2R w HAha - 0 1", true));
    const frc_king_move = uciToMove(board, "e1h1");
    try expectEqual(49415, frc_king_move.move);

    const illegal_frc_king_move = uciToMove(board, "e1g1");
    try expectEqual(262, illegal_frc_king_move.move);
}

test "Loosely checking uci legality" {
    // Acceptable moves
    try expect(isUciMove("e1e2"));
    try expect(isUciMove("e7e8q"));
    try expect(isUciMove("a7g8q"));

    // Unacceptable moves
    try expect(!isUciMove("e7e8np"));
    try expect(!isUciMove("e7e8l"));
    try expect(!isUciMove("e7e81"));
    try expect(!isUciMove("move_str: []const u8"));
}

test "Board diagram creation" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, .{});
    defer board.deinit();

    // Expected strings from first iteration of the water engine
    const expected_default =
        \\+---+---+---+---+---+---+---+---+
        \\| r | n | b | q | k | b | n | r | 8
        \\+---+---+---+---+---+---+---+---+
        \\| p | p | p | p | p | p | p | p | 7
        \\+---+---+---+---+---+---+---+---+
        \\|   |   |   |   |   |   |   |   | 6
        \\+---+---+---+---+---+---+---+---+
        \\|   |   |   |   |   |   |   |   | 5
        \\+---+---+---+---+---+---+---+---+
        \\|   |   |   |   |   |   |   |   | 4
        \\+---+---+---+---+---+---+---+---+
        \\|   |   |   |   |   |   |   |   | 3
        \\+---+---+---+---+---+---+---+---+
        \\| P | P | P | P | P | P | P | P | 2
        \\+---+---+---+---+---+---+---+---+
        \\| R | N | B | Q | K | B | N | R | 1
        \\+---+---+---+---+---+---+---+---+
        \\  a   b   c   d   e   f   g   h  
        \\
        \\Fen         : rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
        \\Hash        : 5060803636482931868
    ;

    const actual_default = try uciBoardDiagram(board, .{});
    defer allocator.free(actual_default);
    try expectEqualSlices(u8, expected_default, actual_default);

    const expected_highlighted =
        \\+---+---+---+---+---+---+---+---+
        \\| r | n | b | q | k | b | n | r | 8
        \\+---+---+---+---+---+---+---+---+
        \\| p | p | p | p | p | p | p | p | 7
        \\+---+---+---+---+---+---+---+---+
        \\|   |   |   |   |   |   |   |   | 6
        \\+---+---+---+---+---+---+---+---+
        \\|   |   |   |   |   |   |   |   | 5
        \\+---+---+---+---+---+---+---+---+
        \\|   |   |   |   |   |   |   |   | 4
        \\+---+---+---+---+---+---+---+---+
        \\|   |   |   |   |   |( )|   |   | 3
        \\+---+---+---+---+---+---+---+---+
        \\| P | P | P | P | P | P | P | P | 2
        \\+---+---+---+---+---+---+---+---+
        \\| R | N | B | Q | K | B | N | R | 1
        \\+---+---+---+---+---+---+---+---+
        \\  a   b   c   d   e   f   g   h  
        \\
        \\Fen         : rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
        \\Hash        : 5060803636482931868
    ;

    const actual_highlighted = try uciBoardDiagram(board, .{
        .highlighted_move = uciToMove(board, "f2f3"),
    });
    defer allocator.free(actual_highlighted);
    try expectEqualSlices(u8, expected_highlighted, actual_highlighted);

    const expected_flipped =
        \\+---+---+---+---+---+---+---+---+
        \\| R | N | B | K | Q | B | N | R | 1
        \\+---+---+---+---+---+---+---+---+
        \\| P | P | P | P | P | P | P | P | 2
        \\+---+---+---+---+---+---+---+---+
        \\|   |   |   |   |   |   |   |   | 3
        \\+---+---+---+---+---+---+---+---+
        \\|   |   |   |   |   |   |   |   | 4
        \\+---+---+---+---+---+---+---+---+
        \\|   |   |   |   |   |   |   |   | 5
        \\+---+---+---+---+---+---+---+---+
        \\|   |   |   |   |   |   |   |   | 6
        \\+---+---+---+---+---+---+---+---+
        \\| p | p | p | p | p | p | p | p | 7
        \\+---+---+---+---+---+---+---+---+
        \\| r | n | b | k | q | b | n | r | 8
        \\+---+---+---+---+---+---+---+---+
        \\  h   g   f   e   d   c   b   a  
        \\
        \\Fen         : rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
        \\Hash        : 5060803636482931868
    ;

    const actual_flipped = try uciBoardDiagram(board, .{
        .black_at_top = false,
    });
    defer allocator.free(actual_flipped);
    try expectEqualSlices(u8, expected_flipped, actual_flipped);
}
