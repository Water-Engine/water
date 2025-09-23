const std = @import("std");

const types = @import("../core/types.zig");
const Color = types.Color;
const File = types.File;

pub const CastlingRights = struct {
    rooks: [2][2]File = @splat(@splat(File.init())),

    pub const Side = enum(u1) {
        queen = 0,
        king = 1,

        pub fn asInt(self: *const Side, comptime T: type) T {
            return switch (@typeInfo(T)) {
                .int, .comptime_int => @intFromEnum(self.*),
                else => @compileError("T must be an integer type"),
            };
        }

        pub fn index(self: *const Side) usize {
            return self.asInt(usize);
        }
    };

    pub fn clear(self: *CastlingRights) void {
        self.rooks = @splat(@splat(File.init()));
    }

    pub fn set(self: *CastlingRights, color: Color, side: Side, rook_file: File) void {
        self.rooks[color.index()][side.index()] = rook_file;
    }

    pub fn pop(self: *CastlingRights, comptime T: type, color: Color, side: Side) T {
        self.rooks[color.index()][side.index()] = .none;
        return color.asInt(T) * 2 + side.asInt(T);
    }

    pub fn hasSide(self: *const CastlingRights, color: Color, side: Side) bool {
        return self.rooks[color.index()][side.index()] != .none;
    }

    pub fn hasEither(self: *const CastlingRights, color: Color) bool {
        return self.hasSide(color, .king) or self.hasSide(color, .queen);
    }

    pub fn empty(self: *const CastlingRights) bool {
        return !self.hasEither(.white) and !self.hasEither(.black);
    }

    pub fn rookFile(self: *const CastlingRights, color: Color, side: Side) File {
        return self.rooks[color.index()][side.index()];
    }

    fn hasSideKey(self: *const CastlingRights, color: Color, side: Side) u64 {
        return @intFromBool(self.hasSide(color, side));
    }

    pub fn hash(self: *const CastlingRights) u64 {
        return self.hasSideKey(.white, .king) +
            2 * self.hasSideKey(.white, .queen) +
            4 * self.hasSideKey(.black, .king) +
            8 * self.hasSideKey(.black, .queen);
    }

    /// The `comparator` param should return true if lhs > rhs
    pub fn closestSide(
        comptime T: type,
        square: T,
        pred: T,
        comparator: *const fn (T, T) bool,
    ) Side {
        return if (comparator(square, pred)) .king else .queen;
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "CastlingRights" {
    var cr = CastlingRights{};

    // Initially empty
    try expect(cr.empty());
    try expect(!cr.hasSide(.white, .king));
    try expect(!cr.hasSide(.white, .queen));
    try expect(!cr.hasSide(.black, .king));
    try expect(!cr.hasSide(.black, .queen));
    try expectEqual(File.none, cr.rookFile(.white, .king));
    try expectEqual(File.none, cr.rookFile(.black, .queen));
    try expectEqual(@as(u64, 0), cr.hash());

    // Set castling rights
    cr.set(.white, .king, .fh);
    cr.set(.white, .queen, .fa);
    cr.set(.black, .king, .fh);
    cr.set(.black, .queen, .fa);

    try expect(cr.hasEither(.white));
    try expect(cr.hasEither(.black));
    try expect(cr.hasSide(.white, .king));
    try expect(cr.hasSide(.white, .queen));
    try expect(cr.hasSide(.black, .king));
    try expect(cr.hasSide(.black, .queen));
    try expectEqual(File.fh, cr.rookFile(.white, .king));
    try expectEqual(File.fa, cr.rookFile(.black, .queen));

    // Hash should reflect 4 sides present => 1+2+4+8=15
    try expectEqual(@as(u64, 15), cr.hash());

    // Pop castling rights
    const white_king_pop = cr.pop(u8, .white, .king);
    try expectEqual(@as(u8, 1), white_king_pop);
    try expect(!cr.hasSide(.white, .king));

    const black_queen_pop = cr.pop(u8, .black, .queen);
    try expectEqual(@as(u8, 2), black_queen_pop);
    try expect(!cr.hasSide(.black, .queen));

    // Clearing all rights
    cr.clear();
    try expect(cr.empty());

    // Test closestSide helper
    const greater = struct {
        fn cmp(lhs: u8, rhs: u8) bool {
            return lhs > rhs;
        }
    }.cmp;

    const s1 = CastlingRights.closestSide(u8, 7, 4, greater);
    const s2 = CastlingRights.closestSide(u8, 3, 5, greater);
    try expectEqual(CastlingRights.Side.king, s1);
    try expectEqual(CastlingRights.Side.queen, s2);

    // Side.index / asInt
    try expectEqual(@as(usize, 1), CastlingRights.Side.king.index());
    try expectEqual(@as(usize, 0), CastlingRights.Side.queen.index());
    try expectEqual(@as(u8, 1), CastlingRights.Side.king.asInt(u8));
    try expectEqual(@as(u8, 0), CastlingRights.Side.queen.asInt(u8));
}
