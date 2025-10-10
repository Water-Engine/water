const std = @import("std");
const builtin = @import("builtin");

const tt = @import("evaluation/tt.zig");

pub const max_ply: usize = 128;

pub var lmr_weight: f64 = 0.429;
pub var lmr_bias: f64 = 0.769;

pub var rfp_depth: i32 = 8;
pub var rfp_multiplier: i32 = 58;
pub var rfp_improving_deduction: i32 = 69;

pub var nmp_improving_margin: i32 = 72;
pub var nmp_base: usize = 3;
pub var nmp_depth_divisor: usize = 3;
pub var nmp_beta_divisor: i32 = 206;

pub var razoring_base: i32 = 68;
pub var razoring_margin: i32 = 191;

pub var aspiration_window: i32 = 11;

pub var move_overhead: i32 = 10_000;

pub var use_nnue: bool = true;

pub const Default = struct {
    name: []const u8,
    variant: []const u8,
    value: []const u8,
    min_value: []const u8,
    max_value: []const u8,
    underlying: type,
};

pub const OptParseError = error{
    MissingSetOptToken,
    MissingNameToken,
    MissingValueToken,
    UnknownOption,
    InvalidValue,
    ButtonHasValue,
    AllocationError,
    TTFailure,

    SilentSearchOutput,
    LoudSearchOutput,
};

// Make sure you update us if you change default parameters!

pub const defaults = [_]Default{
    // Search specific tuning values
    .{
        .name = "LMRWeight",
        .variant = "spin",
        .value = "429",
        .min_value = "1",
        .max_value = "999",
        .underlying = f64,
    },
    .{
        .name = "LMRBias",
        .variant = "spin",
        .value = "769",
        .min_value = "1",
        .max_value = "9999",
        .underlying = f64,
    },
    .{
        .name = "RFPDepth",
        .variant = "spin",
        .value = "8",
        .min_value = "1",
        .max_value = "16",
        .underlying = i32,
    },
    .{
        .name = "RFPMultiplier",
        .variant = "spin",
        .value = "58",
        .min_value = "1",
        .max_value = "999",
        .underlying = i32,
    },
    .{
        .name = "RFPImprovingDeduction",
        .variant = "spin",
        .value = "69",
        .min_value = "1",
        .max_value = "999",
        .underlying = i32,
    },
    .{
        .name = "NMPImprovingMargin",
        .variant = "spin",
        .value = "72",
        .min_value = "1",
        .max_value = "999",
        .underlying = i32,
    },
    .{
        .name = "NMPBase",
        .variant = "spin",
        .value = "3",
        .min_value = "1",
        .max_value = "16",
        .underlying = usize,
    },
    .{
        .name = "NMPDepthDivisor",
        .variant = "spin",
        .value = "3",
        .min_value = "1",
        .max_value = "16",
        .underlying = usize,
    },
    .{
        .name = "NMPBetaDivisor",
        .variant = "spin",
        .value = "206",
        .min_value = "1",
        .max_value = "999",
        .underlying = i32,
    },
    .{
        .name = "RazoringBase",
        .variant = "spin",
        .value = "68",
        .min_value = "1",
        .max_value = "999",
        .underlying = i32,
    },
    .{
        .name = "RazoringMargin",
        .variant = "spin",
        .value = "191",
        .min_value = "1",
        .max_value = "999",
        .underlying = i32,
    },
    .{
        .name = "AspirationWindow",
        .variant = "spin",
        .value = "11",
        .min_value = "1",
        .max_value = "999",
        .underlying = i32,
    },

    // Transposition table specific options
    .{
        .name = "Clear Hash",
        .variant = "button",
        .value = "",
        .min_value = "",
        .max_value = "",
        .underlying = void,
    },
    .{
        .name = "Hash",
        .variant = "spin",
        .value = "16",
        .min_value = "1",
        .max_value = tt.MaxHashSize.mb_string,
        .underlying = i32,
    },

    // Other options
    .{
        .name = "Silent",
        .variant = "check",
        .value = "false",
        .min_value = "",
        .max_value = "",
        .underlying = bool,
    },
    .{
        .name = "Move Overhead",
        .variant = "spin",
        .value = "10",
        .min_value = "0",
        .max_value = "50",
        .underlying = i32,
    },
    .{
        .name = "Use NNUE",
        .variant = "check",
        .value = "true",
        .min_value = "",
        .max_value = "",
        .underlying = bool,
    },
};

