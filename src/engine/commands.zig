const std = @import("std");
const water = @import("water");

const searcher = @import("search/searcher.zig");

const Engine = water.engine.Engine(searcher.Searcher);

pub const GoCommand = struct {
    pub const command_name: []const u8 = "go";

    movetime: ?u32 = null,

    wtime: ?u32 = null,
    btime: ?u32 = null,
    winc: ?u32 = null,
    binc: ?u32 = null,

    infinite: bool = false,
    depth: ?usize = null,

    pub fn deserialize(
        allocator: std.mem.Allocator,
        tokens: *std.mem.TokenIterator(u8, .any),
    ) anyerror!GoCommand {
        return water.dispatcher.deserializeFields(
            GoCommand,
            allocator,
            tokens,
            &.{"infinite"},
            null,
        ) catch |err| switch (err) {
            error.NoKVPairs => return .{
                .infinite = true,
            },
            else => return err,
        };
    }

    pub fn chooseThinkTimeNs(self: *const GoCommand, board: *const water.Board) ?i128 {
        if (self.infinite or self.depth != null) {
            return null;
        } else if (self.movetime) |mt_ms| {
            return @intCast(1_000_000 * mt_ms);
        }

        // If we made it here then handle time fully
        const wtime_ns: i128 = @intCast(1_000_000 * (self.wtime orelse 0));
        const btime_ns: i128 = @intCast(1_000_000 * (self.btime orelse 0));
        const winc_ns: i128 = @intCast(1_000_000 * (self.winc orelse 0));
        const binc_ns: i128 = @intCast(1_000_000 * (self.binc orelse 0));

        if (std.mem.allEqual(i128, &.{ wtime_ns, btime_ns, winc_ns, binc_ns }, 0)) {
            return null;
        }

        const time_us = if (board.side_to_move == .white) wtime_ns else btime_ns;
        const inc_us = if (board.side_to_move == .white) winc_ns else binc_ns;

        var think_time_ns = @divTrunc(time_us, 40);
        if (time_us > inc_us * 2) {
            think_time_ns += @intFromFloat(@as(f128, @floatFromInt(inc_us)) * 0.8);
        }

        const min_time_ns = @min(50, @as(i128, @intFromFloat(@as(f128, @floatFromInt(inc_us)) * 0.25)));
        return @max(min_time_ns, think_time_ns);
    }

    pub fn dispatch(
        self: *const GoCommand,
        engine: *Engine,
    ) anyerror!void {
        const think_time_ns = self.chooseThinkTimeNs(engine.searcher.governing_board);
        engine.search(think_time_ns, .{ think_time_ns, self.depth }, .{});
    }
};

pub const OptCommand = struct {
    pub const command_name: []const u8 = "setoption";

    pub fn deserialize(
        allocator: std.mem.Allocator,
        tokens: *std.mem.TokenIterator(u8, .any),
    ) anyerror!OptCommand {
        _ = allocator;
        _ = tokens;
        return .{};
    }

    pub fn dispatch(
        self: *const OptCommand,
        engine: *Engine,
    ) anyerror!void {
        _ = self;
        _ = engine;
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "Go think time finding" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    // Normal timed input
    {
        const go = GoCommand{
            .wtime = 20,
            .btime = 20,
            .winc = 1,
            .binc = 1,
        };

        const time_ns = go.chooseThinkTimeNs(board);
        try expect(time_ns != null);
        try expectEqual(1_300_000, time_ns);
    }

    // Normal timed input with movetime override
    {
        const go = GoCommand{
            .movetime = 10,
            .wtime = 20,
            .btime = 20,
            .winc = 1,
            .binc = 1,
        };

        const time_ns = go.chooseThinkTimeNs(board);
        try expect(time_ns != null);
        try expectEqual(10_000_000, time_ns);
    }

    // Normal + movetime timed input with infinite override
    {
        const go = GoCommand{
            .movetime = 10,
            .wtime = 20,
            .btime = 20,
            .winc = 1,
            .binc = 1,
            .infinite = true,
        };

        const time_ns = go.chooseThinkTimeNs(board);
        try expect(time_ns == null);
    }

    // Input with all zeros
    {
        const go = GoCommand{
            .wtime = 0,
            .btime = 0,
            .winc = 0,
            .binc = 0,
        };

        const time_ns = go.chooseThinkTimeNs(board);
        try expect(time_ns == null);
    }
}
