const std = @import("std");

const board_ = @import("../board/board.zig");
const Board = board_.Board;

const types = @import("../core/types.zig");
const uci = @import("../core/uci.zig");

const movegen = @import("../movegen/movegen.zig");

const dispatcher = @import("dispatcher.zig");
const engine_ = @import("engine.zig");

pub fn PositionCommand(comptime Searcher: type) type {
    return struct {
        const Self = @This();
        pub const command_name: []const u8 = "position";

        fen: []const u8 = board_.starting_fen,
        startpos: ?bool = false,

        moves: ?[]const u8 = null,

        pub fn deserialize(
            allocator: std.mem.Allocator,
            tokens: *std.mem.TokenIterator(u8, .any),
        ) anyerror!Self {
            _ = allocator;
            var parsed = try dispatcher.deserializeFields(
                Self,
                tokens,
                &.{"startpos"},
                &.{"moves"},
            );

            // Handle ambiguity with the fen/startpos
            if (parsed.startpos) |sp| {
                if (sp) parsed.fen = board_.starting_fen;
            } else if (parsed.fen.len == 0) {
                parsed.fen = board_.starting_fen;
            }

            // Collect the moves and return
            parsed.moves = dispatcher.tokensAfter(tokens, "moves");
            return parsed;
        }

        pub fn dispatch(
            self: *const Self,
            engine: *engine_.Engine(Searcher),
        ) anyerror!void {
            if (!engine.searcher.should_stop.load(.acquire)) return;
            if (!try engine.searcher.governing_board.setFen(self.fen, true)) {
                return types.ChessError.IllegalFen;
            }

            engine.last_played = null;
            if (self.moves) |moves| {
                var move_tokens = std.mem.tokenizeAny(u8, moves, " ");
                while (move_tokens.next()) |move_str| {
                    const move = uci.uciToMove(engine.searcher.governing_board, move_str);

                    // Robustly verify the legality of the move before making the move
                    var movelist = movegen.Movelist{};
                    movegen.legalmoves(engine.searcher.governing_board, &movelist, .{});

                    if (movelist.find(move)) |_| {
                        engine.searcher.governing_board.makeMove(move, .{});
                        engine.last_played = move;
                    }
                }
            }

            // Force an update to the searcher's search_board
            engine.searcher.search_board.deinit();
            engine.searcher.search_board = try engine.searcher.governing_board.clone(engine.allocator);
        }
    };
}

pub fn DisplayCommand(comptime Searcher: type) type {
    return struct {
        const Self = @This();
        pub const command_name: []const u8 = "d";

        black_at_top: ?bool = null,

        pub fn deserialize(
            allocator: std.mem.Allocator,
            tokens: *std.mem.TokenIterator(u8, .any),
        ) anyerror!Self {
            _ = allocator;
            return dispatcher.deserializeFields(
                Self,
                tokens,
                null,
                null,
            ) catch |err| switch (err) {
                error.NoKVPairs => return .{},
                else => return err,
            };
        }

        pub fn dispatch(
            self: *const Self,
            engine: *engine_.Engine(Searcher),
        ) anyerror!void {
            const diagram = try uci.uciBoardDiagram(engine.searcher.governing_board, .{
                .black_at_top = self.black_at_top,
                .highlighted_move = engine.last_played,
            });
            defer engine.allocator.free(diagram);
            try engine.writer.print("{s}\n", .{diagram});
            try engine.writer.flush();
        }
    };
}

pub fn UciCommand(comptime Searcher: type) type {
    return struct {
        const Self = @This();
        pub const command_name: []const u8 = "uci";

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
            try engine.writer.print("uciok\n", .{});
            try engine.writer.flush();
        }
    };
}

pub fn ReadyCommand(comptime Searcher: type) type {
    return struct {
        const Self = @This();
        pub const command_name: []const u8 = "isready";

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
            try engine.writer.print("readyok\n", .{});
            try engine.writer.flush();
        }
    };
}
