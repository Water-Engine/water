const std = @import("std");
const water = @import("water");

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
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

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
