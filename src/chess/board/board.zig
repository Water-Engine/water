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

    pub fn reset(self: *Board) void {
        self.pieces_bbs = @splat(Bitboard.init());
        self.occ_bbs = @splat(Bitboard.init());
        self.mailbox = @splat(Piece.none);

        self.side_to_move = .white;
        self.ep_square = .none;
        self.halfmove_clock = 0;
        self.plies = 1;
        self.key = 0;
        self.castling_rights.clear();
        self.previous_states.clearRetainingCapacity();
    }

    pub fn setFen(self: *Board, fen: []const u8) bool {
        self.original_fen = fen;
        self.reset();

        const trimmed = std.mem.trim(u8, fen, " ");
        if (trimmed.len == 0) return false;

        const split_fen: [6]?[]const u8 = split_fen_string(6, trimmed, ' ');
        const pos: []const u8 = if (split_fen[0]) |first| first else "";
        const stm: []const u8 = if (split_fen[1]) |first| first else "w";
        const castle: []const u8 = if (split_fen[2]) |first| first else "-";
        const ep: []const u8 = if (split_fen[3]) |first| first else "-";
        const hmc: []const u8 = if (split_fen[4]) |first| first else "0";
        const fmc: []const u8 = if (split_fen[5]) |first| first else "1";

        if (pos.len == 0) return false;
        if (!std.mem.eql(u8, stm, "w") and !std.mem.eql(u8, stm, "b")) return false;

        self.halfmove_clock = std.fmt.parseInt(u8, hmc, 10) catch 0;
        self.plies = std.fmt.parseInt(u8, fmc, 10) catch 1;
        self.plies = self.plies * 2 - 2;

        if (!std.mem.eql(u8, ep, "-")) {
            const sq = Square.fromStr(ep);
            if (!sq.valid()) return false;

            self.ep_square = sq;
        }

        self.side_to_move = if (std.mem.eql(u8, stm, "w")) .white else .black;
        if (self.side_to_move.isBlack()) {
            self.plies += 1;
        } else {
            self.key ^= Zobrist.sideToMove();
        }

        // Todo, parse position and castling
        _ = castle;
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
