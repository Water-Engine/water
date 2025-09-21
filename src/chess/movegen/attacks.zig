const std = @import("std");

const types = @import("../core/types.zig");
const Square = types.Square;
const Rank = types.Rank;
const File = types.File;
const Color = types.Color;

const bitboard = @import("../core/bitboard.zig");
const Bitboard = bitboard.Bitboard;

const piece = @import("../game/piece.zig");
const PieceType = piece.PieceType;

const magics = @import("magics.zig");

/// Converts the type of u64 arrays (or nested) to Bitboard arrays of the same dimensions.
///
/// Example: `[2][64]u64` becomes `[2][64]Bitboard`
pub fn BitboardArrayTransformer(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .array => |info| switch (@typeInfo(info.child)) {
            .int => if (info.child == u64)
                [info.len]Bitboard
            else
                @compileError("Only u64 supported as base integer type"),
            .array => |child_info| [info.len]BitboardArrayTransformer([child_info.len]child_info.child),
            else => @compileError("Unsupported array element type"),
        },
        else => @compileError("Only arrays are supported"),
    };
}

/// Convert an array of u64 (possibly nested) into its equivalent Bitboard array.
pub fn toBitboardArray(comptime T: type, arr: T) BitboardArrayTransformer(T) {
    var result: BitboardArrayTransformer(T) = undefined;

    @setEvalBranchQuota(100_000_000);
    inline for (arr, 0..) |elem, i| {
        switch (@typeInfo(@TypeOf(elem))) {
            .int => result[i] = Bitboard{ .bits = elem },
            .array => result[i] = toBitboardArray(@TypeOf(elem), elem),
            else => @compileError("Unsupported element type"),
        }
    }

    return result;
}

const PawnAttacksU64: [2][64]u64 = .{
    // white pawn attacks
    .{
        0x0000000000000200, 0x0000000000000500, 0x0000000000000A00, 0x0000000000001400,
        0x0000000000002800, 0x0000000000005000, 0x000000000000A000, 0x0000000000004000,
        0x0000000000020000, 0x0000000000050000, 0x00000000000A0000, 0x0000000000140000,
        0x0000000000280000, 0x0000000000500000, 0x0000000000A00000, 0x0000000000400000,
        0x0000000002000000, 0x0000000005000000, 0x000000000A000000, 0x0000000014000000,
        0x0000000028000000, 0x0000000050000000, 0x00000000A0000000, 0x0000000040000000,
        0x0000000200000000, 0x0000000500000000, 0x0000000A00000000, 0x0000001400000000,
        0x0000002800000000, 0x0000005000000000, 0x000000A000000000, 0x0000004000000000,
        0x0000020000000000, 0x0000050000000000, 0x00000A0000000000, 0x0000140000000000,
        0x0000280000000000, 0x0000500000000000, 0x0000A00000000000, 0x0000400000000000,
        0x0002000000000000, 0x0005000000000000, 0x000A000000000000, 0x0014000000000000,
        0x0028000000000000, 0x0050000000000000, 0x00A0000000000000, 0x0040000000000000,
        0x0200000000000000, 0x0500000000000000, 0x0A00000000000000, 0x1400000000000000,
        0x2800000000000000, 0x5000000000000000, 0xA000000000000000, 0x4000000000000000,
        0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000,
        0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000,
    },

    // black pawn attacks
    .{
        0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000,
        0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000,
        0x0000000000000002, 0x0000000000000005, 0x000000000000000A, 0x0000000000000014,
        0x0000000000000028, 0x0000000000000050, 0x00000000000000A0, 0x0000000000000040,
        0x0000000000000200, 0x0000000000000500, 0x0000000000000A00, 0x0000000000001400,
        0x0000000000002800, 0x0000000000005000, 0x000000000000A000, 0x0000000000004000,
        0x0000000000020000, 0x0000000000050000, 0x00000000000A0000, 0x0000000000140000,
        0x0000000000280000, 0x0000000000500000, 0x0000000000A00000, 0x0000000000400000,
        0x0000000002000000, 0x0000000005000000, 0x000000000A000000, 0x0000000014000000,
        0x0000000028000000, 0x0000000050000000, 0x00000000A0000000, 0x0000000040000000,
        0x0000000200000000, 0x0000000500000000, 0x0000000A00000000, 0x0000001400000000,
        0x0000002800000000, 0x0000005000000000, 0x000000A000000000, 0x0000004000000000,
        0x0000020000000000, 0x0000050000000000, 0x00000A0000000000, 0x0000140000000000,
        0x0000280000000000, 0x0000500000000000, 0x0000A00000000000, 0x0000400000000000,
        0x0002000000000000, 0x0005000000000000, 0x000A000000000000, 0x0014000000000000,
        0x0028000000000000, 0x0050000000000000, 0x00A0000000000000, 0x0040000000000000,
    },
};

