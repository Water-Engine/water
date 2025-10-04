const std = @import("std");
const water = @import("water");

const search = @import("search.zig");

const Engine = water.engine.Engine(search.Search);

pub const PositionCommand = struct {
    pub const command_name: []const u8 = "position";

    fen: []const u8 = water.board.StartingFen,
    startpos: ?bool = false,

    moves: ?[]const u8 = null,

    pub fn deserialize(
        allocator: std.mem.Allocator,
        tokens: *std.mem.TokenIterator(u8, .any),
    ) anyerror!PositionCommand {
        var parsed = try water.dispatcher.deserializeFields(
            PositionCommand,
            allocator,
            tokens,
            &.{"startpos"},
            &.{"moves"},
        );

        // Handle ambiguity with the fen/startpos
        if (parsed.startpos) |sp| {
            if (sp) parsed.fen = water.board.StartingFen;
        } else if (parsed.fen.len == 0) {
            parsed.fen = water.board.StartingFen;
        }

        // Collect the moves and return
        parsed.moves = water.dispatcher.tokensAfter(tokens, "moves");
        return parsed;
    }

    pub fn dispatch(
        self: *const PositionCommand,
        engine: *Engine,
    ) anyerror!void {
        if (!try engine.searcher.board.setFen(self.fen, true)) {
            return water.ChessError.IllegalFen;
        }

        if (self.moves) |moves| {
            var move_tokens = std.mem.tokenizeAny(u8, moves, " ");
            while (move_tokens.next()) |move_str| {
                const move = water.uci.uciToMove(engine.searcher.board, move_str);

                // Robustly verify the legality of the move before making the move
                var movelist = water.movegen.Movelist{};
                water.movegen.legalmoves(engine.searcher.board, &movelist, .{});

                if (movelist.find(move)) |_| {
                    engine.searcher.board.makeMove(move, .{});
                }
            }
        }
    }
};

pub const DisplayCommand = struct {
    pub const command_name: []const u8 = "d";

    black_at_top: bool = false,

    pub fn deserialize(
        allocator: std.mem.Allocator,
        tokens: *std.mem.TokenIterator(u8, .any),
    ) anyerror!DisplayCommand {
        return water.dispatcher.deserializeFields(
            DisplayCommand,
            allocator,
            tokens,
            &.{"black_at_top"},
            null,
        ) catch |err| switch (err) {
            error.NoKVPairs => return .{},
            else => return err,
        };
    }

    pub fn dispatch(
        self: *const DisplayCommand,
        engine: *Engine,
    ) anyerror!void {
        _ = self;
        const diagram = try water.uci.uciBoardDiagram(engine.searcher.board, .{});
        defer engine.allocator.free(diagram);
        try engine.writer.print("{s}\n", .{diagram});
        try engine.writer.flush();
    }
};

pub const GoCommand = struct {
    pub const command_name: []const u8 = "go";

    pub fn deserialize(
        allocator: std.mem.Allocator,
        tokens: *std.mem.TokenIterator(u8, .any),
    ) anyerror!GoCommand {
        _ = allocator;
        _ = tokens;
        return .{};
    }

    pub fn dispatch(
        self: *const GoCommand,
        engine: *Engine,
    ) anyerror!void {
        _ = self;
        _ = engine;
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
