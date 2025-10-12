const std = @import("std");
const water = @import("water");

const parameters = @import("parameters.zig");

const tt = @import("evaluation/tt.zig");
const evaluator = @import("evaluation/evaluator.zig");

const searcher = @import("search/searcher.zig");

const Engine = water.engine.Engine(searcher.Searcher);

pub const NewGameCommand = struct {
    pub const command_name: []const u8 = "ucinewgame";

    pub fn deserialize(
        allocator: std.mem.Allocator,
        tokens: *std.mem.TokenIterator(u8, .any),
    ) anyerror!NewGameCommand {
        _ = allocator;
        _ = tokens;
        return .{};
    }

    pub fn dispatch(
        self: *const NewGameCommand,
        engine: *Engine,
    ) anyerror!void {
        _ = self;

        engine.notifyStopSearch();
        try tt.global_tt.reset(null);
        _ = try engine.searcher.governing_board.setFen(water.board.starting_fen, true);
        _ = try engine.searcher.search_board.setFen(water.board.starting_fen, true);
    }
};

pub const UciCommand = struct {
    pub const command_name: []const u8 = "uci";

    pub fn deserialize(
        allocator: std.mem.Allocator,
        tokens: *std.mem.TokenIterator(u8, .any),
    ) anyerror!UciCommand {
        _ = allocator;
        _ = tokens;
        return .{};
    }

    pub fn dispatch(
        self: *const UciCommand,
        engine: *Engine,
    ) anyerror!void {
        _ = self;
        try engine.writer.writeAll(
            \\id name Water 0.0.1
            \\id author the Water Engine developers (see AUTHORS file)
            \\
            \\
        );

        try parameters.writeOut(engine.writer);
        try engine.writer.print("uciok\n", .{});
        try engine.writer.flush();
    }
};

pub const GoCommand = struct {
    pub const command_name: []const u8 = "go";

    movetime: ?u32 = null,

    wtime: ?u32 = null,
    btime: ?u32 = null,
    winc: ?u32 = null,
    binc: ?u32 = null,

    infinite: bool = false,
    depth: ?usize = null,
    nodes: ?usize = null,
    movestogo: ?usize = null,

    perft: ?usize = null,

    pub fn deserialize(
        allocator: std.mem.Allocator,
        tokens: *std.mem.TokenIterator(u8, .any),
    ) anyerror!GoCommand {
        _ = allocator;
        return water.dispatcher.deserializeFields(
            GoCommand,
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
            return @intCast(1_000_000 * @as(i128, @intCast(mt_ms)));
        }

        // If we made it here then handle time fully
        const wtime_ns: i128 = @intCast(1_000_000 * @as(i128, @intCast(self.wtime orelse 0)));
        const btime_ns: i128 = @intCast(1_000_000 * @as(i128, @intCast(self.btime orelse 0)));
        const winc_ns: i128 = @intCast(1_000_000 * @as(i128, @intCast(self.winc orelse 0)));
        const binc_ns: i128 = @intCast(1_000_000 * @as(i128, @intCast(self.binc orelse 0)));

        // With zero tc it doesn't make sense to calculate, and movestogo means nothing
        if (std.mem.allEqual(i128, &.{ wtime_ns, btime_ns, winc_ns, binc_ns }, 0)) {
            return null;
        }

        var movetime: i128 = 0;
        const overhead = parameters.move_overhead;

        const my_time_ns = if (board.side_to_move == .white) wtime_ns else btime_ns;
        const my_inc_ns = if (board.side_to_move == .white) winc_ns else binc_ns;

        // Not enough time to even cover overhead, move nearly instantly.
        if (my_time_ns <= overhead) {
            return 1_000_000; // 1ms
        }

        const is_panic_mode = my_time_ns < 15_000_000_000;

        if (self.movestogo) |mtg| {
            const base_time = @divTrunc(my_time_ns - overhead, mtg);

            // If we are in a time scramble, don't use the full increment.
            if (is_panic_mode) {
                movetime = base_time + @divTrunc(my_inc_ns, 2);
            } else {
                movetime = base_time + my_inc_ns;
            }
        } else {
            var divisor: i128 = 25;

            // In panic mode, use a much larger divisor to conserve time
            if (is_panic_mode) {
                divisor = 50;
            }
            movetime = my_inc_ns + @divTrunc(my_time_ns - overhead, divisor);
        }

        movetime = @min(movetime, @divTrunc((my_time_ns - overhead) * 3, 4));
        return movetime;
    }

    pub fn dispatch(
        self: *const GoCommand,
        engine: *Engine,
    ) anyerror!void {
        // Perft takes priority over all other options
        if (self.perft) |depth| {
            try engine.searcher.governing_board.divide(depth, engine.writer);
            return;
        }

        const think_time_ns = self.chooseThinkTimeNs(engine.searcher.governing_board);
        engine.searcher.max_nodes = self.nodes;
        engine.searcher.soft_max_nodes = self.nodes;
        engine.search(think_time_ns, .{ think_time_ns, self.depth }, .{});
    }
};

