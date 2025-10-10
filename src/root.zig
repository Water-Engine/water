pub const version: []const u8 = "0.0.0-dev";

const types = @import("water/core/types.zig");
pub const Color = types.Color;
pub const File = types.File;
pub const Rank = types.Rank;
pub const Square = types.Square;
pub const ChessError = types.ChessError;

const bitboard = @import("water/core/bitboard.zig");
pub const Bitboard = bitboard.Bitboard;

const distance = @import("water/core/distance.zig");
pub const manhattan_distance = distance.manhattan_distance;
pub const center_manhattan_distance = distance.center_manhattan_distance;
pub const chebyshev_distance = distance.chebyshev_distance;
pub const absolute_distance = distance.absolute_distance;
pub const squares_between = distance.squares_between;

const piece = @import("water/core/piece.zig");
pub const PieceType = piece.PieceType;
pub const Piece = piece.Piece;

const move = @import("water/core/move.zig");
pub const Move = move.Move;
pub const MoveType = move.MoveType;

pub const board = @import("water/board/board.zig");
pub const Board = board.Board;

pub const arbiter = @import("water/board/arbiter.zig");

const castling = @import("water/board/castling.zig");
pub const CastlingRights = castling.CastlingRights;

const state = @import("water/board/state.zig");
pub const State = state.State;
pub const Zobrist = state.Zobrist;

pub const uci = @import("water/core/uci.zig");

pub const attacks = @import("water/movegen/attacks.zig");
pub const movegen = @import("water/movegen/movegen.zig");

pub const engine = @import("water/framework/engine.zig");
pub const type_validators = @import("water/framework/type_validators.zig");
pub const dispatcher = @import("water/framework/dispatcher.zig");
pub const network = @import("water/framework/network.zig");

// ================ TESTING ================

test {
    _ = @import("water/core/types.zig");
    _ = @import("water/core/bitboard.zig");
    _ = @import("water/core/distance.zig");
    _ = @import("water/core/piece.zig");
    _ = @import("water/core/move.zig");
    _ = @import("water/core/uci.zig");

    _ = @import("water/board/arbiter.zig");
    _ = @import("water/board/board.zig");
    _ = @import("water/board/castling.zig");
    _ = @import("water/board/state.zig");

    _ = @import("water/movegen/attacks.zig");
    _ = @import("water/movegen/movegen.zig");
    _ = @import("water/movegen/generators.zig");

    _ = @import("water/framework/engine.zig");
    _ = @import("water/framework/type_validators.zig");
    _ = @import("water/framework/dispatcher.zig");
}
