const std = @import("std");

const castling = @import("../board/castling.zig");
const CastlingRights = castling.CastlingRights;

// ================ ERRORS ================

const ChessError = error{};

// ================ COLOR ================

pub const Color = enum(u8) {
    white = 0,
    black = 1,
    none = 2,

    pub fn init() Color {
        return .none;
    }

    pub fn valid(self: *const Color) bool {
        return self.* != .none;
    }

    // ================ INT UTILS ================

    pub fn fromInt(comptime T: type, num: T) Color {
        const exhausted = comptime T == u1;
        if (exhausted) {
            return switch (num) {
                0 => .white,
                1 => .black,
            };
        }

        switch (@typeInfo(T)) {
            .int, .comptime_int => {
                return switch (num) {
                    0 => .white,
                    1 => .black,
                    else => .none,
                };
            },
            else => @compileError("T must be an integer type"),
        }
    }

    pub fn asInt(self: *const Color, comptime T: type) T {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @intFromEnum(self.*),
            else => @compileError("T must be an integer type"),
        };
    }

    pub fn index(self: *const Color) usize {
        return self.asInt(usize);
    }

    // ================ SLICE UTILS ================

    pub fn fromStr(str: []const u8) Color {
        return if (str.len == 0) .none else fromChar(str[0]);
    }

    pub fn asStr(self: *const Color) []const u8 {
        return @tagName(self.*);
    }

    // ================ CHAR UTILS ================

    pub fn fromChar(char: u8) Color {
        return switch (std.ascii.toLower(char)) {
            'w' => .white,
            'b' => .black,
            else => .none,
        };
    }

    pub fn asChar(self: *const Color) u8 {
        return switch (self.*) {
            .white => 'w',
            .black => 'b',
            .none => '-',
        };
    }

    // ================ COMPARISON ================

    pub fn eq(self: *const Color, other: Color) bool {
        return self.asInt(i32) == other.asInt(i32);
    }

    pub fn neq(self: *const Color, other: Color) bool {
        return !self.eq(other);
    }

    // ================ MISC UTILS ================

    pub fn opposite(self: *const Color) Color {
        return switch (self.*) {
            .white => .black,
            .black => .white,
            .none => .none,
        };
    }

    pub fn isWhite(self: *const Color) bool {
        return self.* == .white;
    }

    pub fn isBlack(self: *const Color) bool {
        return self.* == .black;
    }

    pub fn isNone(self: *const Color) bool {
        return self.* == .none;
    }
};

// ================ FILE ================

