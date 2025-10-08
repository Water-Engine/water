const std = @import("std");

const types = @import("../core/types.zig");
const Square = types.Square;
const Rank = types.Rank;
const File = types.File;
const Color = types.Color;

const bitboard = @import("../core/bitboard.zig");
const Bitboard = bitboard.Bitboard;

const piece = @import("../core/piece.zig");
const PieceType = piece.PieceType;

const board_ = @import("../board/board.zig");
const Board = board_.Board;

const slider_bbs = @import("slider_bbs.zig");

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

const FlatSliderAttacks = struct {
    attacks: []const Bitboard,
    offsets: [64]usize,
};

/// Flattens a 2D array of Bitboards a 1D array with an offset table.
fn flatten(comptime attacks_2d: [64][]const Bitboard) FlatSliderAttacks {
    @setEvalBranchQuota(100_000_000);

    var total_len: comptime_int = 0;
    inline for (attacks_2d) |slice| {
        total_len += slice.len;
    }

    return comptime blk: {
        var flat_attacks: [total_len]Bitboard = undefined;
        var offsets: [64]usize = undefined;
        var current_offset: usize = 0;

        for (attacks_2d, 0..) |slice, i| {
            offsets[i] = current_offset;
            for (slice, 0..) |bb, j| {
                flat_attacks[current_offset + j] = bb;
            }

            current_offset += slice.len;
        }

        const s_attacks = flat_attacks;
        break :blk FlatSliderAttacks{
            .attacks = &s_attacks,
            .offsets = offsets,
        };
    };
}

const pawn_attacks_u64: [2][64]u64 = .{
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

const knight_attacks_u64: [64]u64 = .{
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

const king_attacks_u64: [64]u64 = .{
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

const pawn_attacks_2d: [2][64]Bitboard = toBitboardArray(@TypeOf(pawn_attacks_u64), pawn_attacks_u64);
const pawn_attacks: [128]Bitboard = pawn_attacks_2d[0] ++ pawn_attacks_2d[1];

const knight_attacks: [64]Bitboard = toBitboardArray(@TypeOf(knight_attacks_u64), knight_attacks_u64);
const king_attacks: [64]Bitboard = toBitboardArray(@TypeOf(king_attacks_u64), king_attacks_u64);

const rook_attacks_2d: [64][]const Bitboard = .{
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_00), slider_bbs.rook_attacks_00), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_01), slider_bbs.rook_attacks_01),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_02), slider_bbs.rook_attacks_02), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_03), slider_bbs.rook_attacks_03),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_04), slider_bbs.rook_attacks_04), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_05), slider_bbs.rook_attacks_05),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_06), slider_bbs.rook_attacks_06), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_07), slider_bbs.rook_attacks_07),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_08), slider_bbs.rook_attacks_08), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_09), slider_bbs.rook_attacks_09),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_10), slider_bbs.rook_attacks_10), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_11), slider_bbs.rook_attacks_11),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_12), slider_bbs.rook_attacks_12), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_13), slider_bbs.rook_attacks_13),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_14), slider_bbs.rook_attacks_14), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_15), slider_bbs.rook_attacks_15),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_16), slider_bbs.rook_attacks_16), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_17), slider_bbs.rook_attacks_17),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_18), slider_bbs.rook_attacks_18), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_19), slider_bbs.rook_attacks_19),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_20), slider_bbs.rook_attacks_20), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_21), slider_bbs.rook_attacks_21),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_22), slider_bbs.rook_attacks_22), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_23), slider_bbs.rook_attacks_23),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_24), slider_bbs.rook_attacks_24), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_25), slider_bbs.rook_attacks_25),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_26), slider_bbs.rook_attacks_26), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_27), slider_bbs.rook_attacks_27),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_28), slider_bbs.rook_attacks_28), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_29), slider_bbs.rook_attacks_29),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_30), slider_bbs.rook_attacks_30), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_31), slider_bbs.rook_attacks_31),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_32), slider_bbs.rook_attacks_32), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_33), slider_bbs.rook_attacks_33),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_34), slider_bbs.rook_attacks_34), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_35), slider_bbs.rook_attacks_35),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_36), slider_bbs.rook_attacks_36), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_37), slider_bbs.rook_attacks_37),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_38), slider_bbs.rook_attacks_38), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_39), slider_bbs.rook_attacks_39),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_40), slider_bbs.rook_attacks_40), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_41), slider_bbs.rook_attacks_41),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_42), slider_bbs.rook_attacks_42), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_43), slider_bbs.rook_attacks_43),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_44), slider_bbs.rook_attacks_44), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_45), slider_bbs.rook_attacks_45),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_46), slider_bbs.rook_attacks_46), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_47), slider_bbs.rook_attacks_47),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_48), slider_bbs.rook_attacks_48), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_49), slider_bbs.rook_attacks_49),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_50), slider_bbs.rook_attacks_50), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_51), slider_bbs.rook_attacks_51),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_52), slider_bbs.rook_attacks_52), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_53), slider_bbs.rook_attacks_53),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_54), slider_bbs.rook_attacks_54), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_55), slider_bbs.rook_attacks_55),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_56), slider_bbs.rook_attacks_56), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_57), slider_bbs.rook_attacks_57),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_58), slider_bbs.rook_attacks_58), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_59), slider_bbs.rook_attacks_59),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_60), slider_bbs.rook_attacks_60), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_61), slider_bbs.rook_attacks_61),
    &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_62), slider_bbs.rook_attacks_62), &toBitboardArray(@TypeOf(slider_bbs.rook_attacks_63), slider_bbs.rook_attacks_63),
};
const rook_attacks = flatten(rook_attacks_2d);

