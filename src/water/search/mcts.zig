const std = @import("std");
const water = @import("water");

const orderer = @import("../evaluation/orderer.zig");

pub const MCTSResult = enum(i2) {
    loss = -1,
    draw = 0,
    win = 1,

    /// Converts the Result into its float score.
    pub fn score(self: *const MCTSResult) f64 {
        return switch (self.*) {
            .loss => 0.0,
            .draw => 0.5,
            .win => 1.0,
        };
    }
};

pub fn interpretGameResult(result: water.arbiter.Result, stm: water.Color) MCTSResult {
    switch (result.result) {
        .win => {
            if (result.winner == stm) {
                return .win;
            } else if (result.winner == stm.opposite()) {
                return .loss;
            } else unreachable;
        },
        .draw => return .draw,
    }
}

pub const MCTSNode = struct {
    parent: ?*MCTSNode,
    antecedent: struct {
        move: water.Move,
        policy: f32,
    },

    children: std.ArrayList(*MCTSNode),
    untried_moves: water.movegen.Movelist,

    value_sum: f64,
    visits: u64,

    terminal: bool,

    /// Determine the best child using the Upper Confidence Bound (UCT) algorithm.
    ///
    /// Performs the selection phase of MCTS.
    /// 
    /// https://www.chessprogramming.org/UCT
    pub fn bestChildUCT(self: *const MCTSNode) *MCTSNode {
        const c: f64 = comptime @sqrt(2.0);
        const ln_parent_visits = @log(@as(f64, @floatFromInt(self.visits)));

        var best_score: f64 = -1.0;
        var best_child: ?*MCTSNode = null;

        for (self.children.items) |child| {
            const child_visits = @as(f64, @floatFromInt(child.visits));
            const exploitation = child.value_sum / child_visits;
            const exploration = c * @sqrt(ln_parent_visits / child_visits);

            // Use 1.0 - exploitation as value_sum is from child's perspective
            const uct_score = (1.0 - exploitation) + exploration;
            if (uct_score > best_score) {
                best_score = uct_score;
                best_child = child;
            }
        }

        return best_child orelse unreachable;
    }

    /// Expands a node, adding child with the highest ordered move in the nodes untried move.
    ///
    /// Performs the expansion phase of MCTS.
    ///
    /// Does not perform ordering on the parent's move, assuming that this has been performed already.
    pub fn expand(self: *MCTSNode, allocator: std.mem.Allocator, parent_board: *const water.Board) !*MCTSNode {
        std.debug.assert(self.untried_moves.size > 0);
        const move_to_expand = self.untried_moves.moves[0];

        var child_board = try parent_board.clone(allocator);
        defer child_board.deinit();

        child_board.makeMove(move_to_expand, .{});
        var movelist = water.movegen.Movelist{};
        water.movegen.legalmoves(child_board, &movelist, .{});
        orderer.orderMoves(child_board, &movelist, null);

        const child_node = try allocator.create(MCTSNode);
        child_node.* = .{
            .parent = self,
            .antecedent = .{
                .move = move_to_expand,
                .policy = 1.0,
            },
            .children = .empty,
            .untried_moves = movelist,
            .value_sum = 0.0,
            .visits = 0,
            .terminal = water.arbiter.gameOver(child_board, &movelist) != null,
        };

        try self.children.append(allocator, child_node);
        return child_node;
    }

    /// Returns the result from the perspective of the player to move in the rollout_board state.
    ///
    /// Performs the simulation phase of MCTS.
    /// 
    /// Performs the rollout phase of MCTS.
    pub fn rollout(self: *const MCTSNode, allocator: std.mem.Allocator, rollout_board: *const water.Board) !MCTSResult {
        // Pregenerate a movelist for efficient game over detection
        var movelist = water.movegen.Movelist{};
        water.movegen.legalmoves(rollout_board, &movelist, .{});

        // Terminal nodes are assumed to have no legal moves left, so a result is guaranteed
        if (self.terminal) {
            const result = water.arbiter.gameOver(rollout_board, &movelist);
            if (result) |res| {
                return interpretGameResult(res, rollout_board.side_to_move);
            } else unreachable;
        }

        var tmp_board = try rollout_board.clone(allocator);
        defer tmp_board.deinit();

        var prng = std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
        const random = prng.random();
        
        // Continue to search randomly until a result is encountered, cache along the way for efficiency
        var last_result = water.arbiter.gameOver(rollout_board, &movelist);
        while (last_result == null) {
            const random_idx = random.uintAtMost(usize, @intCast(movelist.size - 1));
            const random_move = movelist.moves[random_idx];
            tmp_board.makeMove(random_move, .{});

            movelist.reset();
            water.movegen.legalmoves(tmp_board, &movelist, .{});
            last_result = water.arbiter.gameOver(tmp_board, &movelist);
        }

        // If the current player to move in rollout_board is NOT the same as the winner, it's a win.
        const result = last_result orelse unreachable;
        const interpreted = interpretGameResult(result, tmp_board.side_to_move);
        if (rollout_board.side_to_move != tmp_board.side_to_move and interpreted == .win) {
            return .win;
        } else if (interpreted == .draw) {
            return .draw;
        } else return .loss;
    }

    /// Propagates the node up to the top to the tree.
    /// 
    /// Performs the backpropagation phase of MCTS.
    pub fn backpropagate(self: *MCTSNode, result: MCTSResult) void {
        var current_result = result.score();
        var node: ?*MCTSNode = self;
        while (node) |n| {
            n.visits += 1;
            n.value_sum += current_result;

            // Flip the perspective to account for switch to parent
            current_result = 1.0 - current_result;
            node = n.parent;
        }
    }
};

pub const MCTSTree = struct {
    allocator: std.mem.Allocator,
    root: *MCTSNode,

    /// Creates an MCTSTree, assuming that all nodes are managed by an arena.
    pub fn init(allocator: std.mem.Allocator, root_board: *const water.Board) !*MCTSTree {
        const tree = try allocator.create(MCTSTree);
        const root = try allocator.create(MCTSNode);

        var movelist = water.movegen.Movelist{};
        water.movegen.legalmoves(root_board, &movelist, .{});
        orderer.orderMoves(root_board, &movelist, null);

        root.* = .{
            .parent = null,
            .antecedent = .{
                .move = water.Move.init(),
                .policy = 1.0,
            },
            .children = .empty,
            .untried_moves = movelist,
            .value_sum = 0.0,
            .visits = 0,
            .terminal = water.arbiter.gameOver(root_board, &movelist) != null,
        };

        tree.* = .{
            .allocator = allocator,
            .root = root,
        };
        return tree;
    }

    /// Destroys the pointer to self.
    ///
    /// All nodes are assumed to be arena allocated and are not freed here.
    pub fn deinit(self: *MCTSTree) void {
        defer self.allocator.destroy(self);
    }

    /// Selects the best move from the tree based on the most visited positions.
    pub fn probeBest(self: *const MCTSTree) water.Move {
        var max_visits: u64 = 0;
        var best_move: ?water.Move = null;

        for (self.root.children.items) |child| {
            if (child.visits > max_visits) {
                max_visits = child.visits;
                best_move = child.antecedent.move;
            }
        }

        return best_move orelse water.Move.init();
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "MCTSResult handling" {
    try expectEqual(0.0, MCTSResult.loss.score());
    try expectEqual(0.5, MCTSResult.draw.score());
    try expectEqual(1.0, MCTSResult.win.score());
}

test "Tree creation and deletion" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var tree = try MCTSTree.init(arena_allocator, board);
    defer tree.deinit();
}
