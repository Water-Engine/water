const std = @import("std");
const water = @import("water");

const max_search_depth = 200;

pub const Search = struct {
    allocator: std.mem.Allocator,
    governing_board: *water.Board,

    writer: *std.Io.Writer,
    search_board: *water.Board,
    should_stop: std.atomic.Value(bool) = .init(false),

    depth: i32 = 0,
    last_score: i32 = 0,

    root_best: water.Move = .init(),
    search_best: water.Move = .init(),

    pub fn init(allocator: std.mem.Allocator, board: *water.Board, writer: *std.Io.Writer) anyerror!*Search {
        const searcher = try allocator.create(Search);
        searcher.* = .{
            .allocator = allocator,
            .writer = writer,
            .governing_board = board,
            .search_board = try board.clone(allocator),
        };

        return searcher;
    }

    pub fn deinit(self: *Search) void {
        defer self.allocator.destroy(self);
        self.search_board.deinit();
    }

    pub fn search(self: *Search) anyerror!void {
        self.should_stop.store(false, .release);

        self.depth = 1;
        while (true) {
            // Aspiration window
            if (@abs(self.last_score - negamax(
                self.last_score - 20,
                self.last_score + 20,
                self.depth,
            ) catch break) >= 20) {
                _ = negamax(-32_000, 32_000, self.depth) catch break;
            }
            self.root_best = self.search_best;

            // Check if we should stop
            if (self.should_stop.load(.acquire) or self.depth > max_search_depth) {
                break;
            } else self.depth += 1;
        }

        const bm = try water.uci.moveToUci(
            self.allocator,
            self.root_best,
            self.governing_board.fischer_random,
        );
        defer self.allocator.free(bm);

        try self.writer.print("bestmove {s}\n", .{bm});
        try self.writer.flush();
    }

    fn negamax(self: *Search, alpha: i32, beta: i32, depth: i32) !i32 {
        if (self.should_stop.load(.acquire) and self.depth > 1) {
            return error.OutOfTime;
        }

        _ = alpha;
        _ = beta;
        _ = depth;

        unreachable;
    }
};