const KnightAttacksU64: [64]u64 = .{
    0x0000000000020400, 0x0000000000050800, 0x00000000000A1100, 0x0000000000142200,
    0x0000000000284400, 0x0000000000508800, 0x0000000000A01000, 0x0000000000402000,
    0x0000000002040004, 0x0000000005080008, 0x000000000A110011, 0x0000000014220022,
    0x0000000028440044, 0x0000000050880088, 0x00000000A0100010, 0x0000000040200020,
    0x0000000204000402, 0x0000000508000805, 0x0000000A1100110A, 0x0000001422002214,
    0x0000002844004428, 0x0000005088008850, 0x000000A0100010A0, 0x0000004020002040,
    0x0000020400040200, 0x0000050800080500, 0x00000A1100110A00, 0x0000142200221400,
    0x0000284400442800, 0x0000508800885000, 0x0000A0100010A000, 0x0000402000204000,
    0x0002040004020000, 0x0005080008050000, 0x000A1100110A0000, 0x0014220022140000,
    0x0028440044280000, 0x0050880088500000, 0x00A0100010A00000, 0x0040200020400000,
    0x0204000402000000, 0x0508000805000000, 0x0A1100110A000000, 0x1422002214000000,
    0x2844004428000000, 0x5088008850000000, 0xA0100010A0000000, 0x4020002040000000,
    0x0400040200000000, 0x0800080500000000, 0x1100110A00000000, 0x2200221400000000,
    0x4400442800000000, 0x8800885000000000, 0x100010A000000000, 0x2000204000000000,
    0x0004020000000000, 0x0008050000000000, 0x00110A0000000000, 0x0022140000000000,
    0x0044280000000000, 0x0088500000000000, 0x0010A00000000000, 0x0020400000000000,
};

const KingAttacksU64: [64]u64 = .{
    0x0000000000000302, 0x0000000000000705, 0x0000000000000E0A, 0x0000000000001C14,
    0x0000000000003828, 0x0000000000007050, 0x000000000000E0A0, 0x000000000000C040,
    0x0000000000030203, 0x0000000000070507, 0x00000000000E0A0E, 0x00000000001C141C,
    0x0000000000382838, 0x0000000000705070, 0x0000000000E0A0E0, 0x0000000000C040C0,
    0x0000000003020300, 0x0000000007050700, 0x000000000E0A0E00, 0x000000001C141C00,
    0x0000000038283800, 0x0000000070507000, 0x00000000E0A0E000, 0x00000000C040C000,
    0x0000000302030000, 0x0000000705070000, 0x0000000E0A0E0000, 0x0000001C141C0000,
    0x0000003828380000, 0x0000007050700000, 0x000000E0A0E00000, 0x000000C040C00000,
    0x0000030203000000, 0x0000070507000000, 0x00000E0A0E000000, 0x00001C141C000000,
    0x0000382838000000, 0x0000705070000000, 0x0000E0A0E0000000, 0x0000C040C0000000,
    0x0003020300000000, 0x0007050700000000, 0x000E0A0E00000000, 0x001C141C00000000,
    0x0038283800000000, 0x0070507000000000, 0x00E0A0E000000000, 0x00C040C000000000,
    0x0302030000000000, 0x0705070000000000, 0x0E0A0E0000000000, 0x1C141C0000000000,
    0x3828380000000000, 0x7050700000000000, 0xE0A0E00000000000, 0xC040C00000000000,
    0x0203000000000000, 0x0507000000000000, 0x0A0E000000000000, 0x141C000000000000,
    0x2838000000000000, 0x5070000000000000, 0xA0E0000000000000, 0x40C0000000000000,
};

