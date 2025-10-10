const std = @import("std");
const water = @import("water");

const parameters = @import("../../parameters.zig");
const network = @import("network.zig");

// This is a gem https://www.chessprogramming.org/NNUE
const quantized_a: i32 = 255;
const quantized_b: i32 = 64;
const quantized_ab = quantized_a * quantized_b;

const scale: i32 = 400;

const input_size: usize = 768;
const hidden_size: usize = 512;
const output_size: usize = 8;

const NNUEWeights = struct {
    layer_1: [input_size * hidden_size]i16 align(64),
    layer_1_bias: [hidden_size]i16 align(64),
    layer_2: [output_size][hidden_size * 2]i16 align(64),
    layer_2_bias: [output_size]i16 align(64),
};

const Network = network.Network(NNUEWeights);
const model = Network.static(network);

pub const PiecePair = packed struct {
    white: usize,
    black: usize,

    /// Builds the white and black indices in the net for the piece on the given square.
    pub fn init(piece: water.Piece, square: water.Square) PiecePair {
        const p = piece.asType().index();
        const c = piece.color().index();
        const s = square.index();

        const white = c * 64 * 6 + p * 64 + s;
        const black = c * 64 * 6 + p * 64 + s ^ 56;

        return .{
            .white = white * hidden_size,
            .black = black * hidden_size,
        };
    }
};

pub const Accumulator = packed struct {
    white: [hidden_size]i16,
    black: [hidden_size]i16,

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

/// This is literally a statically sized stack that is coupled with Accumulators.
///
/// Fully stack allocated, no heap allocations ever.
pub const NNUE = struct {
    accumulators: [parameters.max_ply + 2]Accumulator = std.mem.zeroes(Accumulator),
    size: usize = 0,
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;
