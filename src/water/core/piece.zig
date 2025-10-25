const std = @import("std");

const Color = @import("../core/types.zig").Color;

/// All possible piece types for classical and fischer random chess.
///
/// Includes a sentinel `none` value in favor of using optionals.
pub const PieceType = enum(u3) {
    pawn = 0,
    knight = 1,
    bishop = 2,
    rook = 3,
    queen = 4,
    king = 5,

    none = 6,

    /// All of the valid PieceType, especially useful in for loops.
    pub const all: [6]PieceType = .{ .pawn, .knight, .bishop, .rook, .queen, .king };

    /// Checks if the PieceType is not `none`.
    pub fn valid(self: *const PieceType) bool {
        return self.* != .none;
    }

    /// Creates a PieceType from the given integer.
    pub fn fromInt(comptime T: type, num: T) PieceType {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @enumFromInt(num),
            else => @compileError("T must be an integer type"),
        };
    }

    // Returns the enum value as the given integer type.
    pub fn asInt(self: *const PieceType, comptime T: type) T {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @intFromEnum(self.*),
            else => @compileError("T must be an integer type"),
        };
    }

    // This does exactly what you think.
    pub fn index(self: *const PieceType) usize {
        return self.asInt(usize);
    }

    /// Converts the first character of the input string to its PieceType representation.
    ///
    /// Invalid characters are `.none`.
    pub fn fromStr(str: []const u8) PieceType {
        return if (str.len == 0) .none else fromChar(str[0]);
    }

    /// Returns the tag name of the PieceType.
    pub fn asStr(self: *const PieceType) []const u8 {
        return @tagName(self.*);
    }

    /// Converts the byte to its PieceType representation.
    ///
    /// Invalid characters are `.none`.
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

    /// Returns the byte representation of the PieceType.
    ///
    /// The `.none` variant is represented as '-'.
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

    pub fn order(lhs: PieceType, rhs: PieceType) std.math.Order {
        const lhs_val = lhs.asInt(i32);
        const rhs_val = rhs.asInt(i32);

        return std.math.order(lhs_val, rhs_val);
    }
};

/// All possible pieces for classical and fischer random chess.
///
/// Includes a sentinel `none` value in favor of using optionals.
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

    /// Alias for using `Piece.none`.
    ///
    /// Only included for unity with other more useful `init` functions.
    pub fn init() Piece {
        return .none;
    }

    /// Makes a Piece with the given color and type.
    ///
    /// No assertions are made.
    pub fn make(piece_color: Color, piece_type: PieceType) Piece {
        return Piece.fromInt(
            usize,
            piece_type.asInt(usize) + piece_color.asInt(usize) * 6,
        );
    }

    /// Checks if the Piece is not `none`.
    pub fn valid(self: *const Piece) bool {
        return self.* != .none;
    }

    /// Creates a Piece from the given integer.
    pub fn fromInt(comptime T: type, num: T) Piece {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @enumFromInt(num),
            else => @compileError("T must be an integer type"),
        };
    }

    // Returns the enum value as the given integer type.
    pub fn asInt(self: *const Piece, comptime T: type) T {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => @intFromEnum(self.*),
            else => @compileError("T must be an integer type"),
        };
    }

    // This does exactly what you think.
    pub fn index(self: *const Piece) usize {
        return self.asInt(usize);
    }

    /// Converts the byte to its Piece representation.
    ///
    /// Invalid characters are `.none`.
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

    /// Returns the byte representation of the Piece.
    ///
    /// The `.none` variant is represented as '-'.
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

    pub fn order(lhs: Piece, rhs: Piece) std.math.Order {
        const lhs_val = lhs.asInt(i32);
        const rhs_val = rhs.asInt(i32);

        return std.math.order(lhs_val, rhs_val);
    }

    /// Determines the underlying PieceType of the Piece.
    ///
    /// This is branchless and generally very inexpensive.
    pub fn asType(self: *const Piece) PieceType {
        const is_black = @intFromBool(self.asInt(i32) > 5);
        const offset = 6 * @as(i32, is_black);
        return PieceType.fromInt(i32, self.asInt(i32) - offset);
    }

    /// Determines the underlying Color of the Piece.
    ///
    /// This is branchless and generally very inexpensive.
    pub fn color(self: *const Piece) Color {
        const is_black = self.order(.white_king) == .gt;
        const color_if_valid = @as(u8, @intFromBool(is_black));
        const none_val = @intFromEnum(Color.none);

        // Selector is is -1 if the piece is NOT none, and 0 otherwise.
        const selector = -@as(i8, @intFromBool(self.* != .none));

        const final_val = (color_if_valid & @as(u8, @bitCast(selector))) |
            (none_val & ~@as(u8, @bitCast(selector)));

        return @enumFromInt(final_val);
    }
};

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "PieceType" {
    const expected_all: [6]PieceType = .{ .pawn, .knight, .bishop, .rook, .queen, .king };
    for (expected_all, PieceType.all) |expected, actual| {
        try expectEqual(expected, actual);
    }

    try expectEqual(PieceType.pawn, PieceType.fromInt(u8, 0));
    try expectEqual(PieceType.knight, PieceType.fromInt(u8, 1));

    try expectEqual(PieceType.pawn, PieceType.fromChar('p'));
    try expectEqual(PieceType.knight, PieceType.fromChar('N'));
    try expectEqual(PieceType.none, PieceType.fromChar('x'));

    try expectEqual('p', PieceType.pawn.asChar());
    try expectEqual('n', PieceType.knight.asChar());
    try expectEqual('-', PieceType.none.asChar());

    try expect(PieceType.pawn.order(.pawn) == .eq);
    try expect(PieceType.pawn.order(.knight) != .eq);
    try expect(PieceType.pawn.order(.knight) == .lt);
    try expect(PieceType.rook.order(.pawn) == .gt);
}

test "Piece" {
    var pc = Piece.init();
    try expect(pc == .none);
    try expect(!pc.valid());
    pc = .white_pawn;
    try expect(pc.valid());

    try expectEqual(Piece.white_pawn, Piece.fromInt(u8, 0));
    try expectEqual(Piece.black_king, Piece.fromInt(u8, 11));

    try expectEqual(0, Piece.white_pawn.asInt(u8));
    try expectEqual(11, Piece.black_king.asInt(u8));

    try expectEqual(Piece.black_knight, Piece.make(.black, .knight));
    try expectEqual(Piece.white_pawn, Piece.make(.white, .pawn));

    try expectEqual(Piece.white_pawn, Piece.fromChar('P'));
    try expectEqual(Piece.black_knight, Piece.fromChar('n'));
    try expectEqual(Piece.none, Piece.fromChar('x'));

    try expectEqual('P', Piece.white_pawn.asChar());
    try expectEqual('n', Piece.black_knight.asChar());
    try expectEqual('-', Piece.none.asChar());

    try expect(Piece.white_pawn.order(.white_pawn) == .eq);
    try expect(Piece.white_pawn.order(.white_knight) != .eq);
    try expect(Piece.white_pawn.order(.white_knight) == .lt);
    try expect(Piece.black_pawn.order(.white_king) == .gt);

    try expectEqual(PieceType.pawn, Piece.white_pawn.asType());
    try expectEqual(PieceType.knight, Piece.black_knight.asType());
    try expectEqual(Color.white, Piece.white_queen.color());
    try expectEqual(Color.black, Piece.black_king.color());
}
