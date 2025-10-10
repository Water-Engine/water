const std = @import("std");
const water = @import("water");
const nets = @import("nets");

/// Creates a Network type tailored to the provided network architecture.
///
/// Arch must be a struct type, but no other safety checks are performed.
///
/// An example Arch type might look like:
/// ```
/// pub const NNUEWeights = struct {
///     layer_1: [INPUT_SIZE * HIDDEN_SIZE]i16 align(64),
///     layer_1_bias: [HIDDEN_SIZE]i16 align(64),
///     layer_2: [OUTPUT_SIZE][HIDDEN_SIZE * 2]i16 align(64),
///     layer_2_bias: [OUTPUT_SIZE]i16 align(64),
/// };
/// ```
///
/// This type factory also exposes bucketing and activation helpers.
pub fn Network(comptime Arch: type) type {
    return struct {
        const Self = @This();

        allocator: ?std.mem.Allocator,
        data_blob: []u8,

        layers: Arch,

        /// Loads and parses a network file for this specific architecture.
        ///
        /// An instance of the architecture is stored internally.
        /// The source length must be the exact size of the Arch struct.
        ///
        /// The original data is also stored internally.
        /// The provided source, if allocated externally, can be freed safely.
        pub fn init(allocator: std.mem.Allocator, source: []const u8) error{ SizeMismatch, OutOfMemory }!*Self {
            if (@sizeOf(Arch) != source.len) {
                return error.SizeMismatch;
            }

            const net = try allocator.create(Self);
            net.* = .{
                .allocator = allocator,
                .data_blob = try allocator.dupe(u8, source),
                .layers = std.mem.bytesAsValue(Arch, source[0..@sizeOf(Arch)]).*,
            };
            return net;
        }

        /// Loads and parses a network file for this specific architecture.
        ///
        /// Asserts that the provided source is static with respect to the program.
        /// The allocator is set to the
        ///
        /// Can and should be called at compile time.
        pub fn static(comptime source: []const u8) Self {
            if (@sizeOf(Arch) != source.len) {
                @compileError("Architecture must be the same size as the source contents");
            }

            return .{
                .allocator = null,
                .data_blob = source,
                .layers = std.mem.bytesAsValue(Arch, source[0..@sizeOf(Arch)]).*,
            };
        }

        // Only frees if the allocator was passed to init. This is a noop otherwise.
        pub fn deinit(self: *Self) void {
            if (self.allocator) |allocator| {
                allocator.free(self.data_blob);
                allocator.destroy(self);
            }
        }

        pub fn bucket(board: *const water.Board) usize {
            return (board.occ().count() - 2) / 4;
        }

        /// Performs the given function on the input value.
        /// - .RELU almost always avoided due to potential overflow
        /// - .CReLU is not as common but can be auto-vectorized
        /// - .SCReLU produces the strongest network
        ///
        /// https://www.chessprogramming.org/NNUE
        pub fn activation(
            value: i16,
            comptime min: i16,
            comptime max: i16,
            comptime func: enum { relu, crelu, screlu },
        ) i16 {
            return switch (comptime func) {
                .relu => @max(value, 0),
                .crelu => std.math.clamp(value, min, max),
                .screlu => blk: {
                    const clamped = std.math.clamp(value, min, max);
                    break :blk clamped * clamped;
                },
            };
        }
    };
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;

test "Network creation with Avalanche's model" {
    const allocator = testing.allocator;

    const input_size: usize = 768;
    const hidden_size: usize = 512;
    const output_size: usize = 8;

    const NNUEWeights = struct {
        layer_1: [input_size * hidden_size]i16 align(64),
        layer_1_bias: [hidden_size]i16 align(64),
        layer_2: [output_size][hidden_size * 2]i16 align(64),
        layer_2_bias: [output_size]i16 align(64),
    };

    const mismatch = Network(NNUEWeights).init(allocator, "bingshan");
    try expectError(error.SizeMismatch, mismatch);

    var valid = try Network(NNUEWeights).init(allocator, nets.bingshan);
    defer valid.deinit();
}
