const std = @import("std");

const Color = @import("../core/types.zig").Color;

pub const PieceType = enum(u3) {
    pawn = 0,
    knight = 1,
    bishop = 2,
    rook = 3,
    queen = 4,
    king = 5,

    none = 6,

    pub fn init() PieceType {
        return .none;
    }

    pub fn valid(self: *const PieceType) bool {
        return self.* != .none;
    }

    // ================ INT UTILS ================

    pub fn fromInt(comptime T: type, num: T) PieceType {
        switch (@typeInfo(T)) {
            .int, .comptime_int => {
                return switch (num) {
                    0 => .pawn,
                    1 => .knight,
                    2 => .bishop,
                    3 => .rook,
                    4 => .queen,
                    5 => .king,
                    else => .none,
                };
            },
            else => @compileError("T must be an integer type"),
        }
    }

    pub fn asInt(self: *const PieceType, comptime T: type) T {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @intFromEnum(self.*),
            else => @compileError("T must be an integer type"),
        };
    }

    pub fn index(self: *const PieceType) usize {
        return self.asInt(usize);
    }

    // ================ SLICE UTILS ================

    pub fn fromStr(str: []const u8) PieceType {
        return if (str.len == 0) .none else fromChar(str[0]);
    }

    pub fn asStr(self: *const PieceType) []const u8 {
        return @tagName(self.*);
    }

    // ================ CHAR UTILS ================

    pub fn fromChar(char: u8) PieceType {
        return switch (std.ascii.toLower(char)) {
            'p' => .pawn,
            'n' => .knight,
            'b' => .bishop,
            'r' => .rook,
            'q' => .queen,
            'k' => .king,
            else => .none,
        };
    }

    pub fn asChar(self: *const PieceType) u8 {
        return switch (self.*) {
            .pawn => 'p',
            .knight => 'n',
            .bishop => 'b',
            .rook => 'r',
            .queen => 'q',
            .king => 'k',
            .none => '-',
        };
    }

    // ================ COMPARISON ================

    pub fn order(lhs: PieceType, rhs: PieceType) std.math.Order {
        const lhs_val = lhs.asInt(i32);
        const rhs_val = rhs.asInt(i32);

        return std.math.order(lhs_val, rhs_val);
    }
};

