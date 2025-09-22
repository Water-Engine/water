const types = @import("chess/core/types.zig");
pub const Color = types.Color;
pub const File = types.File;
pub const Rank = types.Rank;
pub const Square = types.Square;

const bitboard = @import("chess/core/bitboard.zig");
pub const Bitboard = bitboard.Bitboard;

const distance = @import("chess/core/distance.zig");
pub const ManhattanDist = distance.ManhattanDist;
pub const CenterManhattanDist = distance.CenterManhattan;
pub const ChebyshevDist = distance.ChebyshevDist;
pub const ValueDist = distance.ValueDist;

const piece = @import("chess/core/piece.zig");
pub const PieceType = piece.PieceType;
pub const Piece = piece.Piece;

const attacks = @import("chess/movegen/attacks.zig");
pub const Attacks = attacks.Attacks;

const move = @import("chess/core/move.zig");
pub const Move = move.Move;
pub const MoveType = move.MoveType;

const board = @import("chess/board/board.zig");
pub const Board = board.Board;

const castling = @import("chess/board/castling.zig");
pub const CastlingRights = castling.CastlingRights;

const state = @import("chess/board/state.zig");
pub const State = state.State;
pub const Zobrist = state.Zobrist;

// ================ TESTING ================

test {
    _ = @import("chess/core/types.zig");
    _ = @import("chess/core/bitboard.zig");
    _ = @import("chess/core/distance.zig");
    _ = @import("chess/core/piece.zig");
    _ = @import("chess/core/move.zig");

    _ = @import("chess/board/board.zig");
    _ = @import("chess/board/castling.zig");
    _ = @import("chess/board/state.zig");

    _ = @import("chess/movegen/attacks.zig");
}