const bishop_attacks_2d: [64][]const Bitboard = .{
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_00), slider_bbs.bishop_attacks_00), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_01), slider_bbs.bishop_attacks_01),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_02), slider_bbs.bishop_attacks_02), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_03), slider_bbs.bishop_attacks_03),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_04), slider_bbs.bishop_attacks_04), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_05), slider_bbs.bishop_attacks_05),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_06), slider_bbs.bishop_attacks_06), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_07), slider_bbs.bishop_attacks_07),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_08), slider_bbs.bishop_attacks_08), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_09), slider_bbs.bishop_attacks_09),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_10), slider_bbs.bishop_attacks_10), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_11), slider_bbs.bishop_attacks_11),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_12), slider_bbs.bishop_attacks_12), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_13), slider_bbs.bishop_attacks_13),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_14), slider_bbs.bishop_attacks_14), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_15), slider_bbs.bishop_attacks_15),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_16), slider_bbs.bishop_attacks_16), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_17), slider_bbs.bishop_attacks_17),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_18), slider_bbs.bishop_attacks_18), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_19), slider_bbs.bishop_attacks_19),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_20), slider_bbs.bishop_attacks_20), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_21), slider_bbs.bishop_attacks_21),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_22), slider_bbs.bishop_attacks_22), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_23), slider_bbs.bishop_attacks_23),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_24), slider_bbs.bishop_attacks_24), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_25), slider_bbs.bishop_attacks_25),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_26), slider_bbs.bishop_attacks_26), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_27), slider_bbs.bishop_attacks_27),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_28), slider_bbs.bishop_attacks_28), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_29), slider_bbs.bishop_attacks_29),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_30), slider_bbs.bishop_attacks_30), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_31), slider_bbs.bishop_attacks_31),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_32), slider_bbs.bishop_attacks_32), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_33), slider_bbs.bishop_attacks_33),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_34), slider_bbs.bishop_attacks_34), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_35), slider_bbs.bishop_attacks_35),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_36), slider_bbs.bishop_attacks_36), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_37), slider_bbs.bishop_attacks_37),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_38), slider_bbs.bishop_attacks_38), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_39), slider_bbs.bishop_attacks_39),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_40), slider_bbs.bishop_attacks_40), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_41), slider_bbs.bishop_attacks_41),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_42), slider_bbs.bishop_attacks_42), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_43), slider_bbs.bishop_attacks_43),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_44), slider_bbs.bishop_attacks_44), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_45), slider_bbs.bishop_attacks_45),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_46), slider_bbs.bishop_attacks_46), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_47), slider_bbs.bishop_attacks_47),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_48), slider_bbs.bishop_attacks_48), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_49), slider_bbs.bishop_attacks_49),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_50), slider_bbs.bishop_attacks_50), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_51), slider_bbs.bishop_attacks_51),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_52), slider_bbs.bishop_attacks_52), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_53), slider_bbs.bishop_attacks_53),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_54), slider_bbs.bishop_attacks_54), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_55), slider_bbs.bishop_attacks_55),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_56), slider_bbs.bishop_attacks_56), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_57), slider_bbs.bishop_attacks_57),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_58), slider_bbs.bishop_attacks_58), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_59), slider_bbs.bishop_attacks_59),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_60), slider_bbs.bishop_attacks_60), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_61), slider_bbs.bishop_attacks_61),
    &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_62), slider_bbs.bishop_attacks_62), &toBitboardArray(@TypeOf(slider_bbs.bishop_attacks_63), slider_bbs.bishop_attacks_63),
};
const bishop_attacks = flatten(bishop_attacks_2d);

