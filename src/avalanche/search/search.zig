const std = @import("std");
const water = @import("water");

const max_search_ply = 128;

pub const Search = struct {
    allocator: std.mem.Allocator,
    governing_board: *water.Board,

    writer: *std.Io.Writer,
    search_board: *water.Board,
    should_stop: std.atomic.Value(bool) = .init(false),

    ply: usize = 0,
    last_score: i32 = 0,

    root_best: water.Move = .init(),
    search_best: water.Move = .init(),

    history: [2][64][64]i32 = std.mem.zeroes([2][64][64]i32),
    killers: [max_search_ply][2]water.Move = @splat(@splat(water.Move.init())),

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

    pub fn resetHeuristics(self: *Search) void {
        self.history = std.mem.zeroes([2][64][64]i32);
        self.killers = @splat(@splat(water.Move.init()));
    }

    pub fn search(self: *Search) anyerror!void {
        self.should_stop.store(false, .release);

        self.iteration = 0;
        self.ply = 0;
        while (true) {
            try self.writer.print("Im thinking it", .{});
            if (self.should_stop.load(.acquire)) {
                break;
            }
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
};
