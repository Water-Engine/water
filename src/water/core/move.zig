const std = @import("std");

const types = @import("../core/types.zig");
const Square = types.Square;

const piece = @import("piece.zig");
const PieceType = piece.PieceType;

/// THe various types a move can be.
///
/// A null move 'corrupts' the square bits of the move.
pub const MoveType = enum(u16) {
    normal = 0,
    null_move = 65,
    promotion = @as(u16, 1) << @truncate(14),
    en_passant = @as(u16, 2) << @truncate(14),
    castling = @as(u16, 3) << @truncate(14),

    /// Creates a MoveType from the given integer.
    pub fn fromInt(comptime T: type, num: T) MoveType {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @enumFromInt(num),
            else => @compileError("T must be an integer type"),
        };
    }

    // Returns the enum value as the given integer type.
    pub fn asInt(self: *const MoveType, comptime T: type) T {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @intFromEnum(self.*),
            else => @compileError("T must be an integer type"),
        };
    }
};

/// A 16-bit-represented move ordered as:
/// - First 6 bits: to square
/// - Next 6 bits: from square
/// - Last 4 bits: type
///
/// Example: "e2e4" from startpos is:
/// `0000_001100_011100`
pub const Move = struct {
    move: u16,
    score: i32 = 0,

    /// Creates a zeroed move.
    ///
    /// THe uci representation of this is `a1a1`.
    pub fn init() Move {
        return .{ .move = 0 };
    }

    /// Checks if the move is the zero `a1a1` move.
    pub fn valid(self: *const Move) bool {
        return self.move != 0;
    }

    /// Creates a move with the given value and 0 score.
    pub fn fromMove(value: u16) Move {
        return .{ .move = value };
    }

    /// Creates a move from the source to the target square with the given options.
    ///
    /// The promotion type must always be between a knight and queen regardless of the move.
    pub fn make(
        source: Square,
        target: Square,
        comptime options: struct {
            move_type: MoveType = .normal,
            promotion_type: PieceType = .knight,
        },
    ) Move {
        const move_type = comptime options.move_type;
        const pt = comptime options.promotion_type;

        std.debug.assert(blk: {
            const knight_ord = pt.order(.knight);
            const queen_ord = pt.order(.queen);

            break :blk knight_ord != .lt and queen_ord != .gt;
        });

        const promotion_type = comptime pt.asInt(u16) - PieceType.knight.asInt(u16);
        const type_bits = comptime move_type.asInt(u16);
        const promotion_bits = comptime promotion_type << @truncate(12);
        const special = comptime type_bits + promotion_bits;

        const from_bits = source.asInt(u16) << @truncate(6);
        const to_bits = target.asInt(u16);

        return .{
            .move = special + from_bits + to_bits,
        };
    }

    /// Returns the `from` square stored in the move's bits.
    pub fn from(self: *const Move) Square {
        return Square.fromInt(u16, (self.move >> @truncate(6)) & 0x3F);
    }

    /// Returns the `to` square stored in the move's bits.
    pub fn to(self: *const Move) Square {
        return Square.fromInt(u16, self.move & 0x3F);
    }

    /// Returns the type of the move as an int or MoveType.
    pub fn typeOf(self: *const Move, comptime T: type) T {
        if (comptime T == MoveType) {
            const bits = self.move & (@as(u16, 3) << @truncate(14));
            return MoveType.fromInt(u16, bits);
        } else {
            return switch (@typeInfo(T)) {
                .int, .comptime_int => self.move & (@as(T, 3) << @truncate(14)),
                else => @compileError("T must be a MoveType or an integer type"),
            };
        }
    }

    /// Returns the promotion PieceType.
    ///
    /// Asserts that the moves flag is a promotion.
    pub fn promotionType(self: *const Move) PieceType {
        std.debug.assert(self.typeOf(MoveType) == .promotion);
        return PieceType.fromInt(u16, ((self.move >> @truncate(12)) & 3) + PieceType.knight.asInt(u16));
    }

    pub fn order(lhs: Move, rhs: Move, comptime by: enum { mv, sc }) std.math.Order {
        return switch (comptime by) {
            .mv => lhs.orderByMove(rhs),
            .sc => lhs.orderByScore(rhs),
        };
    }

    /// Compares the underlying integer representation of the moves.
    pub fn orderByMove(lhs: Move, rhs: Move) std.math.Order {
        const lhs_val = lhs.move;
        const rhs_val = rhs.move;

        return std.math.order(lhs_val, rhs_val);
    }

    /// Compares the underlying scores of the moves.
    pub fn orderByScore(lhs: Move, rhs: Move) std.math.Order {
        const lhs_val = lhs.score;
        const rhs_val = rhs.score;

        return std.math.order(lhs_val, rhs_val);
    }
};

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "Move" {
    try expectEqual(MoveType.normal, MoveType.fromInt(u16, 0));
    try expectEqual(MoveType.null_move, MoveType.fromInt(u16, 65));
    try expectEqual(MoveType.promotion, MoveType.fromInt(u16, 16384));
    try expectEqual(MoveType.en_passant, MoveType.fromInt(u16, 32768));
    try expectEqual(MoveType.castling, MoveType.fromInt(u16, 49152));

    const mt = MoveType.castling;
    try expectEqual(@as(u16, 49152), mt.asInt(u16));

    const empty = Move.init();
    try expect(!empty.valid());

    const opening_move = Move.make(.a2, .a3, .{});
    try expect(opening_move.valid());
    try expectEqual(528, opening_move.move);

    const same_move = Move.fromMove(opening_move.move);
    try expectEqual(opening_move.move, same_move.move);

    try expectEqual(@as(u16, 8), opening_move.from().asInt(u16));
    try expectEqual(@as(u16, 16), opening_move.to().asInt(u16));
    try expectEqual(MoveType.normal.asInt(u16), opening_move.typeOf(u16));

    const promo_move = Move.make(.e7, .e8, .{
        .move_type = .promotion,
        .promotion_type = .queen,
    });
    try expectEqual(MoveType.promotion.asInt(u16), promo_move.typeOf(u16));
    try expectEqual(MoveType.promotion, promo_move.typeOf(MoveType));
    try expectEqual(PieceType.queen, promo_move.promotionType());

    const m1 = Move.fromMove(100);
    const m2 = Move.fromMove(200);
    const m3 = Move.fromMove(100);

    try expect(m1.orderByMove(m3) == .eq);
    try expect(m1.orderByMove(m2) != .eq);
    try expect(m1.orderByMove(m2) == .lt);
    try expect(m2.orderByMove(m1) == .gt);

    var s1 = Move.fromMove(10);
    s1.score = 50;
    var s2 = Move.fromMove(20);
    s2.score = 100;
    var s3 = Move.fromMove(30);
    s3.score = 50;

    try expect(s1.orderByScore(s3) == .eq);
    try expect(s1.orderByScore(s2) != .eq);
    try expect(s1.orderByScore(s2) == .lt);
    try expect(s2.orderByScore(s1) == .gt);
}
