pub const version: []const u8 = "0.0.0-dev";

const types = @import("chess/core/types.zig");
pub const Color = types.Color;
pub const File = types.File;
pub const Rank = types.Rank;
pub const Square = types.Square;
pub const ChessError = types.ChessError;

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

const move = @import("chess/core/move.zig");
pub const Move = move.Move;
pub const MoveType = move.MoveType;

pub const board = @import("chess/board/board.zig");
pub const Board = board.Board;

pub const arbiter = @import("chess/board/arbiter.zig");

const castling = @import("chess/board/castling.zig");
pub const CastlingRights = castling.CastlingRights;

const state = @import("chess/board/state.zig");
pub const State = state.State;
pub const Zobrist = state.Zobrist;

pub const uci = @import("chess/core/uci.zig");

pub const attacks = @import("chess/movegen/attacks.zig");
pub const movegen = @import("chess/movegen/movegen.zig");

pub const engine = @import("chess/engine/engine.zig");
pub const type_validators = @import("chess/engine/type_validators.zig");
pub const dispatcher = @import("chess/engine/dispatcher.zig");

// ================ TESTING ================

test {
    _ = @import("chess/core/types.zig");
    _ = @import("chess/core/bitboard.zig");
    _ = @import("chess/core/distance.zig");
    _ = @import("chess/core/piece.zig");
    _ = @import("chess/core/move.zig");
    _ = @import("chess/core/uci.zig");

    _ = @import("chess/board/arbiter.zig");
    _ = @import("chess/board/board.zig");
    _ = @import("chess/board/castling.zig");
    _ = @import("chess/board/state.zig");

    _ = @import("chess/movegen/attacks.zig");
    _ = @import("chess/movegen/movegen.zig");
    _ = @import("chess/movegen/generators.zig");

    _ = @import("chess/engine/engine.zig");
    _ = @import("chess/engine/type_validators.zig");
    _ = @import("chess/engine/dispatcher.zig");
}
