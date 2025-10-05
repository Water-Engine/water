const std = @import("std");
const water = @import("water");

const mcts = @import("mcts.zig");

const max_search_ply = 128;

pub const Search = struct {
    allocator: std.mem.Allocator,
    governing_board: *water.Board,

    writer: *std.Io.Writer,
    search_board: *water.Board,
    should_stop: std.atomic.Value(bool) = .init(false),

    iteration: i32 = 0,
    ply: usize = 0,
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

        self.ply = 0;

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var search_tree = try mcts.MCTSTree.init(allocator, self.search_board);
        while (true) {
            const should_stop = self.should_stop.load(.acquire);
            var traversal_board = try self.search_board.clone(allocator);
            defer traversal_board.deinit();

            // 1. SELECTION: Traverse the tree and update the board state
            var node = search_tree.root;
            while (node.untried_moves.size == 0 and node.children.items.len > 0) {
                node = node.bestChildUCT();
                traversal_board.makeMove(node.antecedent.move, .{});
            }

            // 2. EXPANSION: Expand from the selected node if it's not terminal
            if (!node.terminal) {
                const expanded_node = try node.expand(allocator, traversal_board);
                node = expanded_node;
                traversal_board.makeMove(node.antecedent.move, .{});
            }

            // 3. SIMULATION (ROLLOUT): Run from the correct board state
            const result = try node.rollout(allocator, traversal_board);

            // 4. BACKPROPAGATION
            node.backpropagate(result);

            if (should_stop) {
                break;
            }
        }

        const bm = try water.uci.moveToUci(
            self.allocator,
            search_tree.probeBest(),
            self.governing_board.fischer_random,
        );
        defer self.allocator.free(bm);

        try self.writer.print("bestmove {s}\n", .{bm});
        try self.writer.flush();
    }
};
