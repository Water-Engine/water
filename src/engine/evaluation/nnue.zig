const std = @import("std");
const water = @import("water");
const nets = @import("nets");

const parameters = @import("../parameters.zig");

// This is a gem https://www.chessprogramming.org/NNUE
const quantized_a: i32 = 255;
const quantized_b: i32 = 64;
const quantized_ab = quantized_a * quantized_b;
const squared_activation = true;

const scale: i32 = 400;

const input_size: usize = 768;
const hidden_size: usize = 512;
const output_size: usize = 8;

const NNUEWeights = extern struct {
    layer_1: [input_size * hidden_size]i16 align(64),
    layer_1_bias: [hidden_size]i16 align(64),
    layer_2: [output_size][hidden_size * 2]i16 align(64),
    layer_2_bias: [output_size]i16 align(64),
};

const Network = water.network.Network(NNUEWeights);
const model = Network.static(nets.bingshan);

pub const PiecePair = packed struct {
    white: usize,
    black: usize,

    /// Builds the white and black indices in the net for the piece on the given square.
    pub fn init(piece: water.Piece, square: usize) PiecePair {
        std.debug.assert(piece.valid() and water.Square.fromInt(usize, square).valid());
        const p = piece.asType().index();
        const color = piece.color();

        const white = color.index() * 64 * 6 + p * 64 + square;
        const black = color.opposite().index() * 64 * 6 + p * 64 + (square ^ 56);

        return .{
            .white = white * hidden_size,
            .black = black * hidden_size,
        };
    }
};

const VecI16_16 = @Vector(16, i16);
const vec16_len = @typeInfo(VecI16_16).vector.len;
const VecI32_8 = @Vector(8, i32);
const VecI32_16 = @Vector(16, i32);

pub const vec16_iter = blk: {
    if (vec16_len % hidden_size == 0) {
        @compileError("Hidden size must be a multiple of 16");
    }

    const count = (hidden_size / 16);

    var indices: [count]usize = undefined;
    for (0..count) |i| {
        indices[i] = i * 16;
    }

    const s_indices = indices;
    break :blk s_indices;
};

pub const Accumulator = struct {
    white: [hidden_size]i16 align(32) = model.layers.layer_1_bias,
    black: [hidden_size]i16 align(32) = model.layers.layer_1_bias,

    pub inline fn clear(self: *Accumulator) void {
        self.white = model.layers.layer_1_bias;
        self.black = model.layers.layer_1_bias;
    }

    pub fn update(
        self: *Accumulator,
        data: PiecePair,
        comptime delta: enum(i32) { add, sub },
    ) void {
        @setEvalBranchQuota(4 * hidden_size);
        if (vec16_len % hidden_size == 0) {
            @compileError("Hidden size must be a multiple of 16");
        }

        inline for (vec16_iter) |i| {
            // White accumulator operation
            const white_acc_ptr = @as(*VecI16_16, @alignCast(self.white[i .. i + 16]));
            const white_weights_ptr = @as(
                *const VecI16_16,
                @ptrCast(@alignCast(model.layers.layer_1[data.white + i .. data.white + i + 16])),
            );

            const white_acc_vec = white_acc_ptr.*;
            const white_weights_vec = white_weights_ptr.*;

            white_acc_ptr.* = switch (comptime delta) {
                .add => white_acc_vec + white_weights_vec,
                .sub => white_acc_vec - white_weights_vec,
            };

            // Black accumulator operation
            const black_acc_ptr = @as(*VecI16_16, @alignCast(self.black[i .. i + 16]));
            const black_weights_ptr = @as(
                *const VecI16_16,
                @ptrCast(@alignCast(model.layers.layer_1[data.black + i .. data.black + i + 16])),
            );

            const black_acc_vec = black_acc_ptr.*;
            const black_weights_vec = black_weights_ptr.*;

            black_acc_ptr.* = switch (comptime delta) {
                .add => black_acc_vec + black_weights_vec,
                .sub => black_acc_vec - black_weights_vec,
            };
        }
    }
};

