const std = @import("std");
const water = @import("water");

pub fn main() !void {
    const bb = water.Bitboard{.bits = water.File.fh.mask()};
    std.debug.print("{s}", .{bb.asBoardStr()});
}
