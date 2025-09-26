const std = @import("std");

const types = @import("../core/types.zig");
const Square = types.Square;

const piece = @import("piece.zig");
const PieceType = piece.PieceType;

pub const MoveType = enum(u16) {
    normal = 0,
    null_move = 65,
    promotion = @as(u16, 1) << @truncate(14),
    en_passant = @as(u16, 2) << @truncate(14),
    castling = @as(u16, 3) << @truncate(14),

    pub fn fromInt(comptime T: type, num: T) MoveType {
        switch (@typeInfo(T)) {
            .int, .comptime_int => {
                return switch (num) {
                    0 => .normal,
                    65 => .null_move,
                    16384 => .promotion,
                    32768 => .en_passant,
                    49152 => .castling,
                    else => .normal,
                };
            },
            else => @compileError("T must be an integer type"),
        }
    }

    pub fn asInt(self: *const MoveType, comptime T: type) T {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @intFromEnum(self.*),
            else => @compileError("T must be an integer type"),
        };
    }
};

pub const Move = struct {
    move: u16,
    score: i32 = 0,

    // ================ INITIALIZATION ================

    pub fn init() Move {
        return .{ .move = 0 };
    }

    pub fn valid(self: *const Move) bool {
        return self.move != 0;
    }

    pub fn fromMove(value: u16) Move {
        return .{ .move = value };
    }

    pub fn make(
        source: Square,
        target: Square,
        options: struct {
            move_type: MoveType = .normal,
            promotion_type: PieceType = .knight,
        },
    ) Move {
        const move_type = options.move_type;
        const pt = options.promotion_type;
        std.debug.assert(pt.gteq(.knight) and pt.lteq(.queen));

        const promotion_type = pt.asInt(u16) - PieceType.knight.asInt(u16);

        const type_bits = move_type.asInt(u16);
        const promotion_bits = promotion_type << @truncate(12);
        const from_bits = source.asInt(u16) << @truncate(6);
        const to_bits = target.asInt(u16);

        return .{
            .move = type_bits + promotion_bits + from_bits + to_bits,
        };
    }

    // ================ UTILITIES ================

    pub fn from(self: *const Move) Square {
        return Square.fromInt(u16, (self.move >> @truncate(6)) & 0x3F);
    }

    pub fn to(self: *const Move) Square {
        return Square.fromInt(u16, self.move & 0x3F);
    }

    /// Returns the type of the move as an int or MoveType.
    pub fn typeOf(self: *const Move, comptime T: type) T {
        if (T == MoveType) {
            const bits = self.move & (@as(u16, 3) << @truncate(14));
            return MoveType.fromInt(u16, bits);
        }

        switch (@typeInfo(T)) {
            .int, .comptime_int => return self.move & (@as(T, 3) << @truncate(14)),
            else => @compileError("T must be a MoveType or an integer type"),
        }
    }

    pub fn promotionType(self: *const Move) PieceType {
        std.debug.assert(self.typeOf(MoveType) == .promotion);
        return PieceType.fromInt(u16, ((self.move >> @truncate(12)) & 3) + PieceType.knight.asInt(u16));
    }

    // ================ MOVE COMPARISON ================

    pub fn eqMove(self: *const Move, other: Move) bool {
        return self.move == other.move;
    }

    pub fn neqMove(self: *const Move, other: Move) bool {
        return !self.eqMove(other);
    }

    pub fn ltMove(self: *const Move, other: Move) bool {
        return self.move < other.move;
    }

    pub fn gtMove(self: *const Move, other: Move) bool {
        return self.move > other.move;
    }

    pub fn lteqMove(self: *const Move, other: Move) bool {
        return self.move <= other.move;
    }

    pub fn gteqMove(self: *const Move, other: Move) bool {
        return self.move >= other.move;
    }

    // ================ SCORE COMPARISON ================

    pub fn eqScore(self: *const Move, other: Move) bool {
        return self.score == other.score;
    }

    pub fn neqScore(self: *const Move, other: Move) bool {
        return !self.eqScore(other);
    }

    pub fn ltScore(self: *const Move, other: Move) bool {
        return self.score < other.score;
    }

    pub fn gtScore(self: *const Move, other: Move) bool {
        return self.score > other.score;
    }

    pub fn lteqScore(self: *const Move, other: Move) bool {
        return self.score <= other.score;
    }

    pub fn gteqScore(self: *const Move, other: Move) bool {
        return self.score >= other.score;
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "Move" {
    // ================ MoveType tests ================
    try expectEqual(MoveType.normal, MoveType.fromInt(u16, 0));
    try expectEqual(MoveType.null_move, MoveType.fromInt(u16, 65));
    try expectEqual(MoveType.promotion, MoveType.fromInt(u16, 16384));
    try expectEqual(MoveType.en_passant, MoveType.fromInt(u16, 32768));
    try expectEqual(MoveType.castling, MoveType.fromInt(u16, 49152));

    const mt = MoveType.castling;
    try expectEqual(@as(u16, 49152), mt.asInt(u16));

    // ================ Initialization ================
    const empty = Move.init();
    try expect(!empty.valid());

    const opening_move = Move.make(.a2, .a3, .{});
    try expect(opening_move.valid());
    try expectEqual(528, opening_move.move);

    const same_move = Move.fromMove(opening_move.move);
    try expectEqual(opening_move.move, same_move.move);

    // ================ Utilities ================
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

    // ================ Move comparison ================
    const m1 = Move.fromMove(100);
    const m2 = Move.fromMove(200);
    const m3 = Move.fromMove(100);

    try expect(m1.eqMove(m3));
    try expect(m1.neqMove(m2));
    try expect(m1.ltMove(m2));
    try expect(m2.gtMove(m1));
    try expect(m1.lteqMove(m3));
    try expect(m2.gteqMove(m1));

    // ================ Score comparison ================
    var s1 = Move.fromMove(10);
    var s2 = Move.fromMove(20);
    s1.score = 50;
    s2.score = 100;

    try expect(s1.neqScore(s2));
    try expect(s1.ltScore(s2));
    try expect(s2.gtScore(s1));
    try expect(s1.lteqScore(s2));
    try expect(s2.gteqScore(s1));

    s2.score = 50;
    try expect(s1.eqScore(s2));
}