pub const NNUE = struct {
    accumulator: Accumulator = .{},

    pub fn refresh(self: *NNUE, board: *const water.Board) void {
        self.accumulator.clear();

        for (board.mailbox, 0..) |piece, square| {
            if (piece == .none) continue;
            self.toggle(piece, square, .on);
        }
    }

    pub fn toggle(
        self: *NNUE,
        piece: water.Piece,
        square: usize,
        comptime delta: enum { on, off },
    ) void {
        self.accumulator.update(
            .init(piece, square),
            comptime switch (delta) {
                .on => .add,
                .off => .sub,
            },
        );
    }

    fn getBucket(board: *const water.Board) usize {
        return (board.occ().count() - 2) / 4;
    }

    fn widenLow(comptime Vec: type, v: *const Vec) VecI32_8 {
        var res: VecI32_8 = undefined;
        inline for (0..8) |i| res[i] = @intCast(v[i]);
        return res;
    }

    fn widenHigh(comptime Vec: type, v: *const Vec) VecI32_8 {
        var res: VecI32_8 = undefined;
        inline for (0..8) |i| res[i] = @intCast(v[i + 8]);
        return res;
    }

    fn activation(
        values: VecI16_16,
        comptime min: i16,
        comptime max: i16,
        comptime func: enum { relu, crelu, screlu },
    ) VecI32_16 {
        return switch (comptime func) {
            .relu => @max(values, @as(VecI16_16, @splat(0))),
            .crelu => std.math.clamp(
                values,
                @as(VecI32_16, @splat(min)),
                @as(VecI32_16, @splat(max)),
            ),
            .screlu => blk: {
                const clamped = std.math.clamp(
                    values,
                    @as(VecI32_16, @splat(min)),
                    @as(VecI32_16, @splat(max)),
                );
                const extended = @as(VecI32_16, clamped);
                break :blk extended * extended;
            },
        };
    }

    pub fn evaluate(self: *NNUE, board: *const water.Board) i32 {
        std.debug.assert(board.side_to_move.valid());
        const color_selector: VecI32_8 = @splat(board.side_to_move.asInt(i32));
        const inv_color_selector = @as(VecI32_8, @splat(1)) - color_selector;

        const bucket = getBucket(board);
        const initial_bias: i32 = @intCast(model.layers.layer_2_bias[bucket]);
        var res_vec: VecI32_8 = @splat(0);

        @setEvalBranchQuota(4 * hidden_size);
        inline for (vec16_iter) |i| {
            const white_acc_ptr = @as(*const VecI16_16, @alignCast(self.accumulator.white[i .. i + 16]));
            const black_acc_ptr = @as(*const VecI16_16, @alignCast(self.accumulator.black[i .. i + 16]));
            const hidden_layer_1 = @as(*const VecI16_16, @alignCast(model.layers.layer_2[bucket][i .. i + 16]));
            const hidden_layer_2 = @as(*const VecI16_16, @alignCast(model.layers.layer_2[bucket][hidden_size + i .. hidden_size + i + 16]));

            const screlu_white = activation(white_acc_ptr.*, 0, quantized_a, .screlu);
            const screlu_black = activation(black_acc_ptr.*, 0, quantized_a, .screlu);

            // Low 8 lane accumulate
            {
                const screlu_white_low = widenLow(VecI32_16, &screlu_white);
                const screlu_black_low = widenLow(VecI32_16, &screlu_black);
                const hidden_layer_1_low = widenLow(VecI16_16, hidden_layer_1);
                const hidden_layer_2_low = widenLow(VecI16_16, hidden_layer_2);

                const term_a = inv_color_selector * screlu_white_low + color_selector * screlu_black_low;
                const term_b = color_selector * screlu_white_low + inv_color_selector * screlu_black_low;

                res_vec = term_a * hidden_layer_1_low + res_vec;
                res_vec = term_b * hidden_layer_2_low + res_vec;
            }

            // High 8 lane accumulate
            {
                const screlu_white_high = widenHigh(VecI32_16, &screlu_white);
                const screlu_black_high = widenHigh(VecI32_16, &screlu_black);
                const hidden_layer_1_high = widenHigh(VecI16_16, hidden_layer_1);
                const hidden_layer_2_high = widenHigh(VecI16_16, hidden_layer_2);

                const term_a = inv_color_selector * screlu_white_high + color_selector * screlu_black_high;
                const term_b = color_selector * screlu_white_high + inv_color_selector * screlu_black_high;

                res_vec = term_a * hidden_layer_1_high + res_vec;
                res_vec = term_b * hidden_layer_2_high + res_vec;
            }
        }

        const reduced: i32 = @reduce(.Add, res_vec);
        const res = initial_bias + reduced;

        return blk: {
            if (comptime squared_activation) {
                break :blk @divTrunc(@divTrunc(res, quantized_a) * scale, quantized_ab);
            } else {
                break :blk @divTrunc(res * scale, quantized_ab);
            }
        };
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;

test "Network creation" {
    const allocator = testing.allocator;

    const test_input_size: usize = 768;
    const test_hidden_size: usize = 512;
    const test_output_size: usize = 8;

    const TestArch = extern struct {
        layer_1: [test_input_size * test_hidden_size]i16 align(64),
        layer_1_bias: [test_hidden_size]i16 align(64),
        layer_2: [test_output_size][test_hidden_size * 2]i16 align(64),
        layer_2_bias: [test_output_size]i16 align(64),
    };
    const TestNetwork = water.network.Network(TestArch);

    const mismatch = TestNetwork.init(allocator, "bingshan");
    try expectError(error.SizeMismatch, mismatch);

    var valid = try TestNetwork.init(allocator, nets.bingshan);
    defer valid.deinit();
}

test "Model creation" {
    const allocator = testing.allocator;
    const board = try water.Board.init(allocator, .{});
    defer board.deinit();

    var nnue = NNUE{};
    nnue.refresh(board);
    _ = nnue.evaluate(board);

    // First 50 expected values for each layer of the model
    const layers = model.layers;

    // First layer
    const l1_expected = [_]i16{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };

    for (0..50) |i| {
        try expectEqual(l1_expected[i], layers.layer_1[i]);
    }

    // First layer bias
    const l1_bias_expected = [_]i16{
        35,  -19, -43, 15,  -40, -31, -46, 6,   -74,
        -7,  -54, -10, -11, 33,  -11, 96,  53,  -79,
        19,  -57, -34, 35,  -27, -21, -28, -2,  -35,
        -3,  -36, -12, -17, 23,  76,  -86, -8,  -45,
        101, -8,  41,  38,  -59, -22, -10, -25, -12,
        -47, -46, 0,   -51, -13,
    };

    for (0..50) |i| {
        try expectEqual(l1_bias_expected[i], layers.layer_1_bias[i]);
    }

    // Second layer
    const l2_expected = [_]i16{
        -55, 9,   24,  7,  20,  0,   -1,  2,  -28, -8,  0,    -5,
        -2,  103, -3,  29, -39, -55, -33, -1, -10, 6,   -101, 17,
        -7,  0,   0,   -3, -60, 22,  -73, 3,  46,  -13, 11,   -3,
        -4,  -10, -41, 26, 4,   25,  0,   3,  -2,  11,  -10,  -22,
        -17, -5,  6,
    };

    for (0..50) |i| {
        try expectEqual(l2_expected[i], layers.layer_2[0][i]);
    }

    // Second layer bias
    const l2_bias_expected = [_]i16{
        -585, -139, 278, 711, 960, 878, 671, 292,
    };

    for (0..8) |i| {
        try expectEqual(l2_bias_expected[i], layers.layer_2_bias[i]);
    }
}

test "NNUE evaluation correctness" {
    const allocator = testing.allocator;
    const board = try water.Board.init(allocator, .{});
    defer board.deinit();

    var net = NNUE{};

    // Random FEN strings from http://bernd.bplaced.net/fengenerator/fengenerator.html
    // Expected evaluations from Avalanche using bingshan model
    const short_fens = [_][]const u8{
        "8/4k3/8/2K5/8/P5P1/6B1/8 w - - 0 1",
        "8/2k5/6P1/3K2p1/6n1/8/8/8 w - - 0 1",
        "6Q1/8/7k/2b5/3N4/8/8/5K2 w - - 0 1",
        "8/3P1p2/3b4/8/5k2/8/3K4/8 w - - 0 1",
        "1N6/4p3/6K1/8/8/4Bk2/8/8 w - - 0 1",
        "8/8/K7/8/B7/Q7/6k1/7b w - - 0 1",
        "8/8/4P3/4kp2/1K6/8/1p6/8 w - - 0 1",
        "8/8/1k1n4/5p2/5p2/8/4K3/8 w - - 0 1",
        "8/1p6/7K/8/3k4/P7/1r6/8 w - - 0 1",
        "6K1/p7/p7/6k1/8/8/4p3/8 w - - 0 1",
    };

    const nnue_evals_short = [_]i32{
        1101, -292, 654, -483, 207, 633, -99, -901, -1104, -1189,
    };

    for (short_fens, 0..) |fen, i| {
        try expect(try board.setFen(fen, true));
        net.refresh(board);
        try expectEqual(nnue_evals_short[i], net.evaluate(board));
    }

    const long_fens = [_][]const u8{
        "r1N1R3/pPb3R1/q4BNP/PPpK4/b1rP2P1/pP2Pn1n/k1ppp1pp/5B1Q w - - 0 1",
        "R6N/RbBp1Pp1/1p1n1k1p/1P1B2qp/P1PP2Pn/1p2NP1K/1p2pPQ1/1r2b1r1 w - - 0 1",
        "b3NBK1/R4pp1/1PqPR1NP/4p3/2rPPpnb/2k1PP1P/p1p2prp/nQ5B w - - 0 1",
        "2q2n1b/p1P2BQP/p1PN1p1K/5PP1/N1Rprppn/2B3P1/1pPpb2P/1R4rk w - - 0 1",
        "8/1pP2bRP/P1rppp1P/PP1kp2p/p1N2nNb/1PqPnp1Q/1Br4R/3B3K w - - 0 1",
        "7K/1N1Qpr2/p1PB1rPk/pPp5/q2n1Rpp/P1PPPbpB/p1P5/bR1N3n w - - 0 1",
        "BR1n3Q/1P1pbr1P/Pp2p3/1NrpPP2/p2PR2p/Bn1ppk2/KP5P/1N2q2b w - - 0 1",
        "1R1q4/n2bP1rR/1BNP1n1p/PPpp3p/kP3PP1/br4p1/BpP1p2p/1K2QN2 w - - 0 1",
        "2N3N1/pnR2BP1/P1b2PpQ/1p1R1PKP/q3P2p/1Pb1nr1p/k1pp1pP1/4B1r1 w - - 0 1",
        "B6N/QP2pPbR/2q1p2p/2PRp2p/Pk2p1r1/nP1PPr2/1Kpp2PN/1bB3n1 w - - 0 1",
    };

    const nnue_evals_long = [_]i32{
        -1461, -57, 10, 217, 581, -314, 583, 259, -174, 114,
    };

    for (long_fens, 0..) |fen, i| {
        try expect(try board.setFen(fen, true));
        net.refresh(board);
        try expectEqual(nnue_evals_long[i], net.evaluate(board));
    }
}