pub fn pawn(color: Color, square: Square) Bitboard {
    std.debug.assert(color.valid());
    return pawn_attacks[64 * color.index() + square.index()];
}

pub fn pawnLeftAttacks(comptime C: Color, pawns: Bitboard) Bitboard {
    return blk: {
        if (comptime C.isWhite()) {
            break :blk pawns.shl(7).andBB(Bitboard.fromInt(u64, File.fh.mask()).not());
        } else {
            break :blk pawns.shr(7).andBB(Bitboard.fromInt(u64, File.fa.mask()).not());
        }
    };
}

pub fn pawnRightAttacks(comptime C: Color, pawns: Bitboard) Bitboard {
    return blk: {
        if (comptime C.isWhite()) {
            break :blk pawns.shl(9).andBB(Bitboard.fromInt(u64, File.fa.mask()).not());
        } else {
            break :blk pawns.shr(9).andBB(Bitboard.fromInt(u64, File.fh.mask()).not());
        }
    };
}

pub fn knight(square: Square) Bitboard {
    return knight_attacks[square.index()];
}

pub fn king(square: Square) Bitboard {
    return king_attacks[square.index()];
}

pub fn rook(square: Square, occupied: Bitboard) Bitboard {
    const index = square.index();
    const masked_occ = occupied.andBB(slider_bbs.rook_masks[index]);
    const key = (masked_occ.mulU64Wrapped(slider_bbs.rook_magics[index])).shr(slider_bbs.rook_shifts[index]);
    return rook_attacks.attacks[rook_attacks.offsets[index] + @as(usize, @truncate(key.bits))];
}

pub fn bishop(square: Square, occupied: Bitboard) Bitboard {
    const index = square.index();
    const masked_occ = occupied.andBB(slider_bbs.bishop_masks[index]);
    const key = (masked_occ.mulU64Wrapped(slider_bbs.bishop_magics[index])).shr(slider_bbs.bishop_shifts[index]);
    return bishop_attacks.attacks[bishop_attacks.offsets[index] + @as(usize, @truncate(key.bits))];
}

pub fn queen(square: Square, occupied: Bitboard) Bitboard {
    return rook(square, occupied).orBB(bishop(square, occupied));
}

/// Returns all slider attacks for the PieceType on the given square.
pub fn slider(comptime pt: PieceType, square: Square, occupied: Bitboard) Bitboard {
    return switch (pt) {
        .rook => rook(square, occupied),
        .bishop => bishop(square, occupied),
        .queen => queen(square, occupied),
        else => @compileError("PieceType must be a slider!"),
    };
}

