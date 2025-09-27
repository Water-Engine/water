const std = @import("std");

const types = @import("types.zig");
const Square = types.Square;
const File = types.File;
const Rank = types.Rank;

pub const Bitboard = struct {
    bits: u64,

    // ================ INITIALIZATION ================

    pub fn init() Bitboard {
        return .{ .bits = 0 };
    }

    pub fn fromRank(rank: Rank) Bitboard {
        return if (rank.valid()) .{ .bits = rank.mask() } else .{ .bits = 0 };
    }

    pub fn fromFile(file: File) Bitboard {
        return if (file.valid()) .{ .bits = file.mask() } else .{ .bits = 0 };
    }

    pub fn fromSquare(square: Square) Bitboard {
        return if (square.valid()) .{ .bits = @as(u64, 1) << @truncate(square.index()) } else .{ .bits = 0 };
    }

    pub fn fromInt(comptime T: type, num: T) Bitboard {
        switch (@typeInfo(T)) {
            .int, .comptime_int => {
                return if (num < 0 or num > std.math.maxInt(u64)) blk: {
                    break :blk .{ .bits = 0 };
                } else blk: {
                    break :blk .{ .bits = @intCast(num) };
                };
            },
            else => @compileError("T must be an integer type"),
        }
    }

    // ================ BIT MANIPULATION ================

    pub fn msb(self: *const Bitboard) Square {
        const least: u6 = @truncate(@clz(self.bits));
        return Square.fromInt(u6, 63 ^ least);
    }

    pub fn lsb(self: *const Bitboard) Square {
        const least: u6 = @truncate(@ctz(self.bits));
        return Square.fromInt(u6, least);
    }

    pub fn popLsb(self: *Bitboard) Square {
        defer self.bits &= (self.bits - 1);
        return self.lsb();
    }

    pub fn set(self: *Bitboard, index: usize) Bitboard {
        if (index > 63) return self.*;
        self.bits |= (@as(u64, 1) << @truncate(index));
        return self.*;
    }

    pub fn remove(self: *Bitboard, index: usize) Bitboard {
        if (index > 63) return self.*;
        self.bits &= ~(@as(u64, 1) << @truncate(index));
        return self.*;
    }

    pub fn contains(self: *const Bitboard, index: usize) bool {
        if (index > 63) return false;
        return (self.bits & (@as(u64, 1) << @truncate(index))) != 0;
    }

    pub fn clear(self: *Bitboard) void {
        self.bits = 0;
    }

    pub fn shl(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits << @truncate(rhs) };
    }

    pub fn shlInPlace(self: *Bitboard, rhs: u64) void {
        self.bits = self.bits << @truncate(rhs);
    }

    pub fn shr(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits >> @truncate(rhs) };
    }

    pub fn shrInPlace(self: *Bitboard, rhs: u64) void {
        self.bits = self.bits >> @truncate(rhs);
    }

    // ================= OPS WITH U64 =================

    pub fn andU64(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits & rhs };
    }

    pub fn orU64(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits | rhs };
    }

    pub fn xorU64(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits ^ rhs };
    }

    pub fn eqU64(self: *const Bitboard, rhs: u64) bool {
        return self.bits == rhs;
    }

    pub fn neqU64(self: *const Bitboard, rhs: u64) bool {
        return self.bits != rhs;
    }

    // ================= OPS WITH BITBOARD =================

    pub fn andBB(self: *const Bitboard, rhs: Bitboard) Bitboard {
        return .{ .bits = self.bits & rhs.bits };
    }

    pub fn orBB(self: *const Bitboard, rhs: Bitboard) Bitboard {
        return .{ .bits = self.bits | rhs.bits };
    }

    pub fn xorBB(self: *const Bitboard, rhs: Bitboard) Bitboard {
        return .{ .bits = self.bits ^ rhs.bits };
    }

    pub fn eqBB(self: *const Bitboard, rhs: Bitboard) bool {
        return self.bits == rhs.bits;
    }

    pub fn neqBB(self: *const Bitboard, rhs: Bitboard) bool {
        return self.bits != rhs.bits;
    }

    pub fn not(self: *const Bitboard) Bitboard {
        return .{ .bits = ~self.bits };
    }

    // ================= IN-PLACE OPS =================

    pub fn andAssign(self: *Bitboard, rhs: Bitboard) *Bitboard {
        self.bits &= rhs.bits;
        return self;
    }

    pub fn orAssign(self: *Bitboard, rhs: Bitboard) *Bitboard {
        self.bits |= rhs.bits;
        return self;
    }

    pub fn xorAssign(self: *Bitboard, rhs: Bitboard) *Bitboard {
        self.bits ^= rhs.bits;
        return self;
    }

    // ================ MISC UTILS ================

    pub fn asBoardStr(self: *const Bitboard) [128]u8 {
        var out: [128]u8 = undefined;
        const bits: u64 = @bitReverse(self.bits);

        for (0..8) |row| {
            const row_shift: u6 = @intCast(row * 8);
            const byte: u64 = @intCast(bits >> @truncate(row_shift));

            for (0..8) |col| {
                const bit_index = 7 - col;
                const bit = (@as(u64, byte) >> @truncate(bit_index)) & 1;
                out[row * 16 + col * 2] = if (bit != 0) '1' else '0';

                if (col != 7) out[row * 16 + col * 2 + 1] = ' ';
            }

            out[row * 16 + 15] = '\n';
        }

        return out;
    }

    pub fn count(self: *const Bitboard) usize {
        return @popCount(self.bits);
    }

    pub fn empty(self: *const Bitboard) bool {
        return self.count() == 0;
    }

    pub fn nonzero(self: *const Bitboard) bool {
        return !self.empty();
    }

    // ================= WRAPPING ARITHMETIC =================

    pub fn addU64Wrapped(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits +% rhs };
    }

    pub fn subU64Wrapped(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits -% rhs };
    }

    pub fn mulU64Wrapped(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits *% rhs };
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "Bitboard Base" {
    var empty = Bitboard.init();
    try expect(empty.bits == 0);
    try expect(empty.empty());
    try expect(!empty.nonzero());
    try expectEqual(0, empty.count());

    // ================ FROM RANK / FILE / SQUARE / INT ================
    const r2 = Rank.r2;
    const fa = File.fa;
    const sq_e4 = Square.e4;

    var bb_rank = Bitboard.fromRank(r2);
    try expect(bb_rank.nonzero());
    try expect(bb_rank.contains(8));
    try expect(bb_rank.contains(15));
    try expect(!bb_rank.contains(0));

    var bb_file = Bitboard.fromFile(fa);
    try expect(bb_file.nonzero());
    try expect(bb_file.contains(0));
    try expect(bb_file.contains(56));
    try expect(!bb_file.contains(1));

    var bb_square = Bitboard.fromSquare(sq_e4);
    try expect(bb_square.nonzero());
    try expect(bb_square.contains(sq_e4.index()));
    try expect(!bb_square.contains(sq_e4.index() + 1));

    var bb_int = Bitboard.fromInt(u64, 0xFF00FF00FF00FF00);
    try expect(bb_int.nonzero());
    try expect(bb_int.contains(8));
    try expect(bb_int.contains(24));
    try expect(!bb_int.contains(0));

    // ================ SET / REMOVE / CONTAINS ================
    var bb = Bitboard.init();
    _ = bb.set(0);
    try expect(bb.contains(0));
    try expect(!bb.contains(1));
    _ = bb.set(63);
    try expect(bb.contains(63));

    _ = bb.remove(0);
    try expect(!bb.contains(0));
    _ = bb.remove(63);
    try expect(!bb.contains(63));

    _ = bb.set(64);
    _ = bb.remove(64);
    try expect(!bb.contains(64));

    // ================ POP LSB / LSB / MSB ================
    bb = Bitboard.init();
    _ = bb.set(0);
    _ = bb.set(7);
    _ = bb.set(63);

    var lsb_sq = bb.lsb();
    try expect(lsb_sq.index() == 0);
    var msb_sq = bb.msb();
    try expect(msb_sq.index() == 63);

    var popped = bb.popLsb();
    try expect(popped.index() == 0);
    try expect(!bb.contains(0));
    try expect(bb.count() == 2);

    // ================ COUNT / EMPTY / NONZERO ================
    bb.clear();
    try expect(bb.empty());
    try expect(!bb.nonzero());
    try expectEqual(0, bb.count());

    _ = bb.set(1);
    _ = bb.set(2);
    try expect(!bb.empty());
    try expect(bb.nonzero());
    try expectEqual(2, bb.count());

    // ================ EDGE CASES ================
    bb.clear();
    for (0..64) |i| {
        _ = bb.set(i);
    }
    try expectEqual(64, bb.count());
    for (0..64) |i| {
        try expect(bb.contains(i));
    }

    bb.clear();
    try expectEqual(0, bb.count());

    // ================ POPULATED SEQUENCE ================
    bb = Bitboard.init();
    _ = bb.set(1);
    _ = bb.set(3);
    _ = bb.set(5);
    var indices: [3]usize = undefined;
    var idx: usize = 0;
    while (bb.nonzero()) {
        indices[idx] = bb.popLsb().index();
        idx += 1;
    }
    try expectEqual(indices[0], 1);
    try expectEqual(indices[1], 3);
    try expectEqual(indices[2], 5);
    try expectEqual(bb.count(), 0);
}