pub const File = enum(u8) {
    fa = 0,
    fb = 1,
    fc = 2,
    fd = 3,
    fe = 4,
    ff = 5,
    fg = 6,
    fh = 7,
    none = 8,

    pub const MASKS: [8]u64 = .{
        0x101010101010101,  0x202020202020202,  0x404040404040404,  0x808080808080808,
        0x1010101010101010, 0x2020202020202020, 0x4040404040404040, 0x8080808080808080,
    };

    pub fn init() File {
        return .none;
    }

    pub fn valid(self: *const File) bool {
        return self.* != .none;
    }

    // ================ INT UTILS ================

    pub fn fromInt(comptime T: type, num: T) File {
        const exhausted = comptime T == u3;
        if (exhausted) {
            return switch (num) {
                0 => .fa,
                1 => .fb,
                2 => .fc,
                3 => .fd,
                4 => .fe,
                5 => .ff,
                6 => .fg,
                7 => .fh,
            };
        }

        switch (@typeInfo(T)) {
            .int, .comptime_int => {
                return switch (num) {
                    0 => .fa,
                    1 => .fb,
                    2 => .fc,
                    3 => .fd,
                    4 => .fe,
                    5 => .ff,
                    6 => .fg,
                    7 => .fh,
                    else => .none,
                };
            },
            else => @compileError("T must be an integer type"),
        }
    }

    pub fn asInt(self: *const File, comptime T: type) T {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @intFromEnum(self.*),
            else => @compileError("T must be an integer type"),
        };
    }

    pub fn index(self: *const File) usize {
        return self.asInt(usize);
    }

    // ================ SLICE UTILS ================

    pub fn fromStr(str: []const u8) File {
        return if (str.len == 0) .none else fromChar(str[0]);
    }

    pub fn asStr(self: *const File) []const u8 {
        return @tagName(self.*);
    }

    // ================ CHAR UTILS ================

    pub fn fromChar(char: u8) File {
        return switch (std.ascii.toLower(char)) {
            'a' => .fa,
            'b' => .fb,
            'c' => .fc,
            'd' => .fd,
            'e' => .fe,
            'f' => .ff,
            'g' => .fg,
            'h' => .fh,
            else => .none,
        };
    }

    pub fn asChar(self: *const File) u8 {
        return switch (self.*) {
            .fa => 'a',
            .fb => 'b',
            .fc => 'c',
            .fd => 'd',
            .fe => 'e',
            .ff => 'f',
            .fg => 'g',
            .fh => 'h',
            .none => '-',
        };
    }

    // ================ COMPARISON ================

    pub fn eq(self: *const File, other: File) bool {
        return self.asInt(i32) == other.asInt(i32);
    }

    pub fn neq(self: *const File, other: File) bool {
        return !self.eq(other);
    }

    pub fn lt(self: *const File, other: File) bool {
        return self.asInt(i32) < other.asInt(i32);
    }

    pub fn gt(self: *const File, other: File) bool {
        return self.asInt(i32) > other.asInt(i32);
    }

    pub fn lteq(self: *const File, other: File) bool {
        return self.asInt(i32) <= other.asInt(i32);
    }

    pub fn gteq(self: *const File, other: File) bool {
        return self.asInt(i32) >= other.asInt(i32);
    }

    // ================ INCREMENTING & DECREMENTING ================

    pub fn next(self: *const File) File {
        return switch (self.*) {
            .fa => .fb,
            .fb => .fc,
            .fc => .fd,
            .fd => .fe,
            .fe => .ff,
            .ff => .fg,
            .fg => .fh,
            .fh => .none,
            .none => .fa,
        };
    }

    pub fn inc(self: *File) File {
        self.* = switch (self.*) {
            .fa => .fb,
            .fb => .fc,
            .fc => .fd,
            .fd => .fe,
            .fe => .ff,
            .ff => .fg,
            .fg => .fh,
            .fh => .none,
            .none => .fa,
        };
        return self.*;
    }

    // ================ MISC UTILS ================

    pub fn mask(self: *const File) u64 {
        return if (self.valid()) MASKS[self.asInt(usize)] else 0;
    }
};

// ================ RANK ================