/// Returns the attacks for the given piece (and color, for pawns) from the given square.
///
/// This is equivalent to dispatching the individual attack functions in a conditional.
pub fn attacks(pt: PieceType, color: Color, square: Square, occupied: Bitboard) Bitboard {
    return switch (pt) {
        .rook => rook(square, occupied),
        .bishop => bishop(square, occupied),
        .queen => queen(square, occupied),
        .pawn => blk: {
            if (color == .none) {
                break :blk pawn(.white, square).andBB(pawn(.black, square));
            } else {
                break :blk pawn(color, square);
            }
        },
        .king => king(square),
        .knight => knight(square),
        .none => unreachable,
    };
}

/// Shifts the given bitboard in the given direction
pub fn shift(comptime D: Square.Direction, bb: Bitboard) Bitboard {
    return switch (D) {
        .north => |d| return bb.shl(@abs(d.asInt(i32))),
        .south => |d| return bb.shr(@abs(d.asInt(i32))),
        .east => |d| return bb.andU64(~File.masks[7]).shl(@abs(d.asInt(i32))),
        .west => |d| return bb.andU64(~File.masks[0]).shr(@abs(d.asInt(i32))),
        .north_east => |d| return bb.andU64(~File.masks[7]).shl(@abs(d.asInt(i32))),
        .north_west => |d| return bb.andU64(~File.masks[0]).shl(@abs(d.asInt(i32))),
        .south_east => |d| return bb.andU64(~File.masks[7]).shr(@abs(d.asInt(i32))),
        .south_west => |d| return bb.andU64(~File.masks[0]).shr(@abs(d.asInt(i32))),
    };
}

/// Returns the origin squares of pieces of a given color attacking a target square.
///
/// Passing a bitboard for occupied overrides the board's occupied status.
pub fn attackers(
    board: *const Board,
    color: Color,
    square: Square,
    comptime include_king: bool,
    options: struct { occupied: ?Bitboard = null },
) Bitboard {
    const queens = board.pieces(color, .queen);
    const occ = options.occupied orelse board.occ();

    // Principle: if we can attack PieceType from square, they can attack us back
    var atks = pawn(color.opposite(), square).andBB(
        board.pieces(color, .pawn),
    );
    _ = atks.orAssign(knight(square).andBB(board.pieces(color, .knight)));
    _ = atks.orAssign(bishop(square, occ).andBB(
        board.pieces(color, .bishop).orBB(queens),
    ));
    _ = atks.orAssign(rook(square, occ).andBB(
        board.pieces(color, .rook).orBB(queens),
    ));

    if (comptime include_king) {
        _ = atks.orAssign(king(square).andBB(board.pieces(color, .king)));
    }

    return atks.andBB(occ);
}

/// Checks if the given color is attacking the square on the board.
///
/// Does not consider whether or not the attack would be an illegal move.
pub fn isAttacked(board: *const Board, color: Color, square: Square) bool {
    if (pawn(color.opposite(), square).andBB(
        board.pieces(color, .pawn),
    ).nonzero()) {
        return true;
    } else if (knight(square).andBB(
        board.pieces(color, .knight),
    ).nonzero()) {
        return true;
    } else if (king(square).andBB(
        board.pieces(color, .king),
    ).nonzero()) {
        return true;
    } else if (bishop(square, board.occ()).andBB(
        board.piecesMany(color, &.{ .bishop, .queen }),
    ).andBB(board.us(color)).nonzero()) {
        return true;
    } else if (rook(square, board.occ()).andBB(
        board.piecesMany(color, &.{ .rook, .queen }),
    ).andBB(board.us(color)).nonzero()) {
        return true;
    }

    return false;
}

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
    try expectEqual(pawn_attacks[64 * Color.white.index() + e2.index()], pawn(.white, e2));
    try expectEqual(pawn_attacks[64 * Color.black.index() + e2.index()], pawn(.black, e2));

    // Comptime pawn left/right attacks
    const w_left = pawnLeftAttacks(.white, white_pawn_bb);
    const w_right = pawnRightAttacks(.white, white_pawn_bb);
    const b_left = pawnLeftAttacks(.black, black_pawn_bb);
    const b_right = pawnRightAttacks(.black, black_pawn_bb);

    try expect(w_left.bits != 0);
    try expect(w_right.bits != 0);
    try expect(b_left.bits != 0);
    try expect(b_right.bits != 0);

    // Knight attacks
    const g1 = Square.fromInt(usize, 6);
    const knight_bb = knight(g1);
    try expect(knight_bb.bits != 0);

    // King attacks
    const e1 = Square.fromInt(usize, 4);
    const king_bb = king(e1);
    try expect(king_bb.bits != 0);

    // Rook attacks
    const occ = Bitboard.fromInt(u64, 0x000000000000FF00);
    const rook_bb = rook(e1, occ);
    try expect(rook_bb.bits != 0);

    // Bishop attacks
    const bishop_bb = bishop(e1, occ);
    try expect(bishop_bb.bits != 0);

    // Queen attacks
    const queen_bb = queen(e1, occ);
    try expect(queen_bb.bits == (rook_bb.orBB(bishop_bb).bits));

    // Slider function
    try expect(slider(.rook, e1, occ).bits == rook_bb.bits);
    try expect(slider(.bishop, e1, occ).bits == bishop_bb.bits);
    try expect(slider(.queen, e1, occ).bits == queen_bb.bits);
}

