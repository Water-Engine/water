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

    /// Clears both color's rights
    pub fn clear(self: *CastlingRights) void {
        self.rooks = @splat(@splat(File.init()));
    }

    /// Clears the specified color's rights
    pub fn clearColor(self: *CastlingRights, color: Color) void {
        self.rooks[color.index()][0] = .none;
        self.rooks[color.index()][1] = .none;
    }

    /// Gives the right to castle for a color on the specified side
    pub fn set(self: *CastlingRights, color: Color, side: Side, rook_file: File) void {
        self.rooks[color.index()][side.index()] = rook_file;
    }

    /// Removes the right to castle for a color on the specified side.
    ///
    /// The index is returned as an int `T`.
    pub fn pop(self: *CastlingRights, comptime T: type, color: Color, side: Side) T {
        self.rooks[color.index()][side.index()] = .none;
        return color.asInt(T) * 2 + (1 - side.asInt(T));
    }

    /// Determines if a color has the side's right
    pub fn hasSide(self: *const CastlingRights, color: Color, side: Side) bool {
        return self.rooks[color.index()][side.index()] != .none;
    }

    /// Determines if a color has either side's right
    pub fn hasEither(self: *const CastlingRights, color: Color) bool {
        return self.hasSide(color, .king) or self.hasSide(color, .queen);
    }

    /// Determines if any color can castle
    pub fn empty(self: *const CastlingRights) bool {
        return !self.hasEither(.white) and !self.hasEither(.black);
    }

    /// Determines which color's side's rook is on.
    pub fn rookFile(self: *const CastlingRights, color: Color, side: Side) File {
        return self.rooks[color.index()][side.index()];
    }

    /// Determines if a color has the side's right and returns as an integer type
    fn hasSideKey(self: *const CastlingRights, color: Color, side: Side) u64 {
        return @intFromBool(self.hasSide(color, side));
    }

    /// Converts the underlying data into zobrist-useable hash information.
    pub fn hash(self: *const CastlingRights) u64 {
        return self.hasSideKey(.white, .king) +
            2 * self.hasSideKey(.white, .queen) +
            4 * self.hasSideKey(.black, .king) +
            8 * self.hasSideKey(.black, .queen);
    }

    /// Returns the fen castle string based on the hash representation.
    ///
    /// Zero allocation, extremely efficient.
    pub fn asStr(self: *const CastlingRights) []const u8 {
        return switch (self.hash()) {
            0b0001 => "K",
            0b0011 => "KQ",
            0b0111 => "KQk",
            0b1111 => "KQkq",
            0b0010 => "Q",
            0b0110 => "Qk",
            0b1110 => "Qkq",
            0b0100 => "k",
            0b0101 => "Kk",
            0b1100 => "kq",
            0b1000 => "q",
            0b1001 => "Kq",
            0b1011 => "KQq",
            0b1010 => "Qq",
            0b1101 => "Kkq",
            else => "-",
        };
    }

    /// Returns `.king` if square > pred.
    pub fn closestSide(
        comptime T: type,
        square: T,
        pred: T,
        order_fn: *const fn (T, T) std.math.Order,
    ) Side {
        return if (order_fn(square, pred) == .gt) .king else .queen;
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

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
    try expectEqualSlices(u8, "KQkq", cr.asStr());

    try expectEqual(File.fh, cr.rookFile(.white, .king));
    try expectEqual(File.fa, cr.rookFile(.black, .queen));

    // Hash should reflect 4 sides present => 1+2+4+8=15
    try expectEqual(@as(u64, 15), cr.hash());

    // Pop castling rights
    const white_king_pop = cr.pop(u8, .white, .king);
    try expectEqualSlices(u8, "Qkq", cr.asStr());
    try expectEqual(0, white_king_pop);
    try expect(!cr.hasSide(.white, .king));

    const black_queen_pop = cr.pop(u8, .black, .queen);
    try expectEqualSlices(u8, "Qk", cr.asStr());
    try expectEqual(3, black_queen_pop);
    try expect(!cr.hasSide(.black, .queen));

    // Clearing all rights
    cr.clear();
    try expect(cr.empty());

    // Test closestSide helper
    const order = struct {
        fn order(lhs: u8, rhs: u8) std.math.Order {
            return std.math.order(lhs, rhs);
        }
    }.order;

    const s1 = CastlingRights.closestSide(u8, 7, 4, order);
    const s2 = CastlingRights.closestSide(u8, 3, 5, order);
    try expectEqual(CastlingRights.Side.king, s1);
    try expectEqual(CastlingRights.Side.queen, s2);

    // Side.index / asInt
    try expectEqual(@as(usize, 1), CastlingRights.Side.king.index());
    try expectEqual(@as(usize, 0), CastlingRights.Side.queen.index());
    try expectEqual(@as(u8, 1), CastlingRights.Side.king.asInt(u8));
    try expectEqual(@as(u8, 0), CastlingRights.Side.queen.asInt(u8));
}
