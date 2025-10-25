const std = @import("std");

const types = @import("types.zig");
const Square = types.Square;

const bitboard = @import("bitboard.zig");
const Bitboard = bitboard.Bitboard;

const piece = @import("piece.zig");
const PieceType = piece.PieceType;

const attacks = @import("../movegen/attacks.zig");

const square_fields = @typeInfo(Square).@"enum".fields;

/// The 'rook' distance between two squares.
pub const manhattan = genManhattan();

/// The distance from a square to the 2x2 'center' of the board.
pub const center_manhattan = genCenterManhattan();

/// The 'king' distance between two squares.
///
/// The number of moves it would take a king to travel between indices.
pub const chebyshev = genChebyshev();

/// The absolute difference between two squares indices
pub const absolute = genValueDistance();

/// The 'ray' distance between two squares.
///
/// Nonzero if, and only if, the squares are aligned along a file, rank, or diagonal.
pub const squares_between = genSquaresBetween();

fn genManhattan() [64][64]u8 {
    var table: [64][64]u8 = undefined;

    @setEvalBranchQuota(100_000_000);
    inline for (square_fields) |a_field| {
        const sq_a = Square.fromInt(comptime_int, a_field.value);
        const fa = sq_a.file().asInt(i32);
        const ra = sq_a.rank().asInt(i32);
        inline for (square_fields) |b_field| {
            const sq_b = Square.fromInt(comptime_int, b_field.value);
            const fb = sq_b.file().asInt(i32);
            const rb = sq_b.rank().asInt(i32);

            if (sq_a.valid() and sq_b.valid()) {
                table[sq_a.index()][sq_b.index()] = @intCast(
                    @abs(fa - fb) + @abs(ra - rb),
                );
            }
        }
    }
    return table;
}

fn genChebyshev() [64][64]u8 {
    var table: [64][64]u8 = undefined;

    @setEvalBranchQuota(100_000_000);
    inline for (square_fields) |a_field| {
        const sq_a = Square.fromInt(comptime_int, a_field.value);
        const fa = sq_a.file().asInt(i32);
        const ra = sq_a.rank().asInt(i32);
        inline for (square_fields) |b_field| {
            const sq_b = Square.fromInt(comptime_int, b_field.value);
            const fb = sq_b.file().asInt(i32);
            const rb = sq_b.rank().asInt(i32);

            const file_dist = @abs(fa - fb);
            const rank_dist = @abs(ra - rb);

            if (sq_a.valid() and sq_b.valid()) {
                table[sq_a.index()][sq_b.index()] = @intCast(@max(file_dist, rank_dist));
            }
        }
    }
    return table;
}

fn genCenterManhattan() [64]u8 {
    var table: [64]u8 = undefined;
    inline for (square_fields) |sq_field| {
        const sq = Square.fromInt(comptime_int, sq_field.value);
        const f = sq.file().asInt(i32);
        const r = sq.rank().asInt(i32);

        const center_file: i32 = @max(3 - f, f - 4);
        const center_rank: i32 = @max(3 - r, r - 4);

        if (sq.valid()) {
            table[sq.index()] = @intCast(center_file + center_rank);
        }
    }
    return table;
}

fn genValueDistance() [64][64]u8 {
    var table: [64][64]u8 = undefined;

    @setEvalBranchQuota(100_000_000);
    inline for (square_fields) |a_field| {
        inline for (square_fields) |b_field| {
            const sq_a = Square.fromInt(comptime_int, a_field.value);
            const sq_b = Square.fromInt(comptime_int, b_field.value);

            if (sq_a.valid() and sq_b.valid()) {
                table[sq_a.index()][sq_b.index()] = @abs(sq_a.asInt(i32) - sq_b.asInt(i32));
            }
        }
    }
    return table;
}

fn attacksOf(comptime pt: PieceType, comptime sq: Square, comptime occ: Bitboard) Bitboard {
    return if (pt == .bishop) attacks.bishop(sq, occ) else attacks.rook(sq, occ);
}

fn genSquaresBetween() [64][64]Bitboard {
    var table: [64][64]Bitboard = @splat(@splat(Bitboard.init()));

    @setEvalBranchQuota(100_000_000);
    inline for (square_fields) |a_field| {
        inline for ([_]PieceType{ .bishop, .rook }) |pt| {
            inline for (square_fields) |b_field| {
                const sq_a = Square.fromInt(comptime_int, a_field.value);
                const sq_b = Square.fromInt(comptime_int, b_field.value);

                if (sq_a.valid() and sq_b.valid()) {
                    if (attacksOf(pt, sq_a, Bitboard.init()).contains(sq_b.index())) {
                        const sq_a_attacks = attacksOf(pt, sq_a, Bitboard.fromSquare(sq_b));
                        const sq_b_attacks = attacksOf(pt, sq_b, Bitboard.fromSquare(sq_a));
                        table[sq_a.index()][sq_b.index()] = sq_a_attacks.andBB(sq_b_attacks);
                    }

                    _ = table[sq_a.index()][sq_b.index()].set(sq_b.index());
                }
            }
        }
    }

    return table;
}