test "Direction Shifts" {
    const d4_bb = Bitboard.fromSquare(.d4);

    // One-step north from d4 should be d5
    try expectEqual(
        shift(.north, d4_bb).bits,
        Bitboard.fromSquare(.d5).bits,
    );

    // One-step south from d4 should be d3
    try expectEqual(
        shift(.south, d4_bb).bits,
        Bitboard.fromSquare(.d3).bits,
    );

    // One-step east from d4 should be e4
    try expectEqual(
        shift(.east, d4_bb).bits,
        Bitboard.fromSquare(.e4).bits,
    );

    // One-step west from d4 should be c4
    try expectEqual(
        shift(.west, d4_bb).bits,
        Bitboard.fromSquare(.c4).bits,
    );

    // One-step north-east from d4 should be e5
    try expectEqual(
        shift(.north_east, d4_bb).bits,
        Bitboard.fromSquare(.e5).bits,
    );

    // One-step north-west from d4 should be c5
    try expectEqual(
        shift(.north_west, d4_bb).bits,
        Bitboard.fromSquare(.c5).bits,
    );

    // One-step south-east from d4 should be e3
    try expectEqual(
        shift(.south_east, d4_bb).bits,
        Bitboard.fromSquare(.e3).bits,
    );

    // One-step south-west from d4 should be c3
    try expectEqual(
        shift(.south_west, d4_bb).bits,
        Bitboard.fromSquare(.c3).bits,
    );
}