/// Prints the supported options out to the writer.
///
/// Does not flush at the end of the call.
pub fn writeOut(writer: *std.Io.Writer) !void {
    inline for (defaults) |default| {
        try writer.print("option name {s} type {s}", .{
            default.name,
            default.variant,
        });

        if (std.mem.eql(u8, default.variant, "spin")) {
            try writer.print(" default {s} min {s} max {s}", .{
                default.value,
                default.min_value,
                default.max_value,
            });
        } else if (std.mem.eql(u8, default.variant, "check")) {
            try writer.print(" default {s}", .{
                default.value,
            });
        }

        try writer.writeByte('\n');
    }
}

/// Parses the setoption command and updates the engine's internal state.
///
/// The tokenizer is reset upon entry and exit.
pub fn setoption(
    allocator: std.mem.Allocator,
    tokenizer: *std.mem.TokenIterator(u8, .any),
) OptParseError!void {
    tokenizer.reset();
    defer tokenizer.reset();

    // Prepare the parser
    if (tokenizer.next()) |token| {
        if (!std.ascii.eqlIgnoreCase(token, "setoption")) {
            return error.MissingSetOptToken;
        }
    } else return error.MissingSetOptToken;

    if (tokenizer.next()) |token| {
        if (!std.ascii.eqlIgnoreCase(token, "name")) {
            return error.MissingNameToken;
        }
    } else return error.MissingNameToken;

    var name_builder = std.Io.Writer.Allocating.init(allocator);
    defer name_builder.deinit();
    var name_writer = &name_builder.writer;

    var value_builder = std.Io.Writer.Allocating.init(allocator);
    defer value_builder.deinit();
    var value_writer = &value_builder.writer;

    var has_value_token = false;

    // Accumulate the option name until we see "value" or the end of the line
    while (tokenizer.next()) |token| {
        if (std.ascii.eqlIgnoreCase(token, "value")) {
            has_value_token = true;
            break;
        }

        if (name_writer.buffered().len > 0) {
            name_writer.writeByte(' ') catch return error.AllocationError;
        }
        name_writer.writeAll(token) catch return error.AllocationError;
    }

    // If we found a "value" token, accumulate the rest as the value
    if (has_value_token) {
        while (tokenizer.next()) |token| {
            if (value_writer.buffered().len > 0) {
                value_writer.writeByte(' ') catch return error.AllocationError;
            }
            value_writer.writeAll(token) catch return error.AllocationError;
        }

        if (value_builder.written().len == 0) {
            return error.MissingValueToken;
        }
    }

    const option_name = name_builder.written();
    const option_value = value_builder.written();

    // Find the matching option in our defaults array and update the corresponding variable
    inline for (defaults, 0..) |default, i| {
        if (std.ascii.eqlIgnoreCase(option_name, default.name)) {
            // This is a button type, it should not have a value.
            if (std.mem.eql(u8, default.variant, "button")) {
                if (has_value_token) return error.ButtonHasValue;
                switch (i) {
                    12 => tt.global_tt.reset(null) catch return error.TTFailure,
                    else => unreachable,
                }
                return;
            }

            // This is a spin type, it must have a value.
            if (!has_value_token) return error.MissingValueToken;

            const T = default.underlying;
            switch (T) {
                f64 => {
                    const val = std.fmt.parseInt(
                        i64,
                        option_value,
                        10,
                    ) catch return error.InvalidValue;

                    const scaled_val: f64 = @floatFromInt(val);
                    switch (i) {
                        0 => lmr_weight = std.math.clamp(scaled_val / 1000.0, 0.001, 0.999),
                        1 => lmr_bias = std.math.clamp(scaled_val / 1000.0, 0.001, 9.999),
                        else => unreachable,
                    }
                },
                i32 => {
                    const val = std.fmt.parseInt(
                        i32,
                        option_value,
                        10,
                    ) catch return error.InvalidValue;

                    switch (i) {
                        2 => rfp_depth = std.math.clamp(val, 1, 16),
                        3 => rfp_multiplier = std.math.clamp(val, 1, 999),
                        4 => rfp_improving_deduction = std.math.clamp(val, 1, 999),
                        5 => nmp_improving_margin = std.math.clamp(val, 1, 999),
                        8 => nmp_beta_divisor = std.math.clamp(val, 1, 999),
                        9 => razoring_base = std.math.clamp(val, 1, 999),
                        10 => razoring_margin = std.math.clamp(val, 1, 999),
                        11 => aspiration_window = std.math.clamp(val, 1, 999),
                        15 => move_overhead = 1000 * std.math.clamp(val, 0, 50),
                        else => unreachable,
                    }
                },
                usize => {
                    const val = std.fmt.parseInt(
                        usize,
                        option_value,
                        10,
                    ) catch return error.InvalidValue;

                    switch (i) {
                        6 => nmp_base = std.math.clamp(val, 1, 16),
                        7 => nmp_depth_divisor = std.math.clamp(val, 1, 16),
                        13 => tt.global_tt.reset(
                            std.math.clamp(val, 1, tt.MaxHashSize.mb_size),
                        ) catch return error.TTFailure,
                        else => unreachable,
                    }
                },
                bool => {
                    const val = if (std.ascii.eqlIgnoreCase("true", option_value)) blk: {
                        break :blk true;
                    } else if (std.ascii.eqlIgnoreCase("1", option_value)) blk: {
                        break :blk true;
                    } else if (std.ascii.eqlIgnoreCase("false", option_value)) blk: {
                        break :blk false;
                    } else if (std.ascii.eqlIgnoreCase("0", option_value)) blk: {
                        break :blk false;
                    } else return error.InvalidValue;

                    switch (i) {
                        14 => return if (val) error.SilentSearchOutput else error.LoudSearchOutput,
                        16 => use_nnue = val,
                        else => unreachable,
                    }
                },
                void => {},
                else => @compileError("Unsupported option type: " ++ @typeName(T)),
            }

            // If we successfully found and set the option, we're done
            return;
        }
    }

    // If the loop completes without returning, the option name was not found
    return error.UnknownOption;
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;
const expectApproxEqAbs = testing.expectApproxEqAbs;
const expectError = testing.expectError;

test "Option printing" {
    const allocator = testing.allocator;

    var string_builder = std.Io.Writer.Allocating.init(allocator);
    defer string_builder.deinit();
    const string_writer = &string_builder.writer;

    try writeOut(string_writer);

    const expected_output = try std.fmt.allocPrint(allocator,
        \\option name LMRWeight type spin default 429 min 1 max 999
        \\option name LMRBias type spin default 769 min 1 max 9999
        \\option name RFPDepth type spin default 8 min 1 max 16
        \\option name RFPMultiplier type spin default 58 min 1 max 999
        \\option name RFPImprovingDeduction type spin default 69 min 1 max 999
        \\option name NMPImprovingMargin type spin default 72 min 1 max 999
        \\option name NMPBase type spin default 3 min 1 max 16
        \\option name NMPDepthDivisor type spin default 3 min 1 max 16
        \\option name NMPBetaDivisor type spin default 206 min 1 max 999
        \\option name RazoringBase type spin default 68 min 1 max 999
        \\option name RazoringMargin type spin default 191 min 1 max 999
        \\option name AspirationWindow type spin default 11 min 1 max 999
        \\option name Clear Hash type button
        \\option name Hash type spin default 16 min 1 max {s}
        \\option name Silent type check default false
        \\option name Move Overhead type spin default 10 min 0 max 50
        \\option name Use NNUE type check default true
        \\
    , .{tt.MaxHashSize.mb_string});
    defer allocator.free(expected_output);

    try expectEqualSlices(u8, expected_output, string_builder.written());
}

test "Parameter setting" {
    // The lion does not concern himself with loops
    const allocator = testing.allocator;

    // Missing option flag
    var missing_opt = std.mem.tokenizeAny(
        u8,
        "name RFPImprovingDeduction value 120",
        " \t\n\r",
    );
    const result_mo = setoption(allocator, &missing_opt);
    try expectError(OptParseError.MissingSetOptToken, result_mo);

    // Missing "name" token
    var miss_name = std.mem.tokenizeAny(
        u8,
        "setoption value 500",
        " \t\n\r",
    );
    const result_mn = setoption(allocator, &miss_name);
    try expectError(OptParseError.MissingNameToken, result_mn);

    // Missing "value" token
    var miss_value = std.mem.tokenizeAny(
        u8,
        "setoption name LMRWeight",
        " \t\n\r",
    );
    const result_mv = setoption(allocator, &miss_value);
    try expectError(OptParseError.MissingValueToken, result_mv);

    // Valid LMRWeight option
    var valid_lmr = std.mem.tokenizeAny(
        u8,
        "setoption name LMRWeight value 500",
        " \t\n\r",
    );
    try setoption(allocator, &valid_lmr);
    try expectApproxEqAbs(0.5, lmr_weight, 0.005);

    // Valid NMPBase option
    var valid_nmp = std.mem.tokenizeAny(
        u8,
        "setoption name NMPBase value 4",
        " \t\n\r",
    );
    try setoption(allocator, &valid_nmp);
    try expectEqual(4, nmp_base);

    // Valid RFPImprovingDeduction option
    var valid_rfp = std.mem.tokenizeAny(
        u8,
        "setoption name RFPImprovingDeduction value 120",
        " \t\n\r",
    );
    try setoption(allocator, &valid_rfp);
    try expectEqual(120, rfp_improving_deduction);

    // Unknown option
    var fake = std.mem.tokenizeAny(
        u8,
        "setoption name Some Fake Option value 10",
        " \t\n\r",
    );
    const result_fake = setoption(allocator, &fake);
    try expectError(OptParseError.UnknownOption, result_fake);

    // Invalid value (non-numeric)
    var invalid_val = std.mem.tokenizeAny(
        u8,
        "setoption name NMPBase value ninety",
        " \t\n\r",
    );
    const result_inv = setoption(allocator, &invalid_val);
    try expectError(OptParseError.InvalidValue, result_inv);

    // Valid button option
    tt.global_tt = try tt.TranspositionTable.init(allocator, 1);
    defer tt.global_tt.deinit();
    var button_valid = std.mem.tokenizeAny(
        u8,
        "setoption name Clear Hash",
        " \t\n\r",
    );
    try setoption(allocator, &button_valid);

    // Invalid button option (has a value)
    var button_invalid = std.mem.tokenizeAny(
        u8,
        "setoption name Clear Hash value 123",
        " \t\n\r",
    );
    const result_button = setoption(allocator, &button_invalid);
    try expectError(OptParseError.ButtonHasValue, result_button);

    // Silent option set to true
    var silent_true = std.mem.tokenizeAny(
        u8,
        "setoption name Silent value true",
        " \t\n\r",
    );
    const result_silent_t = setoption(allocator, &silent_true);
    try expectError(OptParseError.SilentSearchOutput, result_silent_t);

    var silent_true_numeric = std.mem.tokenizeAny(
        u8,
        "setoption name Silent value 1",
        " \t\n\r",
    );
    const result_silent_t_numeric = setoption(allocator, &silent_true_numeric);
    try expectError(OptParseError.SilentSearchOutput, result_silent_t_numeric);

    // Silent option set to false
    var silent_false = std.mem.tokenizeAny(
        u8,
        "setoption name Silent value false",
        " \t\n\r",
    );
    const result_silent_f = setoption(allocator, &silent_false);
    try expectError(OptParseError.LoudSearchOutput, result_silent_f);

    var silent_false_numeric = std.mem.tokenizeAny(
        u8,
        "setoption name Silent value false",
        " \t\n\r",
    );
    const result_silent_f_numeric = setoption(allocator, &silent_false_numeric);
    try expectError(OptParseError.LoudSearchOutput, result_silent_f_numeric);

    // Silent option with invalid boolean value
    var silent_invalid = std.mem.tokenizeAny(
        u8,
        "setoption name Silent value maybe",
        " \t\n\r",
    );
    const result_silent_inv = setoption(allocator, &silent_invalid);
    try expectError(OptParseError.InvalidValue, result_silent_inv);
}