const testing = std.testing;
const expectEqual = testing.expectEqual;

/// Manual manhattan distance from https://www.chessprogramming.org/Manhattan-Distance
fn manManDistance(sq1: i32, sq2: i32) u8 {
    const file1 = sq1 & 7;
    const file2 = sq2 & 7;
    const rank1 = sq1 >> 3;
    const rank2 = sq2 >> 3;
    const rankDistance = @abs(rank2 - rank1);
    const fileDistance = @abs(file2 - file1);
    return @intCast(rankDistance + fileDistance);
}

test "Manhattan Distance" {
    for (0..64) |a| {
        for (0..64) |b| {
            try expectEqual(
                manManDistance(@intCast(a), @intCast(b)),
                manhattan[b][a],
            );
        }
    }
}

test "Center Manhattan Distance" {
    // Expected values from https://www.chessprogramming.org/Center_Manhattan-Distance
    const expecteds = &[64]u8{
        6, 5, 4, 3, 3, 4, 5, 6,
        5, 4, 3, 2, 2, 3, 4, 5,
        4, 3, 2, 1, 1, 2, 3, 4,
        3, 2, 1, 0, 0, 1, 2, 3,
        3, 2, 1, 0, 0, 1, 2, 3,
        4, 3, 2, 1, 1, 2, 3, 4,
        5, 4, 3, 2, 2, 3, 4, 5,
        6, 5, 4, 3, 3, 4, 5, 6,
    };
    for (expecteds, 0..) |expected, i| {
        try expectEqual(expected, center_manhattan[i]);
    }
}

/// Manual chebyshev distance from https://www.chessprogramming.org/Distance
fn manChevDistance(sq1: i32, sq2: i32) u8 {
    const file1 = sq1 & 7;
    const file2 = sq2 & 7;
    const rank1 = sq1 >> 3;
    const rank2 = sq2 >> 3;
    const rankDistance = @abs(rank2 - rank1);
    const fileDistance = @abs(file2 - file1);
    return @intCast(@max(rankDistance, fileDistance));
}

test "Chebyshev Distance" {
    for (0..64) |a| {
        for (0..64) |b| {
            try expectEqual(
                manChevDistance(@intCast(a), @intCast(b)),
                chebyshev[b][a],
            );
        }
    }
}

test "Absolute Value Distance" {
    for (0..64) |a| {
        for (0..64) |b| {
            try expectEqual(if (a > b) a - b else b - a, absolute[a][b]);
        }
    }
}

test "Squares between" {
    // Expected Values from https://github.com/Disservin/chess-library
    const expected_diagonal_u64: [64]u64 = .{
        0x0000000000000001, 0x0000000000000002, 0x0000000000000004, 0x0000000000000008,
        0x0000000000000010, 0x0000000000000020, 0x0000000000000040, 0x0000000000000080,
        0x0000000000000100, 0x0000000000000200, 0x0000000000000400, 0x0000000000000800,
        0x0000000000001000, 0x0000000000002000, 0x0000000000004000, 0x0000000000008000,
        0x0000000000010000, 0x0000000000020000, 0x0000000000040000, 0x0000000000080000,
        0x0000000000100000, 0x0000000000200000, 0x0000000000400000, 0x0000000000800000,
        0x0000000001000000, 0x0000000002000000, 0x0000000004000000, 0x0000000008000000,
        0x0000000010000000, 0x0000000020000000, 0x0000000040000000, 0x0000000080000000,
        0x0000000100000000, 0x0000000200000000, 0x0000000400000000, 0x0000000800000000,
        0x0000001000000000, 0x0000002000000000, 0x0000004000000000, 0x0000008000000000,
        0x0000010000000000, 0x0000020000000000, 0x0000040000000000, 0x0000080000000000,
        0x0000100000000000, 0x0000200000000000, 0x0000400000000000, 0x0000800000000000,
        0x0001000000000000, 0x0002000000000000, 0x0004000000000000, 0x0008000000000000,
        0x0010000000000000, 0x0020000000000000, 0x0040000000000000, 0x0080000000000000,
        0x0100000000000000, 0x0200000000000000, 0x0400000000000000, 0x0800000000000000,
        0x1000000000000000, 0x2000000000000000, 0x4000000000000000, 0x8000000000000000,
    };

    const expected_diagonals: [64]Bitboard = attacks.toBitboardArray(
        @TypeOf(expected_diagonal_u64),
        expected_diagonal_u64,
    );

    for (0..64) |i| {
        try expectEqual(expected_diagonals[i].bits, squares_between[i][i].bits);
    }
}