pub const Piece = enum(u8) {
    white_pawn = 0,
    white_knight = 1,
    white_bishop = 2,
    white_rook = 3,
    white_queen = 4,
    white_king = 5,

    black_pawn = 6,
    black_knight = 7,
    black_bishop = 8,
    black_rook = 9,
    black_queen = 10,
    black_king = 11,

    none = 12,

    pub fn init() Piece {
        return .none;
    }

    pub fn make(piece_color: Color, piece_type: PieceType) Piece {
        return Piece.fromInt(
            usize,
            piece_type.asInt(usize) + piece_color.asInt(usize) * 6,
        );
    }

    pub fn valid(self: *const Piece) bool {
        return self.* != .none;
    }

    // ================ INT UTILS ================

    pub fn fromInt(comptime T: type, num: T) Piece {
        switch (@typeInfo(T)) {
            .int, .comptime_int => {
                return switch (num) {
                    0 => .white_pawn,
                    1 => .white_knight,
                    2 => .white_bishop,
                    3 => .white_rook,
                    4 => .white_queen,
                    5 => .white_king,
                    6 => .black_pawn,
                    7 => .black_knight,
                    8 => .black_bishop,
                    9 => .black_rook,
                    10 => .black_queen,
                    11 => .black_king,
                    else => .none,
                };
            },
            else => @compileError("T must be an integer type"),
        }
    }

    pub fn asInt(self: *const Piece, comptime T: type) T {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @intFromEnum(self.*),
            else => @compileError("T must be an integer type"),
        };
    }

    pub fn index(self: *const Piece) usize {
        return self.asInt(usize);
    }

    // ================ CHAR UTILS ================

    pub fn fromChar(char: u8) Piece {
        return switch (char) {
            'P' => .white_pawn,
            'N' => .white_knight,
            'B' => .white_bishop,
            'R' => .white_rook,
            'Q' => .white_queen,
            'K' => .white_king,
            'p' => .black_pawn,
            'n' => .black_knight,
            'b' => .black_bishop,
            'r' => .black_rook,
            'q' => .black_queen,
            'k' => .black_king,
            else => .none,
        };
    }

    pub fn asChar(self: *const Piece) u8 {
        return switch (self.*) {
            .white_pawn => 'P',
            .white_knight => 'N',
            .white_bishop => 'B',
            .white_rook => 'R',
            .white_queen => 'Q',
            .white_king => 'K',
            .black_pawn => 'p',
            .black_knight => 'n',
            .black_bishop => 'b',
            .black_rook => 'r',
            .black_queen => 'q',
            .black_king => 'k',
            .none => '-',
        };
    }

    // ================ COMPARISON ================

    pub fn order(lhs: Piece, rhs: Piece) std.math.Order {
        const lhs_val = lhs.asInt(i32);
        const rhs_val = rhs.asInt(i32);

        return std.math.order(lhs_val, rhs_val);
    }

    // ================ MISC UTILS ================

    pub fn asType(self: *const Piece) PieceType {
        if (self.* == .none) return .none;
        const ord = self.order(.white_king);
        return PieceType.fromInt(i32, if (ord == .lt or ord == .eq) self.asInt(i32) else self.asInt(i32) - 6);
    }

    pub fn color(self: *const Piece) Color {
        if (self.* == .none) return .none;
        const ord = self.order(.white_king);
        return if (ord == .lt or ord == .eq) .white else .black;
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "PieceType" {
    // ================ INIT / VALID =================
    var pt = PieceType.init();
    try expect(pt == .none);
    try expect(!pt.valid());
    pt = .pawn;
    try expect(pt.valid());

    // ================ FROM / AS INT =================
    try expectEqual(PieceType.pawn, PieceType.fromInt(u8, 0));
    try expectEqual(PieceType.knight, PieceType.fromInt(u8, 1));
    try expectEqual(PieceType.none, PieceType.fromInt(u8, 10));

    try expectEqual(0, pt.asInt(u8));
    try expectEqual(0, pt.asInt(i32));

    // ================ FROM / AS CHAR =================
    try expectEqual(PieceType.pawn, PieceType.fromChar('p'));
    try expectEqual(PieceType.knight, PieceType.fromChar('N'));
    try expectEqual(PieceType.none, PieceType.fromChar('x'));

    try expectEqual('p', PieceType.pawn.asChar());
    try expectEqual('n', PieceType.knight.asChar());
    try expectEqual('-', PieceType.none.asChar());

    // ================ COMPARISONS =================
    try expect(PieceType.pawn.order(.pawn) == .eq);
    try expect(PieceType.pawn.order(.knight) != .eq);
    try expect(PieceType.pawn.order(.knight) == .lt);
    try expect(PieceType.rook.order(.pawn) == .gt);
}

test "Piece" {
    // ================ INIT / VALID =================
    var pc = Piece.init();
    try expect(pc == .none);
    try expect(!pc.valid());
    pc = .white_pawn;
    try expect(pc.valid());

    // ================ FROM / AS INT =================
    try expectEqual(Piece.white_pawn, Piece.fromInt(u8, 0));
    try expectEqual(Piece.black_king, Piece.fromInt(u8, 11));
    try expectEqual(Piece.none, Piece.fromInt(u8, 20));

    try expectEqual(0, Piece.white_pawn.asInt(u8));
    try expectEqual(11, Piece.black_king.asInt(u8));

    // ================ MAKE =================
    try expectEqual(Piece.black_knight, Piece.make(.black, .knight));
    try expectEqual(Piece.white_pawn, Piece.make(.white, .pawn));

    // ================ FROM / AS CHAR =================
    try expectEqual(Piece.white_pawn, Piece.fromChar('P'));
    try expectEqual(Piece.black_knight, Piece.fromChar('n'));
    try expectEqual(Piece.none, Piece.fromChar('x'));

    try expectEqual('P', Piece.white_pawn.asChar());
    try expectEqual('n', Piece.black_knight.asChar());
    try expectEqual('-', Piece.none.asChar());

    // ================ COMPARISONS =================
    try expect(Piece.white_pawn.order(.white_pawn) == .eq);
    try expect(Piece.white_pawn.order(.white_knight) != .eq);
    try expect(Piece.white_pawn.order(.white_knight) == .lt);
    try expect(Piece.black_pawn.order(.white_king) == .gt);

    // ================ UTILITIES =================
    try expectEqual(PieceType.pawn, Piece.white_pawn.asType());
    try expectEqual(PieceType.knight, Piece.black_knight.asType());
    try expectEqual(Color.white, Piece.white_queen.color());
    try expectEqual(Color.black, Piece.black_king.color());
}