pub const Rank = enum(u8) {
    r1 = 0,
    r2 = 1,
    r3 = 2,
    r4 = 3,
    r5 = 4,
    r6 = 5,
    r7 = 6,
    r8 = 7,
    none = 8,

    pub const MASKS: [8]u64 = .{
        0x00000000000000FF, 0x000000000000FF00, 0x0000000000FF0000, 0x00000000FF000000,
        0x000000FF00000000, 0x0000FF0000000000, 0x00FF000000000000, 0xFF00000000000000,
    };

    pub fn init() Rank {
        return .none;
    }

    pub fn valid(self: *const Rank) bool {
        return self.* != .none;
    }

    // ================ INT UTILS ================

    pub fn fromInt(comptime T: type, num: T) Rank {
        const exhausted = comptime T == u3;
        if (exhausted) {
            return switch (num) {
                0 => .r1,
                1 => .r2,
                2 => .r3,
                3 => .r4,
                4 => .r5,
                5 => .r6,
                6 => .r7,
                7 => .r8,
            };
        }

        switch (@typeInfo(T)) {
            .int, .comptime_int => {
                return switch (num) {
                    0 => .r1,
                    1 => .r2,
                    2 => .r3,
                    3 => .r4,
                    4 => .r5,
                    5 => .r6,
                    6 => .r7,
                    7 => .r8,
                    else => .none,
                };
            },
            else => @compileError("T must be an integer type"),
        }
    }

    pub fn asInt(self: *const Rank, comptime T: type) T {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @intFromEnum(self.*),
            else => @compileError("T must be an integer type"),
        };
    }

    pub fn index(self: *const Rank) usize {
        return self.asInt(usize);
    }

    // ================ SLICE UTILS ================

    pub fn fromStr(str: []const u8) Rank {
        return if (str.len == 0) .none else fromChar(str[0]);
    }

    pub fn asStr(self: *const Rank) []const u8 {
        return @tagName(self.*);
    }

    // ================ CHAR UTILS ================

    pub fn fromChar(char: u8) Rank {
        return switch (std.ascii.toLower(char)) {
            '0' => .r1,
            '1' => .r2,
            '2' => .r3,
            '3' => .r4,
            '4' => .r5,
            '5' => .r6,
            '6' => .r7,
            '7' => .r8,
            else => .none,
        };
    }

    pub fn asChar(self: *const Rank) u8 {
        return switch (self.*) {
            .r1 => '0',
            .r2 => '1',
            .r3 => '2',
            .r4 => '3',
            .r5 => '4',
            .r6 => '5',
            .r7 => '6',
            .r8 => '7',
            .none => '-',
        };
    }

    // ================ COMPARISON ================

    pub fn eq(self: *const Rank, other: Rank) bool {
        return self.asInt(i32) == other.asInt(i32);
    }

    pub fn neq(self: *const Rank, other: Rank) bool {
        return !self.eq(other);
    }

    pub fn lt(self: *const Rank, other: Rank) bool {
        return self.asInt(i32) < other.asInt(i32);
    }

    pub fn gt(self: *const Rank, other: Rank) bool {
        return self.asInt(i32) > other.asInt(i32);
    }

    pub fn lteq(self: *const Rank, other: Rank) bool {
        return self.asInt(i32) <= other.asInt(i32);
    }

    pub fn gteq(self: *const Rank, other: Rank) bool {
        return self.asInt(i32) >= other.asInt(i32);
    }

    // ================ INCREMENTING & DECREMENTING ================

    pub fn next(self: *const Rank) Rank {
        return switch (self.*) {
            .r1 => .r2,
            .r2 => .r3,
            .r3 => .r4,
            .r4 => .r5,
            .r5 => .r6,
            .r6 => .r7,
            .r7 => .r8,
            .r8 => .none,
            .none => .r1,
        };
    }

    pub fn inc(self: *Rank) Rank {
        self.* = switch (self.*) {
            .r1 => .r2,
            .r2 => .r3,
            .r3 => .r4,
            .r4 => .r5,
            .r5 => .r6,
            .r6 => .r7,
            .r7 => .r8,
            .r8 => .none,
            .none => .r1,
        };
        return self.*;
    }

    // ================ MISC UTILS ================

    pub fn mask(self: *const Rank) u64 {
        return if (self.valid()) MASKS[self.index()] else 0;
    }

    pub fn backRank(self: *const Rank, color: Color) bool {
        return self.asInt(i32) == @intFromEnum(color) * 7;
    }

    pub fn orient(self: *const Rank, color: Color) Rank {
        return @enumFromInt(self.asInt(i32) ^ (color.asInt(i32) * 7));
    }
};

// ================ SQUARE ================

