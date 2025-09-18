const std = @import("std");

// ================ ERRORS ================

const ChessError = error{};

// ================ COLOR ================

pub const Color = enum(i8) {
    White = 0,
    Black = 1,
    None = -1,

    pub fn init() Color {
        return .None;
    }

    // ================ INT UTILS ================

    pub fn fromInt(num: i32) Color {
        return switch (num) {
            0 => .White,
            1 => .Black,
            else => .None,
        };
    }

    pub fn asInt(self: *const Color) i32 {
        return switch (self.*) {
            .White => 0,
            .Black => 1,
            .None => -1,
        };
    }

    // ================ SLICE UTILS ================

    pub fn fromStr(str: []const u8) Color {
        return if (str.len == 0) .None else fromChar(str[0]);
    }

    pub fn asStr(self: *const Color) []const u8 {
        return @tagName(self.*);
    }

    // ================ CHAR UTILS ================

    pub fn fromChar(char: u8) Color {
        return switch (std.ascii.toLower(char)) {
            'w' => .White,
            'b' => .Black,
            else => .None,
        };
    }

    pub fn asChar(self: *const Color) u8 {
        return switch (self.*) {
            .White => 'w',
            .Black => 'b',
            .None => '-',
        };
    }

    // ================ MISC UTILS ================

    pub fn eq(self: *const Color, other: Color) bool {
        return self.asInt() == other.asInt();
    }

    pub fn neq(self: *const Color, other: Color) bool {
        return !self.eq(other);
    }

    pub fn not(self: *const Color) Color {
        return switch (self.*) {
            .White => .Black,
            .Black => .White,
            .None => .None,
        };
    }
};

// ================ FILE ================

pub const File = enum(u8) {
    FA = 0,
    FB = 1,
    FC = 2,
    FD = 3,
    FE = 4,
    FF = 5,
    FG = 6,
    FH = 7,
    None = 8,

    pub fn init() File {
        return .None;
    }

    // ================ INT UTILS ================

    pub fn fromInt(num: i32) File {
        return switch (num) {
            0 => .FA,
            1 => .FB,
            2 => .FC,
            3 => .FD,
            4 => .FE,
            5 => .FF,
            6 => .FG,
            7 => .FH,
            else => .None,
        };
    }

    pub fn asInt(self: *const File) i32 {
        return @intFromEnum(self.*);
    }

    // ================ SLICE UTILS ================

    pub fn fromStr(str: []const u8) File {
        return if (str.len == 0) .None else fromChar(str[0]);
    }

    pub fn asStr(self: *const File) []const u8 {
        return @tagName(self.*);
    }

    // ================ CHAR UTILS ================

    pub fn fromChar(char: u8) File {
        return switch (std.ascii.toLower(char)) {
            'a' => .FA,
            'b' => .FB,
            'c' => .FC,
            'd' => .FD,
            'e' => .FE,
            'f' => .FF,
            'g' => .FG,
            'h' => .FH,
            else => .None,
        };
    }

    pub fn asChar(self: *const File) u8 {
        return switch (self.*) {
            .FA => 'a',
            .FB => 'b',
            .FC => 'c',
            .FD => 'd',
            .FE => 'e',
            .FF => 'f',
            .FG => 'g',
            .FH => 'h',
            .None => '-',
        };
    }

    // ================ MISC UTILS ================

    pub fn eq(self: *const File, other: File) bool {
        return self.asInt() == other.asInt();
    }

    pub fn neq(self: *const File, other: File) bool {
        return !self.eq(other);
    }

    pub fn lt(self: *const File, other: File) bool {
        return self.asInt() < other.asInt();
    }

    pub fn gt(self: *const File, other: File) bool {
        return self.asInt() > other.asInt();
    }

    pub fn lteq(self: *const File, other: File) bool {
        return self.asInt() <= other.asInt();
    }

    pub fn gteq(self: *const File, other: File) bool {
        return self.asInt() >= other.asInt();
    }

    pub fn next(self: *const File) File {
        return switch (self.*) {
            .FA => .FB,
            .FB => .FC,
            .FC => .FD,
            .FD => .FE,
            .FE => .FF,
            .FF => .FG,
            .FG => .FH,
            .FH => .None,
            .None => .FA,
        };
    }

    pub fn inc(self: *File) File {
        self.* = switch (self.*) {
            .FA => .FB,
            .FB => .FC,
            .FC => .FD,
            .FD => .FE,
            .FE => .FF,
            .FF => .FG,
            .FG => .FH,
            .FH => .None,
            .None => .FA,
        };
        return self.*;
    }
};

// ================ RANK ================

pub const Rank = enum(u8) {
    R1 = 0,
    R2 = 1,
    R3 = 2,
    R4 = 3,
    R5 = 4,
    R6 = 5,
    R7 = 6,
    R8 = 7,
    None = 8,

    pub fn init() Rank {
        return .None;
    }
};

// ================ SQUARE ================

