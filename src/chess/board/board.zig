const std = @import("std");

const bitboard = @import("../core/bitboard.zig");
const Bitboard = bitboard.Bitboard;

const types = @import("../core/types.zig");
const Color = types.Color;
const Square = types.Square;
const File = types.File;
const Rank = types.Rank;

const piece = @import("../core/piece.zig");
const Piece = piece.Piece;
const PieceType = piece.PieceType;

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

pub const Board = struct {
    allocator: std.mem.Allocator,

    original_fen: []const u8,
    previous_states: std.ArrayList(State),

    pieces_bbs: [6]Bitboard = @splat(Bitboard.init()),
    occ_bbs: [2]Bitboard = @splat(Bitboard.init()),
    mailbox: [64]Piece = @splat(Piece.none),

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
            .original_fen = fen,
            .previous_states = try std.ArrayList(State).initCapacity(allocator, 256),
        };
        return b;
    }

    pub fn deinit(self: *Board) void {
        self.previous_states.deinit(self.allocator);
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

test "Board initialization" {
    const allocator = testing.allocator;
    var board = try Board.init(allocator, StartingFen);
    defer {
        board.deinit();
        allocator.destroy(board);
    }

    // Verify that all fields are default initialized

    try expectEqualSlices(u8, StartingFen, board.original_fen);
    try expect(board.previous_states.items.len == 0);

    for (board.pieces_bbs) |bb| {
        try expectEqual(0, bb.bits);
    }

    for (board.occ_bbs) |bb| {
        try expectEqual(0, bb.bits);
    }

    for (board.mailbox) |p| {
        try expectEqual(Piece.none, p);
    }

    try expectEqual(0, board.key);

    for (board.castling_rights.rooks) |rf| {
        try expectEqual(File.none, rf[0]);
        try expectEqual(File.none, rf[1]);
    }

    try expectEqual(0, board.plies);
    try expectEqual(Color.white, board.side_to_move);
    try expectEqual(Square.none, board.ep_square);
    try expectEqual(0, board.halfmove_clock);

    try expectEqual(CastlingRights{}, board.castling_rights);

    for (board.castling_path) |c| {
        try expectEqual(0, c[0].bits);
        try expectEqual(0, c[1].bits);
    }
}