const PawnAttacks: [2][64]Bitboard = toBitboardArray(@TypeOf(PawnAttacksU64), PawnAttacksU64);
const KnightAttacks: [64]Bitboard = toBitboardArray(@TypeOf(KnightAttacksU64), KnightAttacksU64);
const KingAttacks: [64]Bitboard = toBitboardArray(@TypeOf(KingAttacksU64), KingAttacksU64);

const RookAttacks: [64][]const Bitboard = .{
    &toBitboardArray(@TypeOf(magics.RookAttacks00), magics.RookAttacks00), &toBitboardArray(@TypeOf(magics.RookAttacks01), magics.RookAttacks01),
    &toBitboardArray(@TypeOf(magics.RookAttacks02), magics.RookAttacks02), &toBitboardArray(@TypeOf(magics.RookAttacks03), magics.RookAttacks03),
    &toBitboardArray(@TypeOf(magics.RookAttacks04), magics.RookAttacks04), &toBitboardArray(@TypeOf(magics.RookAttacks05), magics.RookAttacks05),
    &toBitboardArray(@TypeOf(magics.RookAttacks06), magics.RookAttacks06), &toBitboardArray(@TypeOf(magics.RookAttacks07), magics.RookAttacks07),
    &toBitboardArray(@TypeOf(magics.RookAttacks08), magics.RookAttacks08), &toBitboardArray(@TypeOf(magics.RookAttacks09), magics.RookAttacks09),
    &toBitboardArray(@TypeOf(magics.RookAttacks10), magics.RookAttacks10), &toBitboardArray(@TypeOf(magics.RookAttacks11), magics.RookAttacks11),
    &toBitboardArray(@TypeOf(magics.RookAttacks12), magics.RookAttacks12), &toBitboardArray(@TypeOf(magics.RookAttacks13), magics.RookAttacks13),
    &toBitboardArray(@TypeOf(magics.RookAttacks14), magics.RookAttacks14), &toBitboardArray(@TypeOf(magics.RookAttacks15), magics.RookAttacks15),
    &toBitboardArray(@TypeOf(magics.RookAttacks16), magics.RookAttacks16), &toBitboardArray(@TypeOf(magics.RookAttacks17), magics.RookAttacks17),
    &toBitboardArray(@TypeOf(magics.RookAttacks18), magics.RookAttacks18), &toBitboardArray(@TypeOf(magics.RookAttacks19), magics.RookAttacks19),
    &toBitboardArray(@TypeOf(magics.RookAttacks20), magics.RookAttacks20), &toBitboardArray(@TypeOf(magics.RookAttacks21), magics.RookAttacks21),
    &toBitboardArray(@TypeOf(magics.RookAttacks22), magics.RookAttacks22), &toBitboardArray(@TypeOf(magics.RookAttacks23), magics.RookAttacks23),
    &toBitboardArray(@TypeOf(magics.RookAttacks24), magics.RookAttacks24), &toBitboardArray(@TypeOf(magics.RookAttacks25), magics.RookAttacks25),
    &toBitboardArray(@TypeOf(magics.RookAttacks26), magics.RookAttacks26), &toBitboardArray(@TypeOf(magics.RookAttacks27), magics.RookAttacks27),
    &toBitboardArray(@TypeOf(magics.RookAttacks28), magics.RookAttacks28), &toBitboardArray(@TypeOf(magics.RookAttacks29), magics.RookAttacks29),
    &toBitboardArray(@TypeOf(magics.RookAttacks30), magics.RookAttacks30), &toBitboardArray(@TypeOf(magics.RookAttacks31), magics.RookAttacks31),
    &toBitboardArray(@TypeOf(magics.RookAttacks32), magics.RookAttacks32), &toBitboardArray(@TypeOf(magics.RookAttacks33), magics.RookAttacks33),
    &toBitboardArray(@TypeOf(magics.RookAttacks34), magics.RookAttacks34), &toBitboardArray(@TypeOf(magics.RookAttacks35), magics.RookAttacks35),
    &toBitboardArray(@TypeOf(magics.RookAttacks36), magics.RookAttacks36), &toBitboardArray(@TypeOf(magics.RookAttacks37), magics.RookAttacks37),
    &toBitboardArray(@TypeOf(magics.RookAttacks38), magics.RookAttacks38), &toBitboardArray(@TypeOf(magics.RookAttacks39), magics.RookAttacks39),
    &toBitboardArray(@TypeOf(magics.RookAttacks40), magics.RookAttacks40), &toBitboardArray(@TypeOf(magics.RookAttacks41), magics.RookAttacks41),
    &toBitboardArray(@TypeOf(magics.RookAttacks42), magics.RookAttacks42), &toBitboardArray(@TypeOf(magics.RookAttacks43), magics.RookAttacks43),
    &toBitboardArray(@TypeOf(magics.RookAttacks44), magics.RookAttacks44), &toBitboardArray(@TypeOf(magics.RookAttacks45), magics.RookAttacks45),
    &toBitboardArray(@TypeOf(magics.RookAttacks46), magics.RookAttacks46), &toBitboardArray(@TypeOf(magics.RookAttacks47), magics.RookAttacks47),
    &toBitboardArray(@TypeOf(magics.RookAttacks48), magics.RookAttacks48), &toBitboardArray(@TypeOf(magics.RookAttacks49), magics.RookAttacks49),
    &toBitboardArray(@TypeOf(magics.RookAttacks50), magics.RookAttacks50), &toBitboardArray(@TypeOf(magics.RookAttacks51), magics.RookAttacks51),
    &toBitboardArray(@TypeOf(magics.RookAttacks52), magics.RookAttacks52), &toBitboardArray(@TypeOf(magics.RookAttacks53), magics.RookAttacks53),
    &toBitboardArray(@TypeOf(magics.RookAttacks54), magics.RookAttacks54), &toBitboardArray(@TypeOf(magics.RookAttacks55), magics.RookAttacks55),
    &toBitboardArray(@TypeOf(magics.RookAttacks56), magics.RookAttacks56), &toBitboardArray(@TypeOf(magics.RookAttacks57), magics.RookAttacks57),
    &toBitboardArray(@TypeOf(magics.RookAttacks58), magics.RookAttacks58), &toBitboardArray(@TypeOf(magics.RookAttacks59), magics.RookAttacks59),
    &toBitboardArray(@TypeOf(magics.RookAttacks60), magics.RookAttacks60), &toBitboardArray(@TypeOf(magics.RookAttacks61), magics.RookAttacks61),
    &toBitboardArray(@TypeOf(magics.RookAttacks62), magics.RookAttacks62), &toBitboardArray(@TypeOf(magics.RookAttacks63), magics.RookAttacks63),
};

