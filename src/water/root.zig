const types = @import("core/types.zig");
pub const Color = types.Color;
pub const File = types.File;
pub const Rank = types.Rank;
pub const Square = types.Square;
pub const ChessError = types.ChessError;

const bitboard = @import("core/bitboard.zig");
pub const Bitboard = bitboard.Bitboard;

pub const distance = @import("core/distance.zig");

const piece = @import("core/piece.zig");
pub const PieceType = piece.PieceType;
pub const Piece = piece.Piece;

const move = @import("core/move.zig");
pub const Move = move.Move;
pub const MoveType = move.MoveType;

pub const board = @import("board/board.zig");
pub const Board = board.Board;

pub const arbiter = @import("board/arbiter.zig");

const castling = @import("board/castling.zig");
pub const CastlingRights = castling.CastlingRights;

const state = @import("board/state.zig");
pub const State = state.State;
pub const Zobrist = state.Zobrist;

pub const uci = @import("core/uci.zig");

pub const attacks = @import("movegen/attacks.zig");
pub const movegen = @import("movegen/movegen.zig");

pub const engine = @import("framework/engine.zig");
pub const type_validators = @import("framework/type_validators.zig");
pub const dispatcher = @import("framework/dispatcher.zig");
pub const network = @import("framework/network.zig");
pub const default_commands = @import("framework/default_commands.zig");

pub const mem = @import("syzygy/mem.zig");

test {
    _ = @import("core/types.zig");
    _ = @import("core/bitboard.zig");
    _ = @import("core/distance.zig");
    _ = @import("core/piece.zig");
    _ = @import("core/move.zig");
    _ = @import("core/uci.zig");

    _ = @import("board/arbiter.zig");
    _ = @import("board/board.zig");
    _ = @import("board/castling.zig");
    _ = @import("board/state.zig");

    _ = @import("movegen/attacks.zig");
    _ = @import("movegen/movegen.zig");
    _ = @import("movegen/generators.zig");

    _ = @import("framework/engine.zig");
    _ = @import("framework/type_validators.zig");
    _ = @import("framework/dispatcher.zig");

    _ = @import("syzygy/mem.zig");
}
