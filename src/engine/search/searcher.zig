const std = @import("std");
const water = @import("water");

const algorithm = @import("algorithm.zig");
const parameters = @import("../parameters.zig");

const evaluator_ = @import("../evaluation/evaluator.zig");
const tt = @import("../evaluation/tt.zig");

pub const NodeType = enum { root, pv, non_pv };

pub var quiet_lmr: [64][64]i32 = undefined;

pub fn reloadQLMR() void {
    for (1..64) |depth| {
        for (1..64) |moves| {
            const log_depth = @log(@as(f32, @floatFromInt(depth)));
            const log_moves = @log(@as(f32, @floatFromInt(moves)));
            const lmr = parameters.lmr_weight * log_depth * log_moves + parameters.lmr_bias;
            quiet_lmr[depth][moves] = @intFromFloat(@floor(lmr));
        }
    }
}

pub const Searcher = struct {
    allocator: std.mem.Allocator,

    writer: *std.Io.Writer,
    min_depth: usize = 1,
    iterative_deepening_depth: usize = 0,
    timer: std.time.Timer = undefined,
    alloted_time_ns: ?i128 = null,

    soft_max_nodes: ?u64 = null,
    max_nodes: ?u64 = null,

    governing_board: *water.Board,
    search_board: *water.Board,
    evaluator: evaluator_.Evaluator = .{},

    should_stop: std.atomic.Value(bool) = .init(true),
    silent_output: bool = false,

    nodes: u64 = 0,
    ply: usize = 0,
    seldepth: usize = 0,

    exclude_move: [parameters.max_ply]water.Move = @splat(water.Move.init()),
    nmp_min_ply: usize = 0,

    killers: [parameters.max_ply][2]water.Move = @splat(@splat(water.Move.init())),
    history: struct {
        heuristic: [2][64][64]i32 = std.mem.zeroes([2][64][64]i32),
        evaluations: [parameters.max_ply]i32 = @splat(0),
        moves: [parameters.max_ply]water.Move = @splat(water.Move.init()),
        moved_pieces: [parameters.max_ply]water.Piece = @splat(water.Piece.init()),
    } = .{},

    best_move: water.Move = .init(),
    pv: [parameters.max_ply][parameters.max_ply]water.Move = @splat(@splat(water.Move.init())),
    pv_size: [parameters.max_ply]usize = @splat(0),

    counter_moves: [2][64][64]water.Move = @splat(@splat(@splat(water.Move.init()))),
    continuation: *[12][64][64][64]i32,

    pub fn init(allocator: std.mem.Allocator, board: *water.Board, writer: *std.Io.Writer) anyerror!*Searcher {
        const searcher = try allocator.create(Searcher);
        searcher.* = .{
            .allocator = allocator,
            .writer = writer,
            .governing_board = board,
            .search_board = try board.clone(allocator),
            .continuation = try allocator.create([12][64][64][64]i32),
        };

        searcher.resetHeuristics(true);
        return searcher;
    }

    pub fn deinit(self: *Searcher) void {
        defer self.allocator.destroy(self);
        self.search_board.deinit();
        self.allocator.destroy(self.continuation);
    }

    /// Resets the searcher's heuristics. The history heuristic is halved if `total_reset` is false.
    pub fn resetHeuristics(self: *Searcher, comptime total_reset: bool) void {
        self.nmp_min_ply = 0;

        // Only reset the history heuristic fully if requested
        if (total_reset) {
            self.history.heuristic = std.mem.zeroes([2][64][64]i32);
        } else {
            for (0..64) |j| {
                for (0..64) |k| {
                    for (0..2) |i| {
                        self.history.heuristic[i][j][k] = @divTrunc(
                            self.history.heuristic[i][j][k],
                            2,
                        );
                    }
                }
            }
        }

        self.history.evaluations = @splat(0);
        self.history.moves = @splat(water.Move.init());
        self.history.moved_pieces = @splat(water.Piece.init());

        self.killers = @splat(@splat(water.Move.init()));
        self.exclude_move = @splat(water.Move.init());
        self.continuation.* = @splat(@splat(@splat(@splat(0))));
        self.counter_moves = @splat(@splat(@splat(water.Move.init())));

        self.pv = @splat(@splat(water.Move.init()));
        self.pv_size = @splat(0);
    }

    pub fn search(self: *Searcher, alloted_time_ns: ?i128, max_depth: ?usize) anyerror!void {
        self.should_stop.store(false, .release);
        self.resetHeuristics(false);
        self.evaluator.refresh(self.search_board, .full);

        self.nodes = 0;
        self.best_move = .init();
        self.timer = std.time.Timer.start() catch unreachable;
        self.alloted_time_ns = alloted_time_ns;
        self.iterative_deepening_depth = 0;

        var prev_score = -evaluator_.mate_score;
        var score = -evaluator_.mate_score;
        var bm = water.Move.init();
        var stability: usize = 0;

        var tdepth: usize = 1;
        var bound = if (max_depth) |md| md else parameters.max_ply - 2;

        outer: while (tdepth <= bound) {
            self.ply = 0;
            self.seldepth = 0;

            var alpha = -evaluator_.mate_score;
            var beta = evaluator_.mate_score;
            var delta = evaluator_.mate_score;

            var depth = tdepth;

            // Aspiration window at deeper depths
            if (depth >= 6) {
                alpha = @max(score - parameters.aspiration_window, -evaluator_.mate_score);
                beta = @min(score + parameters.aspiration_window, evaluator_.mate_score);
                delta = parameters.aspiration_window;
            }

            // Search until the score is between beta and alpha
            while (true) {
                self.iterative_deepening_depth = @max(depth, self.iterative_deepening_depth);
                self.nmp_min_ply = 0;

                const negamax = algorithm.negamax(
                    self,
                    depth,
                    alpha,
                    beta,
                    .{
                        .is_null = false,
                        .cutnode = false,
                        .node = .root,
                    },
                );

                if (self.shouldStop()) {
                    break :outer;
                }

                score = negamax;

                if (score <= alpha) {
                    beta = @divTrunc(alpha + beta, 2);
                    alpha = @max(alpha - delta, -evaluator_.mate_score);
                } else if (score >= beta) {
                    beta = @min(beta + delta, evaluator_.mate_score);
                    if (depth > 1 and (tdepth < 4 or depth > tdepth - 4)) {
                        depth -= 1;
                    }
                } else break;

                // Narrow the window on a failed probe
                delta = @max(1, @min(delta + @divTrunc(delta, 4), evaluator_.mate_score));
            }

            // We lose stability if a best move was not found by the end of the previous probing iteration
            if (self.best_move.order(bm, .mv) != .eq) {
                stability = 0;
            } else {
                stability += 1;
            }

            bm = self.best_move;
            const total_nodes: usize = self.nodes;

            if (!self.silent_output) {
                const elapsed_ms = @max(1, self.timer.read() / std.time.ns_per_ms);
                const elapsed_s = @max(1, elapsed_ms / std.time.ms_per_s);
                try self.writer.print("info depth {d} seldepth {d} nodes {d} time {d} nps {d} score ", .{
                    tdepth,
                    self.seldepth,
                    total_nodes,
                    elapsed_ms,
                    @divTrunc(@as(u64, @intCast(total_nodes)), elapsed_s),
                });

                // Print the mate score if close enough
                if (@abs(score) >= (evaluator_.mate_score - evaluator_.max_mate)) {
                    const mate_in: i32 = @divTrunc(evaluator_.mate_score - @as(i32, @intCast(@abs(score))), 2) + 1;
                    const perspective: i32 = if (score > 0) 1 else -1;
                    try self.writer.print("mate {} pv", .{perspective * mate_in});

                    if (bound == parameters.max_ply - 1) {
                        bound = depth + 2;
                    }
                } else {
                    try self.writer.print("cp {} pv", .{score});
                }

                // Print the pv sequence or the best move depending on the state
                if (self.pv_size[0] > 0) {
                    for (0..self.pv_size[0]) |i| {
                        try self.writer.writeByte(' ');
                        try water.uci.printMoveUci(
                            self.pv[0][i],
                            self.governing_board.fischer_random,
                            self.writer,
                        );
                    }
                } else {
                    try self.writer.writeByte(' ');
                    try water.uci.printMoveUci(
                        bm,
                        self.governing_board.fischer_random,
                        self.writer,
                    );
                }

                try self.writer.writeByte('\n');
                try self.writer.flush();
            }

            // Compute a cutoff factor for time management
            var factor: f32 = @max(0.5, 1.1 - 0.03 * @as(f32, @floatFromInt(stability)));
            if (score - prev_score > parameters.aspiration_window) {
                factor *= 1.1;
            }

            prev_score = score;
            if (self.longEnough(factor)) break;

            tdepth += 1;
        }

        self.best_move = bm;
        tt.global_tt.incAge();
        self.should_stop.store(true, .release);
        self.alloted_time_ns = null;

        // The uci spec has a specific requirement about null moves, a couple heap allocations here is fine
        const bm_str = try water.uci.moveToUci(
            self.allocator,
            self.best_move,
            self.governing_board.fischer_random,
        );
        defer self.allocator.free(bm_str);

        try self.writer.print("bestmove {s}\n", .{
            if (std.mem.eql(u8, bm_str, "a1a1")) "0000" else bm_str,
        });

        try self.writer.flush();
    }

    pub fn shouldStop(self: *const Searcher) bool {
        const exceeded_min_depth = self.iterative_deepening_depth > self.min_depth;
        const exceeded_max_nodes = if (self.max_nodes) |max| self.nodes >= max else false;
        const notified = self.should_stop.load(.acquire);

        return notified or (exceeded_min_depth and exceeded_max_nodes);
    }

    fn longEnough(self: *Searcher, factor: f32) bool {
        const exceeded_min = self.iterative_deepening_depth > self.min_depth;
        const exceeded_soft = if (self.soft_max_nodes) |soft| self.nodes >= soft else false;
        const timed_out = if (self.alloted_time_ns) |max_ns| blk: {
            break :blk self.timer.read() >= @as(u64, @intFromFloat(factor * @as(f64, @floatFromInt(@as(i64, @truncate(max_ns))))));
        } else false;
        const notified = self.should_stop.load(.acquire);

        return notified or (exceeded_min and (exceeded_soft or timed_out));
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "Search initialization" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    var buffer: [1024]u8 = undefined;
    var discarding = std.Io.Writer.Discarding.init(&buffer);
    const writer = &discarding.writer;

    const searcher = try Searcher.init(allocator, board, writer);
    defer searcher.deinit();
}

test "Searching" {
    // Costly test, skip me!
    if (true) return error.SkipZigTest;

    // Housekeeping
    const allocator = testing.allocator;
    var tt_arena = std.heap.ArenaAllocator.init(allocator);
    defer tt_arena.deinit();
    const tt_allocator = tt_arena.allocator();

    reloadQLMR();
    tt.global_tt = try tt.TranspositionTable.init(tt_allocator, null);

    // Actual testing
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    var buffer: [1024]u8 = undefined;
    var discarding = std.Io.Writer.Discarding.init(&buffer);
    const writer = &discarding.writer;

    var searcher = try Searcher.init(allocator, board, writer);
    defer searcher.deinit();

    // Problematic position at depth 7
    const trouble = "RB6/1P1pr1p1/P1b5/1P1n1PKN/4pR2/p1b1P1pk/2P4P/2r5 w - - 0 1";
    try expect(try searcher.governing_board.setFen(trouble, true));
    try expect(try searcher.search_board.setFen(trouble, true));

    // Spawn the search thread with a large stack size to prevent overflow
    const worker = try std.Thread.spawn(
        .{ .stack_size = 64 * 1024 * 1024 },
        Searcher.search,
        .{ searcher, null, 10 },
    );
    worker.join();
}