const BishopAttacks: [64][]const Bitboard = .{
    &toBitboardArray(@TypeOf(magics.BishopAttacks00), magics.BishopAttacks00), &toBitboardArray(@TypeOf(magics.BishopAttacks01), magics.BishopAttacks01),
    &toBitboardArray(@TypeOf(magics.BishopAttacks02), magics.BishopAttacks02), &toBitboardArray(@TypeOf(magics.BishopAttacks03), magics.BishopAttacks03),
    &toBitboardArray(@TypeOf(magics.BishopAttacks04), magics.BishopAttacks04), &toBitboardArray(@TypeOf(magics.BishopAttacks05), magics.BishopAttacks05),
    &toBitboardArray(@TypeOf(magics.BishopAttacks06), magics.BishopAttacks06), &toBitboardArray(@TypeOf(magics.BishopAttacks07), magics.BishopAttacks07),
    &toBitboardArray(@TypeOf(magics.BishopAttacks08), magics.BishopAttacks08), &toBitboardArray(@TypeOf(magics.BishopAttacks09), magics.BishopAttacks09),
    &toBitboardArray(@TypeOf(magics.BishopAttacks10), magics.BishopAttacks10), &toBitboardArray(@TypeOf(magics.BishopAttacks11), magics.BishopAttacks11),
    &toBitboardArray(@TypeOf(magics.BishopAttacks12), magics.BishopAttacks12), &toBitboardArray(@TypeOf(magics.BishopAttacks13), magics.BishopAttacks13),
    &toBitboardArray(@TypeOf(magics.BishopAttacks14), magics.BishopAttacks14), &toBitboardArray(@TypeOf(magics.BishopAttacks15), magics.BishopAttacks15),
    &toBitboardArray(@TypeOf(magics.BishopAttacks16), magics.BishopAttacks16), &toBitboardArray(@TypeOf(magics.BishopAttacks17), magics.BishopAttacks17),
    &toBitboardArray(@TypeOf(magics.BishopAttacks18), magics.BishopAttacks18), &toBitboardArray(@TypeOf(magics.BishopAttacks19), magics.BishopAttacks19),
    &toBitboardArray(@TypeOf(magics.BishopAttacks20), magics.BishopAttacks20), &toBitboardArray(@TypeOf(magics.BishopAttacks21), magics.BishopAttacks21),
    &toBitboardArray(@TypeOf(magics.BishopAttacks22), magics.BishopAttacks22), &toBitboardArray(@TypeOf(magics.BishopAttacks23), magics.BishopAttacks23),
    &toBitboardArray(@TypeOf(magics.BishopAttacks24), magics.BishopAttacks24), &toBitboardArray(@TypeOf(magics.BishopAttacks25), magics.BishopAttacks25),
    &toBitboardArray(@TypeOf(magics.BishopAttacks26), magics.BishopAttacks26), &toBitboardArray(@TypeOf(magics.BishopAttacks27), magics.BishopAttacks27),
    &toBitboardArray(@TypeOf(magics.BishopAttacks28), magics.BishopAttacks28), &toBitboardArray(@TypeOf(magics.BishopAttacks29), magics.BishopAttacks29),
    &toBitboardArray(@TypeOf(magics.BishopAttacks30), magics.BishopAttacks30), &toBitboardArray(@TypeOf(magics.BishopAttacks31), magics.BishopAttacks31),
    &toBitboardArray(@TypeOf(magics.BishopAttacks32), magics.BishopAttacks32), &toBitboardArray(@TypeOf(magics.BishopAttacks33), magics.BishopAttacks33),
    &toBitboardArray(@TypeOf(magics.BishopAttacks34), magics.BishopAttacks34), &toBitboardArray(@TypeOf(magics.BishopAttacks35), magics.BishopAttacks35),
    &toBitboardArray(@TypeOf(magics.BishopAttacks36), magics.BishopAttacks36), &toBitboardArray(@TypeOf(magics.BishopAttacks37), magics.BishopAttacks37),
    &toBitboardArray(@TypeOf(magics.BishopAttacks38), magics.BishopAttacks38), &toBitboardArray(@TypeOf(magics.BishopAttacks39), magics.BishopAttacks39),
    &toBitboardArray(@TypeOf(magics.BishopAttacks40), magics.BishopAttacks40), &toBitboardArray(@TypeOf(magics.BishopAttacks41), magics.BishopAttacks41),
    &toBitboardArray(@TypeOf(magics.BishopAttacks42), magics.BishopAttacks42), &toBitboardArray(@TypeOf(magics.BishopAttacks43), magics.BishopAttacks43),
    &toBitboardArray(@TypeOf(magics.BishopAttacks44), magics.BishopAttacks44), &toBitboardArray(@TypeOf(magics.BishopAttacks45), magics.BishopAttacks45),
    &toBitboardArray(@TypeOf(magics.BishopAttacks46), magics.BishopAttacks46), &toBitboardArray(@TypeOf(magics.BishopAttacks47), magics.BishopAttacks47),
    &toBitboardArray(@TypeOf(magics.BishopAttacks48), magics.BishopAttacks48), &toBitboardArray(@TypeOf(magics.BishopAttacks49), magics.BishopAttacks49),
    &toBitboardArray(@TypeOf(magics.BishopAttacks50), magics.BishopAttacks50), &toBitboardArray(@TypeOf(magics.BishopAttacks51), magics.BishopAttacks51),
    &toBitboardArray(@TypeOf(magics.BishopAttacks52), magics.BishopAttacks52), &toBitboardArray(@TypeOf(magics.BishopAttacks53), magics.BishopAttacks53),
    &toBitboardArray(@TypeOf(magics.BishopAttacks54), magics.BishopAttacks54), &toBitboardArray(@TypeOf(magics.BishopAttacks55), magics.BishopAttacks55),
    &toBitboardArray(@TypeOf(magics.BishopAttacks56), magics.BishopAttacks56), &toBitboardArray(@TypeOf(magics.BishopAttacks57), magics.BishopAttacks57),
    &toBitboardArray(@TypeOf(magics.BishopAttacks58), magics.BishopAttacks58), &toBitboardArray(@TypeOf(magics.BishopAttacks59), magics.BishopAttacks59),
    &toBitboardArray(@TypeOf(magics.BishopAttacks60), magics.BishopAttacks60), &toBitboardArray(@TypeOf(magics.BishopAttacks61), magics.BishopAttacks61),
    &toBitboardArray(@TypeOf(magics.BishopAttacks62), magics.BishopAttacks62), &toBitboardArray(@TypeOf(magics.BishopAttacks63), magics.BishopAttacks63),
};