pub const Square = enum(u8) {
    // zig fmt: off
    a1 = 0,  b1 = 1,  c1 = 2,  d1 = 3,  e1 = 4,  f1 = 5,  g1 = 6,  h1 = 7,
    a2 = 8,  b2 = 9,  c2 = 10, d2 = 11, e2 = 12, f2 = 13, g2 = 14, h2 = 15,
    a3 = 16, b3 = 17, c3 = 18, d3 = 19, e3 = 20, f3 = 21, g3 = 22, h3 = 23,
    a4 = 24, b4 = 25, c4 = 26, d4 = 27, e4 = 28, f4 = 29, g4 = 30, h4 = 31,
    a5 = 32, b5 = 33, c5 = 34, d5 = 35, e5 = 36, f5 = 37, g5 = 38, h5 = 39,
    a6 = 40, b6 = 41, c6 = 42, d6 = 43, e6 = 44, f6 = 45, g6 = 46, h6 = 47,
    a7 = 48, b7 = 49, c7 = 50, d7 = 51, e7 = 52, f7 = 53, g7 = 54, h7 = 55,
    a8 = 56, b8 = 57, c8 = 58, d8 = 59, e8 = 60, f8 = 61, g8 = 62, h8 = 63,
    // zig fmt: on

    none = 64,

    pub const Direction = enum(i8) {
        north = 8,
        west = -1,
        south = -8,
        east = 1,

        north_east = 9,
        north_west = 7,
        south_west = -9,
        south_east = -7,

        pub fn make(direction: Direction, color: Color) Direction {
            if (color == .black) {
                return @as(Direction, @enumFromInt(-direction.asInt(i8)));
            }
            return direction;
        }

        pub fn asInt(self: *const Direction, comptime T: type) T {
            return switch (@typeInfo(T)) {
                .int, .comptime_int => @intFromEnum(self.*),
                else => @compileError("T must be an integer type"),
            };
        }

        pub fn addToSquare(self: *const Direction, square: Square) Square {
            return Square.fromInt(i32, self.asInt(i32) + square.asInt(i32));
        }
    };

    pub fn init() Square {
        return .none;
    }

    pub fn valid(self: *const Square) bool {
        return self.* != .none;
    }

    // ================ INT UTILS ================

    pub fn fromInt(comptime T: type, num: T) Square {
        const exhausted = comptime T == u6;
        if (exhausted) {
            return switch (num) {
                // zig fmt: off
                0 =>  .a1,  1 => .b1,  2 => .c1,  3 => .d1,  4 => .e1,  5 => .f1,  6 => .g1,  7 => .h1,
                8 =>  .a2,  9 => .b2, 10 => .c2, 11 => .d2, 12 => .e2, 13 => .f2, 14 => .g2, 15 => .h2,
                16 => .a3, 17 => .b3, 18 => .c3, 19 => .d3, 20 => .e3, 21 => .f3, 22 => .g3, 23 => .h3,
                24 => .a4, 25 => .b4, 26 => .c4, 27 => .d4, 28 => .e4, 29 => .f4, 30 => .g4, 31 => .h4,
                32 => .a5, 33 => .b5, 34 => .c5, 35 => .d5, 36 => .e5, 37 => .f5, 38 => .g5, 39 => .h5,
                40 => .a6, 41 => .b6, 42 => .c6, 43 => .d6, 44 => .e6, 45 => .f6, 46 => .g6, 47 => .h6,
                48 => .a7, 49 => .b7, 50 => .c7, 51 => .d7, 52 => .e7, 53 => .f7, 54 => .g7, 55 => .h7,
                56 => .a8, 57 => .b8, 58 => .c8, 59 => .d8, 60 => .e8, 61 => .f8, 62 => .g8, 63 => .h8,
                // zig fmt: on
            };
        }

        switch (@typeInfo(T)) {
            .int, .comptime_int => {
                return switch (num) {
                    // zig fmt: off
                    0 =>  .a1,  1 => .b1,  2 => .c1,  3 => .d1,  4 => .e1,  5 => .f1,  6 => .g1,  7 => .h1,
                    8 =>  .a2,  9 => .b2, 10 => .c2, 11 => .d2, 12 => .e2, 13 => .f2, 14 => .g2, 15 => .h2,
                    16 => .a3, 17 => .b3, 18 => .c3, 19 => .d3, 20 => .e3, 21 => .f3, 22 => .g3, 23 => .h3,
                    24 => .a4, 25 => .b4, 26 => .c4, 27 => .d4, 28 => .e4, 29 => .f4, 30 => .g4, 31 => .h4,
                    32 => .a5, 33 => .b5, 34 => .c5, 35 => .d5, 36 => .e5, 37 => .f5, 38 => .g5, 39 => .h5,
                    40 => .a6, 41 => .b6, 42 => .c6, 43 => .d6, 44 => .e6, 45 => .f6, 46 => .g6, 47 => .h6,
                    48 => .a7, 49 => .b7, 50 => .c7, 51 => .d7, 52 => .e7, 53 => .f7, 54 => .g7, 55 => .h7,
                    56 => .a8, 57 => .b8, 58 => .c8, 59 => .d8, 60 => .e8, 61 => .f8, 62 => .g8, 63 => .h8,
                    // zig fmt: on
                    else => .none,
                };
            },
            else => @compileError("T must be an integer type"),
        }
    }

    pub fn asInt(self: *const Square, comptime T: type) T {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @intFromEnum(self.*),
            else => @compileError("T must be an integer type"),
        };
    }

    pub fn index(self: *const Square) usize {
        return self.asInt(usize);
    }

    // ================ SLICE UTILS ================

    pub fn fromStr(str: []const u8) Square {
        if (str.len != 2) return .none;

        const file_char = std.ascii.toLower(str[0]);
        const rank_char = str[1];

        if (file_char < 'a' or file_char > 'h') return .none;
        if (rank_char < '1' or rank_char > '8') return .none;

        const file_val = file_char - 'a';
        const rank_val = rank_char - '1';

        return Square.fromInt(u8, rank_val * 8 + file_val);
    }

    pub fn asStr(self: *const Square) []const u8 {
        return @tagName(self.*);
    }

    // ================ FILE & RANK UTILS ================

    pub fn make(r: Rank, f: File) Square {
        if (!r.valid() or !f.valid()) {
            return .none;
        }

        return Square.fromInt(usize, f.asInt(usize) + r.asInt(usize) * 8);
    }

    pub fn file(self: *const Square) File {
        return File.fromInt(usize, self.index() & 7);
    }

    pub fn rank(self: *const Square) Rank {
        return Rank.fromInt(usize, self.index() >> 3);
    }

    // ================ COMPARISON ================

    pub fn eq(self: *const Square, other: Square) bool {
        return self.asInt(i32) == other.asInt(i32);
    }

    pub fn neq(self: *const Square, other: Square) bool {
        return !self.eq(other);
    }

    pub fn lt(self: *const Square, other: Square) bool {
        return self.asInt(i32) < other.asInt(i32);
    }

    pub fn gt(self: *const Square, other: Square) bool {
        return self.asInt(i32) > other.asInt(i32);
    }

    pub fn lteq(self: *const Square, other: Square) bool {
        return self.asInt(i32) <= other.asInt(i32);
    }

    pub fn gteq(self: *const Square, other: Square) bool {
        return self.asInt(i32) >= other.asInt(i32);
    }

    // ================ INCREMENTING & DECREMENTING ================

    pub fn next(self: *const Square) Square {
        if (self.* == .none) return .a1;
        return @enumFromInt((@intFromEnum(self.*) + 1) % 64);
    }

    pub fn prev(self: *const Square) Square {
        if (self.* == .none) return .h8;
        return @enumFromInt(((@intFromEnum(self.*) + 64 - 1) % 64));
    }

    pub fn inc(self: *Square) Square {
        self.* = if (self.* == .none) .a1 else @enumFromInt((@intFromEnum(self.*) + 1) % 64);
        return self.*;
    }

    pub fn dec(self: *Square) Square {
        self.* = if (self.* == .none) .h8 else @enumFromInt(((@intFromEnum(self.*) + 64 - 1) % 64));
        return self.*;
    }

    // ================ ARITHMETIC ================

    pub fn add(self: *const Square, other: Square) Square {
        return fromInt(i32, self.asInt(i32) + other.asInt(i32));
    }

    pub fn sub(self: *const Square, other: Square) Square {
        return fromInt(i32, self.asInt(i32) - other.asInt(i32));
    }

    pub fn xor(self: *const Square, other: Square) Square {
        return fromInt(usize, self.index() ^ other.index());
    }

    pub fn addToDirection(self: *const Square, direction: Direction) Square {
        return Square.fromInt(i32, self.asInt(i32) + direction.asInt(i32));
    }

    // ================ MISC UTILS ================

    pub fn light(self: *const Square) bool {
        return ((self.file().index() + self.rank().index()) & 1) == 1;
    }

    pub fn dark(self: *const Square) bool {
        return !self.light();
    }

    pub fn sameColor(self: *const Square, other: Square) bool {
        return ((9 * self.xor(other).index()) & 8) == 0;
    }

    pub fn flip(self: *const Square) Square {
        return fromInt(usize, self.index() ^ 56);
    }

    pub fn flipRelative(self: *const Square, color: Color) Square {
        return fromInt(usize, self.index() ^ (color.index() * 56));
    }

    pub fn backRank(self: *const Square, color: Color) bool {
        return self.rank().backRank(color);
    }

    pub fn diagonal(self: *const Square) Square {
        return fromInt(usize, 7 + self.rank().index() - self.file().index());
    }

    pub fn antidiagonal(self: *const Square) Square {
        return fromInt(usize, self.rank().index() + self.file().index());
    }

    pub fn ep(self: *const Square) Square {
        return switch (self.rank()) {
            .r3, .r4, .r5, .r6 => fromInt(usize, self.index() ^ 8),
            else => .none,
        };
    }

    pub fn castlingKingTo(side: CastlingRights.Side, color: Color) Square {
        return if (side == .king) Square.g1.flipRelative(color) else Square.c1.flipRelative(color);
    }

    pub fn castlingRookTo(side: CastlingRights.Side, color: Color) Square {
        return if (side == .king) Square.f1.flipRelative(color) else Square.d1.flipRelative(color);
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "Color" {
    const white = Color.white;
    const black = Color.black;
    const none = Color.none;

    try expectEqual(none, Color.init());

    // ================ INT UTILS ================

    try expectEqual(white, Color.fromInt(i32, 0));
    try expectEqual(black, Color.fromInt(i32, 1));
    try expectEqual(none, Color.fromInt(i32, -1));
    try expectEqual(none, Color.fromInt(i32, 4));

    try expectEqual(0, white.asInt(i32));
    try expectEqual(1, black.asInt(i32));
    try expectEqual(2, none.asInt(i32));

    // ================ SLICE UTILS ================

    try expectEqual(white, Color.fromStr("White"));
    try expectEqual(white, Color.fromStr("w"));
    try expectEqual(black, Color.fromStr("Black"));
    try expectEqual(black, Color.fromStr("b"));
    try expectEqual(none, Color.fromStr("None"));

    try testing.expectEqualSlices(u8, "white", white.asStr());
    try testing.expectEqualSlices(u8, "black", black.asStr());
    try testing.expectEqualSlices(u8, "none", none.asStr());

    // ================ CHAR UTILS ================

    try expectEqual(white, Color.fromChar('w'));
    try expectEqual(black, Color.fromChar('b'));
    try expectEqual(none, Color.fromChar('n'));

    try expectEqual('w', white.asChar());
    try expectEqual('b', black.asChar());
    try expectEqual('-', none.asChar());

    // ================ COMPARISON ================

    try expect(white.eq(.white));
    try expect(black.eq(.black));
    try expect(white.neq(black));

    try expectEqual(black, white.opposite());
    try expectEqual(none, none.opposite());
}

test "File" {
    const fa = File.fa;
    const fb = File.fb;
    const fh = File.fh;
    const none = File.none;

    try expectEqual(none, File.init());

    // ================ INT UTILS ================

    try expectEqual(fa, File.fromInt(i32, 0));
    try expectEqual(fb, File.fromInt(i32, 1));
    try expectEqual(fh, File.fromInt(i32, 7));
    try expectEqual(none, File.fromInt(i32, 8));
    try expectEqual(none, File.fromInt(i32, -1));
    try expectEqual(none, File.fromInt(i32, 99));

    try expectEqual(0, fa.asInt(i32));
    try expectEqual(1, fb.asInt(i32));
    try expectEqual(7, fh.asInt(i32));
    try expectEqual(8, none.asInt(i32));

    // ================ SLICE UTILS ================

    try expectEqual(fa, File.fromStr("a"));
    try expectEqual(fa, File.fromStr("A"));
    try expectEqual(fh, File.fromStr("h"));
    try expectEqual(fh, File.fromStr("H"));
    try expectEqual(none, File.fromStr(""));
    try expectEqual(none, File.fromStr("z"));

    try testing.expectEqualSlices(u8, "fa", fa.asStr());
    try testing.expectEqualSlices(u8, "fb", fb.asStr());
    try testing.expectEqualSlices(u8, "fh", fh.asStr());
    try testing.expectEqualSlices(u8, "none", none.asStr());

    // ================ CHAR UTILS ================

    try expectEqual(fa, File.fromChar('a'));
    try expectEqual(fa, File.fromChar('A'));
    try expectEqual(fh, File.fromChar('h'));
    try expectEqual(fh, File.fromChar('H'));
    try expectEqual(none, File.fromChar('z'));

    try expectEqual('a', fa.asChar());
    try expectEqual('b', fb.asChar());
    try expectEqual('h', fh.asChar());
    try expectEqual('-', none.asChar());

    // ================ COMPARISON ================

    try expect(fa.eq(.fa));
    try expect(fa.neq(fb));
    try expect(fa.lt(fb));
    try expect(fb.gt(fa));
    try expect(fa.lteq(fb));
    try expect(fb.gteq(fa));

    try expectEqual(fb, fa.next());
    try expectEqual(.none, fh.next());
    try expectEqual(.fa, none.next());

    var cur = fa;
    try expectEqual(fb, cur.inc());
    try expectEqual(fb, cur);

    // ================ MASK ================

    try expectEqual(@as(u64, 0x101010101010101), fa.mask());
    try expectEqual(@as(u64, 0x202020202020202), fb.mask());
    try expectEqual(@as(u64, 0x8080808080808080), fh.mask());
    try expectEqual(@as(u64, 0), none.mask());
}

test "Rank" {
    const r1 = Rank.r1;
    const r2 = Rank.r2;
    const r4 = Rank.r4;
    const r8 = Rank.r8;
    const none = Rank.none;

    const white = Color.white;
    const black = Color.black;

    try expectEqual(none, Rank.init());

    // ================ INT UTILS ================

    try expectEqual(r1, Rank.fromInt(i32, 0));
    try expectEqual(r2, Rank.fromInt(i32, 1));
    try expectEqual(r8, Rank.fromInt(i32, 7));
    try expectEqual(none, Rank.fromInt(i32, 8));
    try expectEqual(none, Rank.fromInt(i32, -1));
    try expectEqual(none, Rank.fromInt(i32, 42));

    try expectEqual(0, r1.asInt(i32));
    try expectEqual(1, r2.asInt(i32));
    try expectEqual(7, r8.asInt(i32));
    try expectEqual(8, none.asInt(i32));

    // ================ SLICE UTILS ================

    try expectEqual(r1, Rank.fromStr("0"));
    try expectEqual(r2, Rank.fromStr("1"));
    try expectEqual(r8, Rank.fromStr("7"));
    try expectEqual(none, Rank.fromStr(""));
    try expectEqual(none, Rank.fromStr("z"));

    try testing.expectEqualSlices(u8, "r1", r1.asStr());
    try testing.expectEqualSlices(u8, "r2", r2.asStr());
    try testing.expectEqualSlices(u8, "r8", r8.asStr());
    try testing.expectEqualSlices(u8, "none", none.asStr());

    // ================ CHAR UTILS ================

    try expectEqual(r1, Rank.fromChar('0'));
    try expectEqual(r2, Rank.fromChar('1'));
    try expectEqual(r8, Rank.fromChar('7'));
    try expectEqual(none, Rank.fromChar('z'));

    try expectEqual('0', r1.asChar());
    try expectEqual('1', r2.asChar());
    try expectEqual('7', r8.asChar());
    try expectEqual('-', none.asChar());

    // ================ COMPARISON ================

    try expect(r1.eq(.r1));
    try expect(r1.neq(r2));
    try expect(r1.lt(r2));
    try expect(r2.gt(r1));
    try expect(r1.lteq(r2));
    try expect(r2.gteq(r1));

    try expectEqual(r2, r1.next());
    try expectEqual(.none, r8.next());
    try expectEqual(.r1, none.next());

    var cur = r1;
    try expectEqual(r2, cur.inc());
    try expectEqual(r2, cur);

    // ================ MASK ================

    try expectEqual(@as(u64, 0x00000000000000FF), r1.mask());
    try expectEqual(@as(u64, 0x000000000000FF00), r2.mask());
    try expectEqual(@as(u64, 0x00000000FF000000), r4.mask());
    try expectEqual(@as(u64, 0xFF00000000000000), r8.mask());
    try expectEqual(@as(u64, 0), none.mask());

    // ================ BACK RANK ================

    try expect(r1.backRank(white));
    try expect(!r8.backRank(white));
    try expect(r8.backRank(black));
    try expect(!r1.backRank(black));

    // ================ ORIENT ================

    try expectEqual(Rank.r1, r1.orient(white));
    try expectEqual(Rank.r8, r8.orient(white));
    try expectEqual(Rank.r8, r1.orient(black));
    try expectEqual(Rank.r1, r8.orient(black));
    try expectEqual(Rank.r4, r4.orient(white));
    try expectEqual(Rank.r5, r4.orient(black));
}

test "Square" {
    const a1 = Square.a1;
    const h8 = Square.h8;
    const e4 = Square.e4;
    const a3 = Square.a3;
    const a4 = Square.a4;
    const none = Square.none;

    const white = Color.white;
    const black = Color.black;

    try expectEqual(none, Square.init());

    // ================ INT UTILS ================

    try expectEqual(a1, Square.fromInt(i32, 0));
    try expectEqual(h8, Square.fromInt(i32, 63));
    try expectEqual(none, Square.fromInt(i32, 64));
    try expectEqual(0, a1.asInt(i32));
    try expectEqual(63, h8.asInt(i32));
    try expectEqual(64, none.asInt(i32));
    try expectEqual(a1, Square.fromInt(usize, a1.index()));
    try expectEqual(none, Square.fromInt(usize, 100));

    // ================ SLICE UTILS ================

    try expectEqual(a1, Square.fromStr("a1"));
    try expectEqual(e4, Square.fromStr("e4"));
    try expectEqual(none, Square.fromStr("z9"));
    try testing.expectEqualSlices(u8, "a1", a1.asStr());
    try testing.expectEqualSlices(u8, "none", none.asStr());

    // ================ FILE & RANK UTILS ================

    try expectEqual(File.fa, a1.file());
    try expectEqual(File.fh, h8.file());
    try expectEqual(Rank.r1, a1.rank());
    try expectEqual(Rank.r8, h8.rank());

    try expectEqual(e4, Square.make(Rank.r4, File.fe));
    try expectEqual(none, Square.make(Rank.none, File.fa));
    try expectEqual(none, Square.make(Rank.r1, File.none));

    // ================ COMPARISON ================

    try expect(a1.eq(.a1));
    try expect(a1.neq(h8));
    try expect(a1.lt(h8));
    try expect(h8.gt(a1));
    try expect(a1.lteq(a1));
    try expect(h8.gteq(a1));

    // ================ INCREMENTING & DECREMENTING ================

    try expectEqual(Square.b1, a1.next());
    try expectEqual(Square.a1, none.next());

    var cur = a1;
    try expectEqual(Square.b1, cur.inc());
    try expectEqual(Square.b1, cur);

    try expectEqual(Square.g8, h8.prev());
    try expectEqual(Square.h8, none.prev());

    // ================ ARITHMETIC ================

    try expectEqual(Square.b1, a1.add(Square.b1));
    try expectEqual(a1, Square.b1.sub(Square.b1));
    try expectEqual(Square.b2, a1.xor(Square.b2));

    // ================ OTHER UTILITIES ================

    try expectEqual(a4, a3.ep());
    try expectEqual(a3, a4.ep());
    try expectEqual(none, a1.ep());

    try expectEqual(Square.a8, a1.flip());
    try expectEqual(Square.h1, h8.flip());

    try expectEqual(Square.a1, a1.flipRelative(white));
    try expectEqual(Square.h1, h8.flipRelative(black));

    try expect(a4.light());
    try expect(!a4.dark());
    try expect(h8.dark());

    try expect(Square.a1.sameColor(Square.c1));
    try expect(!Square.a1.sameColor(Square.b1));

    try expectEqual(Square.g1, Square.castlingKingTo(.king, white));
    try expectEqual(Square.c1, Square.castlingKingTo(.queen, white));
    try expectEqual(Square.f1, Square.castlingRookTo(.king, white));
    try expectEqual(Square.d1, Square.castlingRookTo(.queen, white));
    try expectEqual(Square.g8, Square.castlingKingTo(.king, black));
    try expectEqual(Square.c8, Square.castlingKingTo(.queen, black));
    try expectEqual(Square.f8, Square.castlingRookTo(.king, black));
    try expectEqual(Square.d8, Square.castlingRookTo(.queen, black));
}

test "Direction" {
    const a1 = Square.a1;
    const h8 = Square.h8;
    const none = Square.none;

    const white = Color.white;
    const black = Color.black;

    // ================ DIRECTION ================

    const north = Square.Direction.north;
    const south_east = Square.Direction.south_east;

    try expectEqual(8, north.asInt(i32));
    try expectEqual(-7, south_east.asInt(i32));

    try expectEqual(north, Square.Direction.north.make(white));
    try expectEqual(Square.Direction.south, Square.Direction.north.make(black));
    try expectEqual(south_east, south_east.make(white));
    try expectEqual(Square.Direction.north_west, south_east.make(black));

    try expectEqual(Square.fromInt(usize, a1.index() + 8), north.addToSquare(a1));
    try expectEqual(Square.fromInt(usize, h8.index() - 7), south_east.addToSquare(h8));

    // ================ SQUARE + DIRECTION ================

    try expectEqual(Square.fromInt(i32, a1.asInt(i32) + north.asInt(i32)), a1.addToDirection(north));
    try expectEqual(Square.fromInt(i32, h8.asInt(i32) + south_east.asInt(i32)), h8.addToDirection(south_east));

    // ================ EDGE CASES ================

    try expectEqual(Square.fromInt(i32, none.asInt(i32) + north.asInt(i32)), none.addToDirection(north));
}
