const std = @import("std");
const builtin = @import("builtin");

const types = @import("types.zig");
const Square = types.Square;
const File = types.File;
const Rank = types.Rank;

pub const Bitboard = struct {
    bits: u64,

    // ================ INITIALIZATION ================

    /// Creates a BB with all of the bits set to 0.
    pub inline fn init() Bitboard {
        return .{ .bits = 0 };
    }

    /// Creates a BB with all of the bits set to 1.
    pub inline fn full() Bitboard {
        return .{ .bits = std.math.maxInt(u64) };
    }

    /// Computes the rank mask from the given rank.
    ///
    /// Asserts that the rank is valid.
    pub inline fn fromRank(rank: Rank) Bitboard {
        std.debug.assert(rank.valid());
        return .{ .bits = rank.mask() };
    }

    /// Computes the file mask from the given file.
    ///
    /// Asserts that the file is valid.
    pub inline fn fromFile(file: File) Bitboard {
        std.debug.assert(file.valid());
        return .{ .bits = file.mask() };
    }

    /// Creates a BB with the only square's index set to 1.
    ///
    /// Asserts that the square is valid.
    pub inline fn fromSquare(square: Square) Bitboard {
        std.debug.assert(square.valid());
        return .{ .bits = @as(u64, 1) << @truncate(square.index()) };
    }

    /// Creates a BB from the given integer.
    ///
    /// Asserts that the int is unsigned.
    pub inline fn fromInt(comptime T: type, num: T) Bitboard {
        switch (@typeInfo(T)) {
            .int => |i| {
                std.debug.assert(i.signedness == .unsigned);
                return .{ .bits = @intCast(num) };
            },
            else => @compileError("T must be a known integer type"),
        }
    }

    // ================ BIT MANIPULATION ================

    /// Returns the index of the most significant bit.
    pub inline fn msb(self: *const Bitboard) Square {
        const most: u6 = @truncate(@clz(self.bits));
        return Square.fromInt(u6, 63 ^ most);
    }

    /// Returns the index of the lest significant bit.
    pub inline fn lsb(self: *const Bitboard) Square {
        const least: u6 = @truncate(@ctz(self.bits));
        return Square.fromInt(u6, least);
    }

    /// Returns the index of the lest significant bit and pops it from the BB.
    pub inline fn popLsb(self: *Bitboard) Square {
        defer self.bits &= (self.bits - 1);
        return self.lsb();
    }

    /// Toggles on the bit at the given index in the BB.
    ///
    /// Asserts that the int is less than 64.
    pub inline fn set(self: *Bitboard, index: usize) Bitboard {
        std.debug.assert(index < 64);
        self.bits |= (@as(u64, 1) << @truncate(index));
        return self.*;
    }

    /// Toggles off the bit at the given index in the BB.
    ///
    /// Asserts that the int is less than 64.
    pub inline fn remove(self: *Bitboard, index: usize) Bitboard {
        std.debug.assert(index < 64);
        self.bits &= ~(@as(u64, 1) << @truncate(index));
        return self.*;
    }

    /// Checks the state of the bit at the given index in the BB.
    ///
    /// Asserts that the int is less than 64.
    pub inline fn contains(self: *const Bitboard, index: usize) bool {
        std.debug.assert(index < 64);
        return (self.bits & (@as(u64, 1) << @truncate(index))) != 0;
    }

    /// Sets all of the bits in the BB to 0.
    pub inline fn clear(self: *Bitboard) void {
        self.bits = 0;
    }

    pub inline fn shl(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits << @truncate(rhs) };
    }

    pub inline fn shlInPlace(self: *Bitboard, rhs: u64) void {
        self.bits = self.bits << @truncate(rhs);
    }

    pub inline fn shr(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits >> @truncate(rhs) };
    }

    pub inline fn shrInPlace(self: *Bitboard, rhs: u64) void {
        self.bits = self.bits >> @truncate(rhs);
    }

    // ================= OPS WITH U64 =================

    pub inline fn andU64(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits & rhs };
    }

    pub inline fn orU64(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits | rhs };
    }

    pub inline fn xorU64(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits ^ rhs };
    }

    pub inline fn eqU64(self: *const Bitboard, rhs: u64) bool {
        return self.bits == rhs;
    }

    pub inline fn neqU64(self: *const Bitboard, rhs: u64) bool {
        return self.bits != rhs;
    }

    // ================= OPS WITH BITBOARD =================

    pub inline fn andBB(self: *const Bitboard, rhs: Bitboard) Bitboard {
        return .{ .bits = self.bits & rhs.bits };
    }

    pub inline fn orBB(self: *const Bitboard, rhs: Bitboard) Bitboard {
        return .{ .bits = self.bits | rhs.bits };
    }

    pub inline fn xorBB(self: *const Bitboard, rhs: Bitboard) Bitboard {
        return .{ .bits = self.bits ^ rhs.bits };
    }

    pub inline fn eqBB(self: *const Bitboard, rhs: Bitboard) bool {
        return self.bits == rhs.bits;
    }

    pub inline fn neqBB(self: *const Bitboard, rhs: Bitboard) bool {
        return self.bits != rhs.bits;
    }

    pub inline fn not(self: *const Bitboard) Bitboard {
        return .{ .bits = ~self.bits };
    }

    // ================= IN-PLACE OPS =================

    pub inline fn andAssign(self: *Bitboard, rhs: Bitboard) *Bitboard {
        self.bits &= rhs.bits;
        return self;
    }

    pub inline fn orAssign(self: *Bitboard, rhs: Bitboard) *Bitboard {
        self.bits |= rhs.bits;
        return self;
    }

    pub inline fn xorAssign(self: *Bitboard, rhs: Bitboard) *Bitboard {
        self.bits ^= rhs.bits;
        return self;
    }

    // ================ MISC UTILS ================

    /// Converts the BB into a 'board' representation. The board is:
    /// - Separated by newlines every 8 bits, separating each bit with a space
    /// - Printed from white's perspective
    pub fn asBoardStr(self: *const Bitboard) [127]u8 {
        var out: [127]u8 = undefined;
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

            const newline_idx = row * 16 + 15;
            if (newline_idx < 126) {
                out[newline_idx] = '\n';
            }
        }

        return out;
    }

    /// Returns the number of set bits in the BB.
    pub inline fn count(self: *const Bitboard) usize {
        return @popCount(self.bits);
    }

    /// Check if none of the bits in the BB are set.
    pub inline fn empty(self: *const Bitboard) bool {
        return self.count() == 0;
    }

    /// Check if any of the bits in the BB are set.
    pub inline fn nonzero(self: *const Bitboard) bool {
        return !self.empty();
    }

    // ================= WRAPPING ARITHMETIC =================

    pub inline fn addU64Wrapped(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits +% rhs };
    }

    pub inline fn subU64Wrapped(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits -% rhs };
    }

    pub inline fn mulU64Wrapped(self: *const Bitboard, rhs: u64) Bitboard {
        return .{ .bits = self.bits *% rhs };
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

test "Bitboard base" {
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

test "Bitboard string representation" {
    const allocator = testing.allocator;

    var empty = Bitboard.init();
    const expected_empty = try std.fmt.allocPrint(allocator, "{s}", .{
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
    });
    defer allocator.free(expected_empty);
    try expectEqualSlices(u8, expected_empty, empty.asBoardStr()[0..]);

    var full = Bitboard.full();
    const expected_full = try std.fmt.allocPrint(allocator, "{s}", .{
        \\1 1 1 1 1 1 1 1
        \\1 1 1 1 1 1 1 1
        \\1 1 1 1 1 1 1 1
        \\1 1 1 1 1 1 1 1
        \\1 1 1 1 1 1 1 1
        \\1 1 1 1 1 1 1 1
        \\1 1 1 1 1 1 1 1
        \\1 1 1 1 1 1 1 1
    });
    defer allocator.free(expected_full);
    try expectEqualSlices(u8, expected_full, full.asBoardStr()[0..]);

    const fa = Bitboard.fromFile(.fa);
    const expected_fa = try std.fmt.allocPrint(allocator, "{s}", .{
        \\1 0 0 0 0 0 0 0
        \\1 0 0 0 0 0 0 0
        \\1 0 0 0 0 0 0 0
        \\1 0 0 0 0 0 0 0
        \\1 0 0 0 0 0 0 0
        \\1 0 0 0 0 0 0 0
        \\1 0 0 0 0 0 0 0
        \\1 0 0 0 0 0 0 0
    });
    defer allocator.free(expected_fa);
    try expectEqualSlices(u8, expected_fa, fa.asBoardStr()[0..]);

    const r1 = Bitboard.fromRank(.r1);
    const expected_r1 = try std.fmt.allocPrint(allocator, "{s}", .{
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\1 1 1 1 1 1 1 1
    });
    defer allocator.free(expected_r1);
    try expectEqualSlices(u8, expected_r1, r1.asBoardStr()[0..]);

    const fcr4 = Bitboard.fromSquare(Square.make(.r4, .fc));
    const expected_fcr4 = try std.fmt.allocPrint(allocator, "{s}", .{
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 1 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
        \\0 0 0 0 0 0 0 0
    });
    defer allocator.free(expected_fcr4);
    try expectEqualSlices(u8, expected_fcr4, fcr4.asBoardStr()[0..]);
}

test "Bitboard operators" {
    var a = Bitboard.init();
    _ = a.set(0);
    _ = a.set(63);
    const b = Bitboard.fromSquare(Square.e4);

    // ================= SHIFTS =================
    var shl_a = a.shl(1);
    try expect(shl_a.contains(1));
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

test "BB arithmetic wrapping" {
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