var notify_search_silent = false;
var notify_search_loud = false;

pub const OptCommand = struct {
    pub const command_name: []const u8 = "setoption";

    pub fn deserialize(
        allocator: std.mem.Allocator,
        tokens: *std.mem.TokenIterator(u8, .any),
    ) anyerror!OptCommand {
        parameters.setoption(allocator, tokens) catch |err| switch (err) {
            error.SilentSearchOutput => notify_search_silent = true,
            error.LoudSearchOutput => notify_search_loud = true,
            else => {},
        };

        return .{};
    }

    pub fn dispatch(
        self: *const OptCommand,
        engine: *Engine,
    ) anyerror!void {
        _ = self;

        // For safety reasons, only update the silent output when the search thread is asleep
        if (engine.searcher.should_stop.load(.acquire)) {
            if (notify_search_silent) {
                engine.searcher.silent_output = true;
            } else if (notify_search_loud) {
                engine.searcher.silent_output = false;
            }
        }

        // Local global state should be reset without fail so there is no fallthrough
        notify_search_silent = false;
        notify_search_loud = false;
    }
};

pub const DebugCommand = struct {
    pub const command_name: []const u8 = "debug";

    on: bool = false,
    off: bool = false,

    pub fn deserialize(
        allocator: std.mem.Allocator,
        tokens: *std.mem.TokenIterator(u8, .any),
    ) anyerror!DebugCommand {
        _ = allocator;
        return try water.dispatcher.deserializeFields(
            DebugCommand,
            tokens,
            &.{ "on", "off" },
            null,
        );
    }

    pub fn dispatch(
        self: *const DebugCommand,
        engine: *Engine,
    ) anyerror!void {
        // For safety reasons, only update the silent output when the search thread is asleep
        if (engine.searcher.should_stop.load(.acquire)) {
            if (self.on) {
                engine.searcher.silent_output = false;
            } else if (self.off) {
                engine.searcher.silent_output = true;
            }
        }
    }
};

pub const EvalCommand = struct {
    pub const command_name: []const u8 = "eval";

    pub fn deserialize(
        allocator: std.mem.Allocator,
        tokens: *std.mem.TokenIterator(u8, .any),
    ) anyerror!EvalCommand {
        _ = allocator;
        _ = tokens;
        return .{};
    }

    pub fn dispatch(
        self: *const EvalCommand,
        engine: *Engine,
    ) anyerror!void {
        _ = self;
        var eval = evaluator.Evaluator{};
        eval.refresh(engine.searcher.governing_board, .full);
        try engine.writer.print("info string eval {d}\n", .{
            eval.evaluate(engine.searcher.governing_board),
        });
        try engine.writer.flush();
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
        try expectEqual(1_399_800, time_ns);
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

    // Thinktime 'go wtime 61000 btime 61000 winc 1000 binc 1000 movestogo 40'
    {
        const input = "go wtime 10000 btime 61000 winc 1000 binc 1000 movestogo 40";
        var tokens = std.mem.tokenizeAny(u8, input, " ");
        const go = try GoCommand.deserialize(allocator, &tokens);

        const time_ns = go.chooseThinkTimeNs(board);
        try expectEqual(749_999_750, time_ns);
    }
}
