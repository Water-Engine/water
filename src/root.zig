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

// ================ TESTING ================

test {
    _ = @import("chess/core/types.zig");
    _ = @import("chess/core/bitboard.zig");
    _ = @import("chess/core/distance.zig");
}