test "Bitboard Operators" {
    var a = Bitboard.init();
    _ = a.set(0);
    _ = a.set(63);
    const b = Bitboard.fromSquare(Square.e4);

    // ================= SHIFTS =================
    var shl_a = a.shl(1);
    try expect(shl_a.contains(1));
    try expect(shl_a.contains(64) == false);
    var shr_a = a.shr(1);
    try expect(shr_a.contains(62));
    try expect(shr_a.contains(63) == false);

    // ================= OPS WITH U64 =================
    var and_u64 = a.andU64(0x1);
    try expect(and_u64.contains(0));
    try expect(!and_u64.contains(63));

    var or_u64 = a.orU64(0x2);
    try expect(or_u64.contains(1));
    try expect(or_u64.contains(63));

    var xor_u64 = a.xorU64(0x1);
    try expect(!xor_u64.contains(0));
    try expect(xor_u64.contains(63));

    try expect(a.eqU64(a.bits));
    try expect(!a.eqU64(0));
    try expect(a.neqU64(0));
    try expect(!a.neqU64(a.bits));

    // ================= OPS WITH BITBOARD =================
    var and_bb = a.andBB(b);
    try expect(and_bb.count() <= 1);
    var or_bb = a.orBB(b);
    try expect(or_bb.contains(0));
    try expect(or_bb.contains(63));
    try expect(or_bb.contains(b.lsb().index()));

    var xor_bb = a.xorBB(b);
    try expect(xor_bb.contains(0));
    try expect(xor_bb.contains(63) or xor_bb.contains(b.lsb().index()));

    try expect(a.eqBB(a));
    try expect(!a.eqBB(b));
    try expect(a.neqBB(b));
    try expect(!a.neqBB(a));

    var not_a = a.not();
    try expect(!not_a.contains(0));
    try expect(!not_a.contains(63));
    try expect(not_a.contains(1));

    // ================= IN-PLACE OPS =================
    var c = a;
    _ = c.andAssign(b);
    try expect(c.count() <= 1);

    c = a;
    _ = c.orAssign(b);
    try expect(c.contains(0));
    try expect(c.contains(63));
    try expect(c.contains(b.lsb().index()));

    c = a;
    _ = c.xorAssign(b);
    try expect(c.contains(0));
    try expect(c.contains(63) or c.contains(b.lsb().index()));

    // ================= BOOLEAN OPS =================
    try expect(a.nonzero() and b.nonzero());
    try expect(a.nonzero() or Bitboard.init().nonzero());
}

test "BB Arithmetic Wrapping" {
    var bb = Bitboard{ .bits = std.math.maxInt(u64) };

    // ====== ADD ======
    const added = bb.addU64Wrapped(1);
    try expectEqual(@as(u64, 0), added.bits);

    // ====== SUB ======
    bb = Bitboard{ .bits = 0 };
    const subbed = bb.subU64Wrapped(1);
    try expectEqual(std.math.maxInt(u64), subbed.bits);

    // ====== MUL ======
    bb = Bitboard{ .bits = 2 };
    const muld = bb.mulU64Wrapped(std.math.maxInt(u64));
    try expectEqual(@as(u64, std.math.maxInt(u64) - 1), muld.bits);
}