pub const Square = enum(u8) {
    // zig fmt: off
    A1 = 0,  B1 = 1,  C1 = 2,  D1 = 3,  E1 = 4,  F1 = 5,  G1 = 6,  H1 = 7,
    A2 = 8,  B2 = 9,  C2 = 10, D2 = 11, E2 = 12, F2 = 13, G2 = 14, H2 = 15,
    A3 = 16, B3 = 17, C3 = 18, D3 = 19, E3 = 20, F3 = 21, G3 = 22, H3 = 23,
    A4 = 24, B4 = 25, C4 = 26, D4 = 27, E4 = 28, F4 = 29, G4 = 30, H4 = 31,
    A5 = 32, B5 = 33, C5 = 34, D5 = 35, E5 = 36, F5 = 37, G5 = 38, H5 = 39,
    A6 = 40, B6 = 41, C6 = 42, D6 = 43, E6 = 44, F6 = 45, G6 = 46, H6 = 47,
    A7 = 48, B7 = 49, C7 = 50, D7 = 51, E7 = 52, F7 = 53, G7 = 54, H7 = 55,
    A8 = 56, B8 = 57, C8 = 58, D8 = 59, E8 = 60, F8 = 61, G8 = 62, H8 = 63,
    // zig fmt: on

    None = 64,

    pub fn init() Square {
        return .None;
    }
};

// ================ TESTING ================
const testing = std.testing;

test "Color" {
    const white = Color.White;
    const black = Color.Black;
    const none = Color.None;

    try testing.expectEqual(none, Color.init());

    // ================ INT UTILS ================

    try testing.expectEqual(white, Color.fromInt(0));
    try testing.expectEqual(black, Color.fromInt(1));
    try testing.expectEqual(none, Color.fromInt(-1));
    try testing.expectEqual(none, Color.fromInt(4));

    try testing.expectEqual(0, white.asInt());
    try testing.expectEqual(1, black.asInt());
    try testing.expectEqual(-1, none.asInt());

    // ================ SLICE UTILS ================

    try testing.expectEqual(white, Color.fromStr("White"));
    try testing.expectEqual(white, Color.fromStr("w"));
    try testing.expectEqual(black, Color.fromStr("Black"));
    try testing.expectEqual(black, Color.fromStr("b"));
    try testing.expectEqual(none, Color.fromStr("None"));

    try testing.expectEqualSlices(u8, "White", white.asStr());
    try testing.expectEqualSlices(u8, "Black", black.asStr());
    try testing.expectEqualSlices(u8, "None", none.asStr());

    // ================ CHAR UTILS ================

    try testing.expectEqual(white, Color.fromChar('w'));
    try testing.expectEqual(black, Color.fromChar('b'));
    try testing.expectEqual(none, Color.fromChar('n'));

    try testing.expectEqual('w', white.asChar());
    try testing.expectEqual('b', black.asChar());
    try testing.expectEqual('-', none.asChar());

    // ================ MISC UTILS ================

    try testing.expect(white.eq(.White));
    try testing.expect(black.eq(.Black));
    try testing.expect(white.neq(black));

    try testing.expectEqual(black, white.not());
    try testing.expectEqual(none, none.not());
}

test "File" {
    const fa = File.FA;
    const fb = File.FB;
    const fh = File.FH;
    const none = File.None;

    try testing.expectEqual(none, File.init());

    // ================ INT UTILS ================

    try testing.expectEqual(fa, File.fromInt(0));
    try testing.expectEqual(fb, File.fromInt(1));
    try testing.expectEqual(fh, File.fromInt(7));
    try testing.expectEqual(none, File.fromInt(8));
    try testing.expectEqual(none, File.fromInt(-1));
    try testing.expectEqual(none, File.fromInt(99));

    try testing.expectEqual(0, fa.asInt());
    try testing.expectEqual(1, fb.asInt());
    try testing.expectEqual(7, fh.asInt());
    try testing.expectEqual(8, none.asInt());

    // ================ SLICE UTILS ================

    try testing.expectEqual(fa, File.fromStr("a"));
    try testing.expectEqual(fa, File.fromStr("A"));
    try testing.expectEqual(fh, File.fromStr("h"));
    try testing.expectEqual(fh, File.fromStr("H"));
    try testing.expectEqual(none, File.fromStr(""));
    try testing.expectEqual(none, File.fromStr("z"));

    try testing.expectEqualSlices(u8, "FA", fa.asStr());
    try testing.expectEqualSlices(u8, "FB", fb.asStr());
    try testing.expectEqualSlices(u8, "FH", fh.asStr());
    try testing.expectEqualSlices(u8, "None", none.asStr());

    // ================ CHAR UTILS ================

    try testing.expectEqual(fa, File.fromChar('a'));
    try testing.expectEqual(fa, File.fromChar('A'));
    try testing.expectEqual(fh, File.fromChar('h'));
    try testing.expectEqual(fh, File.fromChar('H'));
    try testing.expectEqual(none, File.fromChar('z'));

    try testing.expectEqual('a', fa.asChar());
    try testing.expectEqual('b', fb.asChar());
    try testing.expectEqual('h', fh.asChar());
    try testing.expectEqual('-', none.asChar());

    // ================ MISC UTILS ================

    try testing.expect(fa.eq(.FA));
    try testing.expect(fa.neq(fb));
    try testing.expect(fa.lt(fb));
    try testing.expect(fb.gt(fa));
    try testing.expect(fa.lteq(fb));
    try testing.expect(fb.gteq(fa));

    try testing.expectEqual(fb, fa.next());
    try testing.expectEqual(.None, fh.next());
    try testing.expectEqual(.FA, none.next());

    var cur = fa;
    try testing.expectEqual(fb, cur.inc());
    try testing.expectEqual(fb, cur);
}

test "Rank" {
    const none = Rank.None;

    try testing.expectEqual(none, Rank.init());
}

test "Square" {
    const none = Square.None;

    try testing.expectEqual(none, Square.init());
}
