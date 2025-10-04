const std = @import("std");

const engine_ = @import("engine.zig");

const board_ = @import("../board/board.zig");

pub const TestSearcher = struct {
    allocator: std.mem.Allocator,

    governing_board: *board_.Board,
    search_board: *board_.Board,
    should_stop: std.atomic.Value(bool),

    pub fn init(a: std.mem.Allocator, b: *board_.Board) anyerror!*TestSearcher {
        const searcher = try a.create(TestSearcher);
        searcher.* = .{
            .allocator = a,
            .governing_board = b,
            .search_board = try b.clone(a),
            .should_stop = std.atomic.Value(bool).init(true),
        };

        return searcher;
    }

    pub fn deinit(self: *TestSearcher) void {
        defer self.allocator.destroy(self);
        self.search_board.deinit();
    }

    pub fn search(self: *TestSearcher) anyerror!void {
        _ = self;
    }
};

pub fn TestCommand(comptime Searcher: type) type {
    return struct {
        const Self = @This();
        pub const command_name: []const u8 = "go";

        fsize: f64 = 0.0,
        tsize: ?f16 = 0.0,

        btime: ?u64 = null,
        wtime: ?u64 = null,
        binc: ?u64 = null,
        winc: ?u64 = null,
        infinite: bool = false,

        msize: i42 = -1,

        name: []const u8 = "test",
        crunched: bool = false,

        startpos: ?bool = null,
        moves: ?[]const u8 = null,

        pub fn deserialize(
            allocator: std.mem.Allocator,
            tokens: *std.mem.TokenIterator(u8, .any),
        ) anyerror!Self {
            _ = allocator;
            _ = tokens;
            return .{};
        }

        pub fn dispatch(
            self: *const Self,
            engine: *engine_.Engine(Searcher),
        ) anyerror!void {
            _ = self;
            _ = engine;
        }
    };
}

pub fn CommandOne(comptime Searcher: type) type {
    return struct {
        const Self = @This();
        pub const command_name: []const u8 = "one";

        fsize: f64 = 0.0,

        pub fn deserialize(
            allocator: std.mem.Allocator,
            tokens: *std.mem.TokenIterator(u8, .any),
        ) anyerror!Self {
            _ = allocator;
            _ = tokens;
            return .{};
        }

        pub fn dispatch(
            self: *const Self,
            engine: *engine_.Engine(Searcher),
        ) anyerror!void {
            _ = self;
            try engine.writer.print("Hello from command one!", .{});
        }
    };
}

pub fn CommandTwo(comptime Searcher: type) type {
    return struct {
        const Self = @This();
        pub const command_name: []const u8 = "two";

        tsize: ?f16 = 0.0,

        pub fn deserialize(
            allocator: std.mem.Allocator,
            tokens: *std.mem.TokenIterator(u8, .any),
        ) anyerror!Self {
            _ = allocator;
            _ = tokens;
            return .{};
        }

        pub fn dispatch(
            self: *const Self,
            engine: *engine_.Engine(Searcher),
        ) anyerror!void {
            _ = self;
            try engine.writer.print("Hello from command two!", .{});
        }
    };
}
