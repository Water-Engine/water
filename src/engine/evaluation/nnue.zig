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
        const p = piece.asType().index();
        const color = piece.color();

        const white = color.index() * 64 * 6 + p * 64 + square;
        const black = color.opposite().index() * 64 * 6 + p * 64 + square ^ 56;

        return .{
            .white = white * hidden_size,
            .black = black * hidden_size,
        };
    }
};

pub const Accumulator = struct {
    white: [hidden_size]i16 = model.layers.layer_1_bias,
    black: [hidden_size]i16 = model.layers.layer_1_bias,

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
        // TODO: Keep inline/comptime structure but move to SIMD
        inline for (0..hidden_size) |i| {
            switch (comptime delta) {
                .add => {
                    self.white[i] += model.layers.layer_1[data.white + i];
                    self.black[i] += model.layers.layer_1[data.black + i];
                },
                .sub => {
                    self.white[i] -= model.layers.layer_1[data.white + i];
                    self.black[i] -= model.layers.layer_1[data.black + i];
                },
            }
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

    pub fn evaluate(self: *NNUE, board: *const water.Board) i32 {
        std.debug.assert(board.side_to_move.valid());
        const color_selector = board.side_to_move.asInt(i32);
        const inv_color_selector = 1 - color_selector;

        const bucket = getBucket(board);
        var res: i32 = @intCast(model.layers.layer_2_bias[bucket]);

        const hl_half_1 = model.layers.layer_2[bucket];
        const hl_half_2 = model.layers.layer_2[bucket][hidden_size..];

        @setEvalBranchQuota(4 * hidden_size);
        // TODO: Keep inline/comptime structure but move to SIMD
        inline for (0..hidden_size) |i| {
            const crelu_white = Network.activation(
                self.accumulator.white[i],
                0,
                quantized_a,
                .crelu,
            );

            const crelu_black = Network.activation(
                self.accumulator.black[i],
                0,
                quantized_a,
                .crelu,
            );

            const hl_half_1_val = hl_half_1[i];
            const hl_half_2_val = hl_half_2[i];

            res += (inv_color_selector * crelu_white + inv_color_selector * crelu_black) * hl_half_1_val;
            res += (color_selector * crelu_white + color_selector * crelu_black) * hl_half_2_val;
        }

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

test "Model operation" {
    const allocator = testing.allocator;
    const board = try water.Board.init(allocator, .{});
    defer board.deinit();

    var nnue = NNUE{};
    nnue.refresh(board);
    const eval = nnue.evaluate(board);
    _ = eval;
}
