const std = @import("std");
const builtin = @import("builtin");

const board_ = @import("../board/board.zig");
const Board = board_.Board;

/// Creates a Network type tailored to the provided network architecture.
///
/// Arch must be a struct type with a well defined memory layout (i.e. extern).
/// Non-little-endian systems must roll their own Network.
///
/// An example Arch type might look like:
/// ```
/// pub const NNUEWeights = extern struct {
///     layer_1: [INPUT_SIZE * HIDDEN_SIZE]i16 align(64),
///     layer_1_bias: [HIDDEN_SIZE]i16 align(64),
///     layer_2: [OUTPUT_SIZE][HIDDEN_SIZE * 2]i16 align(64),
///     layer_2_bias: [OUTPUT_SIZE]i16 align(64),
/// };
/// ```
///
/// The passed Arch must have @sizeOf equal to the Network to encode.
///
/// Also exposes an activation function.
pub fn Network(comptime Arch: type) type {
    if (builtin.target.cpu.arch.endian() != .little) {
        @compileError("The target CPU must be little-endian. Other systems cannot use this Factory");
    }

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
        /// The provided source, if allocated externally, can be freed safely after calling this function.
        ///
        /// It is recommended to use this over static when opting for a dynamic Network that can change at runtime.
        pub fn init(allocator: std.mem.Allocator, source: []const u8) error{ SizeMismatch, OutOfMemory }!*Self {
            if (@sizeOf(Arch) != source.len) {
                return error.SizeMismatch;
            }

            const net = try allocator.create(Self);
            const blob = try allocator.dupe(u8, source);
            net.* = .{
                .allocator = allocator,
                .data_blob = blob,
                .layers = std.mem.bytesAsValue(Arch, blob[0..@sizeOf(Arch)]).*,
            };
            return net;
        }

        /// Loads and parses a network file for this specific architecture.
        ///
        /// Asserts that the provided source is static with respect to the program.
        /// The allocator is set to null when this is used as an initializer, and the source is not stored.
        ///
        /// Can and should be called at compile time.
        pub fn static(comptime source: []const u8) Self {
            if (@sizeOf(Arch) != source.len) {
                @compileError("Architecture must be the same size as the source contents");
            }

            return .{
                .allocator = null,
                .data_blob = "",
                .layers = std.mem.bytesAsValue(Arch, source[0..@sizeOf(Arch)]).*,
            };
        }

        // Only frees if the allocator was passed to init.
        ///
        /// This is a noop for Networks created statically.
        pub fn deinit(self: *Self) void {
            if (self.allocator) |allocator| {
                allocator.free(self.data_blob);
                allocator.destroy(self);
            }
        }

        /// Performs the given function on the input value.
        /// - RELU almost always avoided due to potential overflow
        /// - CReLU is not as common but can be auto-vectorized
        /// - SCReLU produces the strongest network
        ///
        /// https://www.chessprogramming.org/NNUE
        pub fn activation(
            value: i16,
            comptime min: i16,
            comptime max: i16,
            comptime func: enum { relu, crelu, screlu },
        ) i32 {
            return switch (comptime func) {
                .relu => @max(value, 0),
                .crelu => std.math.clamp(value, min, max),
                .screlu => blk: {
                    const clamped = @as(i32, std.math.clamp(value, min, max));
                    break :blk clamped * clamped;
                },
            };
        }
    };
}
