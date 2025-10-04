const std = @import("std");

const board_ = @import("../board/board.zig");
const Board = board_.Board;

const tv = @import("type_validators.zig");
const dispatcher = @import("dispatcher.zig");

/// Creates a uci compatible engine with the provided searcher.
///
/// The Searcher must be a struct that abides to this contract:
/// - A function `init` which takes any arguments along with a *Board and must return `anyerror!*Searcher`
/// - A function 'deinit' which takes any arguments but must return `void`
/// - A function `search` which takes any arguments and returns `void`
/// - A field named `board` which is of type `*Board`
///
/// Any Searcher that violates this contract results in a compilation error.
pub fn Engine(comptime Searcher: type) type {
    const SearcherBoardFieldTypeExpected = *Board;

    const SearcherInitFnExpected = anyerror!*Searcher;
    const SearcherDeinitFnExpected = void;
    const SearchFnExpected = anyerror!void;

    // Verify the Searcher's contract with some beautiful metaprogramming
    comptime {
        const searcher = @typeInfo(Searcher);
        switch (searcher) {
            .@"struct" => |searcher_struct| {
                if (searcher_struct.is_tuple) @compileError("Searcher must be a non-tuple 'struct'");

                // Validate the required fields
                tv.validateField(
                    Searcher,
                    "board",
                    SearcherBoardFieldTypeExpected,
                    "Searcher must have field 'board' of type '" ++ @typeName(SearcherBoardFieldTypeExpected) ++ "'",
                );

                // Validate the contracted function's types
                tv.validateReturnType(
                    blk: {
                        if (!@hasDecl(Searcher, "init")) @compileError("Searcher must have decl 'init'");
                        break :blk @TypeOf(Searcher.init);
                    },
                    SearcherInitFnExpected,
                    "Searcher decl 'init' must be a function with return type '" ++ @typeName(SearcherInitFnExpected) ++ "'",
                );

                tv.validateParameterContains(
                    @TypeOf(Searcher.init),
                    *Board,
                    "Searcher decl 'init' must be a function with at least parameter type '*Board'",
                );

                tv.validateReturnType(
                    blk: {
                        if (!@hasDecl(Searcher, "deinit")) @compileError("Searcher must have decl 'deinit'");
                        break :blk @TypeOf(Searcher.deinit);
                    },
                    SearcherDeinitFnExpected,
                    "Searcher decl 'deinit' must be a function with return type '" ++ @typeName(SearcherDeinitFnExpected) ++ "'",
                );

                tv.validateReturnType(
                    blk: {
                        if (!@hasDecl(Searcher, "search")) @compileError("Searcher must have decl 'search'");
                        break :blk @TypeOf(Searcher.search);
                    },
                    SearchFnExpected,
                    "Searcher decl 'search' must be a function with return type '" ++ @typeName(SearchFnExpected) ++ "'",
                );
            },
            else => @compileError("Searcher must be of type 'struct'"),
        }
    }

    return struct {
        allocator: std.mem.Allocator,

        searcher: *Searcher,
        search_thread: ?std.Thread = null,
        welcome: ?[]const u8 = null,

        writer: *std.Io.Writer,

        const Self = @This();

        /// Initializes the engine and allocates all its resources.
        ///
        /// The `search_init_args` are forwarded to the Searcher's `init` function.
        pub fn init(
            allocator: std.mem.Allocator,
            writer: *std.Io.Writer,
            search_init_args: anytype,
        ) !*Self {
            const engine = try allocator.create(Self);
            engine.* = .{
                .allocator = allocator,
                .searcher = try @call(.auto, Searcher.init, search_init_args),
                .writer = writer,
            };

            return engine;
        }

        /// Deinitializes the engine, fully freeing all constituent resources.
        ///
        /// The `search_deinit_args` are forwarded to the Searcher's `deinit` function.
        /// The function automatically handles the first argument (*Searcher) for the `deinit` call.
        pub fn deinit(self: *Self, search_deinit_args: anytype) void {
            // Defer the deallocation of key resources
            defer {
                self.allocator.destroy(self.searcher);
                self.allocator.destroy(self);
            }

            // Free all other resources safely
            @call(
                .auto,
                Searcher.deinit,
                .{self.searcher} ++ search_deinit_args,
            );

            if (self.search_thread) |search_thread| {
                search_thread.join();
            }
        }

        /// Initiates the search, forwarding any provided args in `search_args`.
        /// The search spins up on a background thread to prevent IO blocking.
        ///
        /// The function automatically handles the first argument (*Searcher) for the `search` call.
        /// This can be disabled through the `options` arg.
        ///
        /// If a search is currently in progress, waits for the thread to wrap up.
        pub fn search(self: *Self, search_args: anytype, comptime options: struct {
            forward_ptr: bool = true,
        }) void {
            if (self.search_thread) |search_thread| {
                search_thread.join();
            }

            self.search_thread = std.Thread.spawn(
                .{},
                Searcher.search,
                if (options.forward_ptr) .{self.searcher} ++ search_args else search_args,
            ) catch unreachable;
        }

        /// Starts the engines UCI compatible event loop. The provided commands are deserialized every input read.
        ///
        /// The 'quit' command is implemented for you. Cleanup of resources is not a responsibility of this function.
        ///
        /// The reader is used for handling user input and should almost always be `stdin`.
        pub fn launch(self: *Self, reader: *std.Io.Reader, comptime commands: []const type) !void {
            const Dispatcher = dispatcher.Dispatcher(commands, Searcher);
            if (self.welcome) |msg| {
                try self.writer.print("{s}\n", .{msg});
                try self.writer.flush();
            }

            // Start the main loop, only exiting with an error if not doing so would result in unrecoverable state
            while (true) {
                var line = reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
                    error.EndOfStream, error.ReadFailed => break,
                    else => continue,
                };

                // Handle the carriage return if present
                if (line.len > 0 and line[line.len - 1] == '\r') {
                    line = line[0 .. line.len - 1];
                }

                // Manually handle the quit command since resource responsibility is not for the engine
                if (line.len == 5 and std.mem.startsWith(u8, line, "quit")) {
                    break;
                }

                var tokens = std.mem.tokenizeAny(u8, line, " ");
                Dispatcher.dispatch(&tokens, self) catch |err| switch (err) {
                    error.TemporaryAllocationError => break,
                    else => continue,
                };
            }
        }
    };
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

const test_objs = @import("test_objs.zig");

test "Basic engine creation" {
    const allocator = testing.allocator;

    var test_buffer = std.Io.Writer.Allocating.init(allocator);
    defer test_buffer.deinit();
    const writer = &test_buffer.writer;

    var board = try Board.init(allocator, .{});
    defer board.deinit();

    const instance = Engine(test_objs.TestSearcher);
    const e = try instance.init(
        allocator,
        writer,
        .{ allocator, board },
    );
    defer e.deinit(.{});

    e.search(.{}, .{});
}
