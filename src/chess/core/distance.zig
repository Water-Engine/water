const std = @import("std");

const types = @import("types.zig");
const Square = types.Square;

const square_fields = @typeInfo(Square).@"enum".fields;

pub const ManhattanDist = genManhattan();
pub const CenterManhattanDist = genCenterManhattan();
pub const ChebyshevDist = genChebyshev();
pub const ValueDist = genValueDistance();

fn genManhattan() [64][64]u8 {
    var table: [64][64]u8 = undefined;

    @setEvalBranchQuota(100_000_000); // Arbitrarily large quota
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

    @setEvalBranchQuota(100_000_000); // Arbitrarily large quota
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

    @setEvalBranchQuota(100_000_000); // Arbitrarily large quota
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

// ================ TESTING ================
const testing = std.testing;
const expectEqual = testing.expectEqual;

/// Manual manhattan distance from https://www.chessprogramming.org/Manhattan-Distance
fn manManDistance(sq1: i32, sq2: i32) u8 {
   const file1 = sq1  & 7;
   const file2 = sq2  & 7;
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
                ManhattanDist[b][a],
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
        try expectEqual(expected, CenterManhattanDist[i]);
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
                ChebyshevDist[b][a],
            );
        }
    }
}

test "Absolute Value Distance" {
    for (0..64) |a| {
        for (0..64) |b| {
            try expectEqual(if (a > b) a - b else b - a, ValueDist[a][b]);
        }
    }
}