test "Attackers in a complex position" {
    const allocator = testing.allocator;
    var board = try Board.init(
        allocator,
        .{ .fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1" },
    );
    defer board.deinit();

    // Attackers from fen verified with https://github.com/Disservin/chess-library
    const white_attackers: [64]u64 = .{
        0x0000000000000008, 0x0000000000000009, 0x0000000000000009, 0x0000000001000021,
        0x0000000000200028, 0x0000000000000048, 0x0000000000200020, 0x0000000000000040,
        0x0000000000000001, 0x0000000000000000, 0x0000000001000008, 0x0000000002200008,
        0x0000000000000008, 0x0000000000000060, 0x0000000000000040, 0x0000000000200040,
        0x0000000002000000, 0x0000000001000108, 0x0000000002000800, 0x0000000000000000,
        0x0000000000000800, 0x0000000000004028, 0x0000000000008000, 0x0000000000004000,
        0x0000000000000008, 0x0000000000000000, 0x0000000000000000, 0x0000000000200000,
        0x0000000000000000, 0x0000000000000000, 0x0000800000000000, 0x0000000000200000,
        0x0000000002000000, 0x0000000005000000, 0x0000000002000000, 0x0000000014000000,
        0x0000000000200000, 0x0000800010000000, 0x0000000000200000, 0x0000000000000000,
        0x0000000200000000, 0x0000000000000000, 0x0000000200000000, 0x0000000002000000,
        0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000,
        0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000,
        0x0000000002000000, 0x0000800000000000, 0x0000000000000000, 0x0000000000000000,
        0x0000000000000000, 0x0001000000000000, 0x0000000000000000, 0x0000000000000000,
        0x0000000000000000, 0x0000000002000000, 0x0000800000000000, 0x0000000000000000,
    };

    for (0..64) |i| {
        const atks = attackers(
            board,
            .white,
            Square.fromInt(usize, i),
            true,
            .{},
        );
        try expectEqual(white_attackers[i], atks.bits);
    }

    const does_white_attack: [64]bool = .{
        true,  true,  true,  true,  true,  true,  true,  true,
        true,  false, true,  true,  true,  true,  true,  true,
        true,  true,  true,  false, true,  true,  true,  true,
        true,  false, false, true,  false, false, true,  true,
        true,  true,  true,  true,  true,  true,  true,  false,
        true,  false, true,  true,  false, false, false, false,
        false, false, false, false, true,  true,  false, false,
        false, true,  false, false, false, true,  true,  false,
    };

    for (0..64) |i| {
        try expectEqual(
            does_white_attack[i],
            isAttacked(board, .white, Square.fromInt(usize, i)),
        );
    }

    const black_attackers: [64]u64 = .{
        0x0000000000000200, 0x0000000000000000, 0x0000000000000200, 0x0000000000000000,
        0x0000000000000000, 0x0000000000000000, 0x0000020000000000, 0x0000000000000000,
        0x0000000000010000, 0x0000000000010000, 0x0000000000000000, 0x0000000000000000,
        0x0000000000000000, 0x0000020000000000, 0x0000000000000000, 0x0000000000000000,
        0x0000000000000000, 0x0000000100010000, 0x0000000000010000, 0x0000000000010000,
        0x0000020000010000, 0x0000000000010000, 0x0000000000000000, 0x0000000000000000,
        0x0000000000010000, 0x0000000000010000, 0x0000000100000000, 0x0000020000000000,
        0x0000600000000000, 0x0000000000000000, 0x0000200000000000, 0x0000000000000000,
        0x0000020000000000, 0x0000000000000000, 0x0000020000000000, 0x0000200000000000,
        0x0000000000000000, 0x0000400000000000, 0x0000000000000000, 0x0000600000000000,
        0x0002000000000000, 0x0004000000000000, 0x000A000100000000, 0x0004000000000000,
        0x0028000000000000, 0x0040000000000000, 0x00A0000000000000, 0x0040000000000000,
        0x0100020000000000, 0x0000000100000000, 0x0000020000000000, 0x1000200000000000,
        0x1000000000000000, 0x1000400000000000, 0x0000000000000000, 0x8000600000000000,
        0x0000000000000000, 0x0100000000000000, 0x0100000000000000, 0x1100000000000000,
        0x8100200000000000, 0x9000000000000000, 0x8000200000000000, 0x0000000000000000,
    };

    for (0..64) |i| {
        const atks = attackers(
            board,
            .black,
            Square.fromInt(usize, i),
            true,
            .{},
        );
        try expectEqual(black_attackers[i], atks.bits);
    }

    const does_black_attack: [64]bool = .{
        true,  false, true,  false, false, false, true,  false,
        true,  true,  false, false, false, true,  false, false,
        false, true,  true,  true,  true,  true,  false, false,
        true,  true,  true,  true,  true,  false, true,  false,
        true,  false, true,  true,  false, true,  false, true,
        true,  true,  true,  true,  true,  true,  true,  true,
        true,  true,  true,  true,  true,  true,  false, true,
        false, true,  true,  true,  true,  true,  true,  false,
    };

    for (0..64) |i| {
        try expectEqual(
            does_black_attack[i],
            isAttacked(board, .black, Square.fromInt(usize, i)),
        );
    }
}