pub const Attacks = struct {
    pub fn pawn(color: Color, square: Square) Bitboard {
        return PawnAttacks[color.index()][square.index()];
    }

    pub fn pawnLeftAttacks(comptime C: Color, pawns: Bitboard) Bitboard {
        return if (C.isWhite()) blk: {
            break :blk pawns.shl(7).andBB(Bitboard.fromInt(u64, File.fh.mask()).not());
        } else blk: {
            break :blk pawns.shr(7).andBB(Bitboard.fromInt(u64, File.fa.mask()).not());
        };
    }

    pub fn pawnRightAttacks(comptime C: Color, pawns: Bitboard) Bitboard {
        return if (C.isWhite()) blk: {
            break :blk pawns.shl(9).andBB(Bitboard.fromInt(u64, File.fh.mask()).not());
        } else blk: {
            break :blk pawns.shr(9).andBB(Bitboard.fromInt(u64, File.fa.mask()).not());
        };
    }

    pub fn knight(square: Square) Bitboard {
        return KnightAttacks[square.index()];
    }

    pub fn king(square: Square) Bitboard {
        return KingAttacks[square.index()];
    }

    pub fn rook(square: Square, occupied: Bitboard) Bitboard {
        const index = square.index();
        const masked_occ = occupied.andBB(magics.RookMasks[index]);
        const key = (masked_occ.mulU64Wrapped(magics.RookMagics[index])).shr(magics.RookShifts[index]);
        return RookAttacks[index][key.bits];
    }

    pub fn bishop(square: Square, occupied: Bitboard) Bitboard {
        const index = square.index();
        const masked_occ = occupied.andBB(magics.BishopMasks[index]);
        const key = (masked_occ.mulU64Wrapped(magics.BishopMagics[index])).shr(magics.BishopShifts[index]);
        return BishopAttacks[index][key.bits];
    }

    pub fn queen(square: Square, occupied: Bitboard) Bitboard {
        return rook(square, occupied).orBB(bishop(square, occupied));
    }

    pub fn slider(comptime PT: PieceType, square: Square, occupied: Bitboard) Bitboard {
        return switch (PT) {
            .rook => rook(square, occupied),
            .bishop => bishop(square, occupied),
            .queen => queen(square, occupied),
            else => @compileError("PieceType must be a slider!"),
        };
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

// === TESTING ===
test "Bitboard Array Transformations" {
    // Types converted appropriately
    try expectEqual([3]Bitboard, BitboardArrayTransformer([3]u64));
    try expectEqual([2][2]Bitboard, BitboardArrayTransformer([2][2]u64));
    try expectEqual([0]Bitboard, BitboardArrayTransformer([0]u64));

    // Flat case
    const flat: [3]u64 = .{ 1, 2, 3 };
    const flat_bb: [3]Bitboard = toBitboardArray(@TypeOf(flat), flat);
    try expectEqual(@as(u64, 1), flat_bb[0].bits);
    try expectEqual(@as(u64, 2), flat_bb[1].bits);
    try expectEqual(@as(u64, 3), flat_bb[2].bits);

    // Nested case
    const nested: [2][2]u64 = .{ .{ 10, 20 }, .{ 30, 40 } };
    const nested_bb: [2][2]Bitboard = toBitboardArray(@TypeOf(nested), nested);
    try expectEqual(@as(u64, 10), nested_bb[0][0].bits);
    try expectEqual(@as(u64, 20), nested_bb[0][1].bits);
    try expectEqual(@as(u64, 30), nested_bb[1][0].bits);
    try expectEqual(@as(u64, 40), nested_bb[1][1].bits);

    // Empty case
    const empty: [0]u64 = .{};
    const empty_bb: [0]Bitboard = toBitboardArray(@TypeOf(empty), empty);
    try expectEqual(@as(usize, 0), empty_bb.len);
}

test "Attacks" {
    // Pawn attacks
    const e2 = Square.fromInt(usize, 12); // Example: e2
    const white_pawn_bb = Bitboard.fromInt(u64, @as(u64, 1) << @truncate(e2.index()));
    const black_pawn_bb = Bitboard.fromInt(u64, @as(u64, 1) << @truncate(e2.index()));

    // Simple lookups
    try expectEqual(PawnAttacks[Color.white.index()][e2.index()], Attacks.pawn(.white, e2));
    try expectEqual(PawnAttacks[Color.black.index()][e2.index()], Attacks.pawn(.black, e2));

    // Comptime pawn left/right attacks
    const w_left = Attacks.pawnLeftAttacks(.white, white_pawn_bb);
    const w_right = Attacks.pawnRightAttacks(.white, white_pawn_bb);
    const b_left = Attacks.pawnLeftAttacks(.black, black_pawn_bb);
    const b_right = Attacks.pawnRightAttacks(.black, black_pawn_bb);

    try expect(w_left.bits != 0);
    try expect(w_right.bits != 0);
    try expect(b_left.bits != 0);
    try expect(b_right.bits != 0);

    // Knight attacks
    const g1 = Square.fromInt(usize, 6);
    const knight_bb = Attacks.knight(g1);
    try expect(knight_bb.bits != 0);

    // King attacks
    const e1 = Square.fromInt(usize, 4);
    const king_bb = Attacks.king(e1);
    try expect(king_bb.bits != 0);

    // Rook attacks
    const occ = Bitboard.fromInt(u64, 0x000000000000FF00);
    const rook_bb = Attacks.rook(e1, occ);
    try expect(rook_bb.bits != 0);

    // Bishop attacks
    const bishop_bb = Attacks.bishop(e1, occ);
    try expect(bishop_bb.bits != 0);

    // Queen attacks
    const queen_bb = Attacks.queen(e1, occ);
    try expect(queen_bb.bits == (rook_bb.orBB(bishop_bb).bits));

    // Slider function
    try expect(Attacks.slider(.rook, e1, occ).bits == rook_bb.bits);
    try expect(Attacks.slider(.bishop, e1, occ).bits == bishop_bb.bits);
    try expect(Attacks.slider(.queen, e1, occ).bits == queen_bb.bits);
}
