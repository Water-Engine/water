const std = @import("std");

const board_ = @import("../board/board.zig");
const Board = board_.Board;

const move = @import("../core/move.zig");
const Move = move.Move;

const tv = @import("type_validators.zig");
const dispatcher = @import("dispatcher.zig");
const default_commands = @import("default_commands.zig");

/// Creates a uci compatible engine with the provided searcher.
///
/// The Searcher must be a struct that abides to this contract:
/// - A function `init` which takes any arguments along with a *Board and must return `anyerror!*Searcher`
/// - A function `deinit` which takes any arguments but must return `void`
/// - A function `search` which takes any arguments and returns `void`
/// - An atomic field named `should_stop` of type `std.atomic.Value(bool)`
/// - A field named `governing_board` which is of type `*Board`
/// - A field named `search_board` which is of type `*Board`
///
/// The searcher's `search_board` is used for searcher and access is not thread safe.
/// The searcher's `governing_board` is the board at the start of the search.
///
/// The engine is responsible for telling the searcher when to stop, but determining alloted time must be handled externally.
/// Of course, the searcher can stop itself if it feels so inclined.
///
/// The searcher should free its `search_board`, but the `governing_board` should be handled externally.
///
/// Any Searcher that violates this contract results in a compilation error.
pub fn Engine(comptime Searcher: type) type {
    const SearcherBoardFieldTypeExpected = *Board;
    const SearcherShouldStopFieldTypeExpected = std.atomic.Value(bool);

    const SearcherInitFnExpected = anyerror!*Searcher;
    const SearcherDeinitFnExpected = void;
    const SearchFnExpected = anyerror!void;

    // Verify the Searcher's contract with some beautiful comptime reflection
    comptime {
        const searcher = @typeInfo(Searcher);
        switch (searcher) {
            .@"struct" => |searcher_struct| {
                if (searcher_struct.is_tuple) @compileError("Searcher must be a non-tuple 'struct'");

                // Validate the required fields
                tv.validateField(
                    Searcher,
                    "governing_board",
                    SearcherBoardFieldTypeExpected,
                    "Searcher must have field 'governing_board' of type '" ++ @typeName(SearcherBoardFieldTypeExpected) ++ "'",
                );

                tv.validateField(
                    Searcher,
                    "search_board",
                    SearcherBoardFieldTypeExpected,
                    "Searcher must have field 'search_board' of type '" ++ @typeName(SearcherBoardFieldTypeExpected) ++ "'",
                );

                tv.validateField(
                    Searcher,
                    "should_stop",
                    SearcherShouldStopFieldTypeExpected,
                    "Searcher must have field 'should_stop' of type '" ++ @typeName(SearcherShouldStopFieldTypeExpected) ++ "'",
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
        search_timer_thread: ?std.Thread = null,

        search_start_time_ns: ?i128 = null,
        alloted_search_time_ns: ?i128 = null,

        welcome: ?[]const u8 = null,
        last_played: ?Move = null,

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
        /// The function automatically forwards the first argument (*Searcher) for the `deinit` call.
        pub fn deinit(self: *Self, search_deinit_args: anytype) void {
            defer self.allocator.destroy(self);

            if (self.search_thread) |search_thread| {
                search_thread.join();
            }

            // Free all other resources safely
            @call(
                .auto,
                Searcher.deinit,
                .{self.searcher} ++ search_deinit_args,
            );
        }

        /// Initiates the search, forwarding any provided args in `search_args`.
        /// The search spins up on a background thread to prevent IO blocking.
        ///
        /// The function automatically handles the first argument (*Searcher) for the `search` call.
        /// This can be disabled through the `options` arg.
        ///
        /// Ensure the alloted search time is in nanoseconds. Making it null corresponds to infinite thinking time.
        ///
        /// If a search is currently in progress, waits for the thread to wrap up.
        pub fn search(self: *Self, search_time_ns: ?i128, search_args: anytype, comptime options: struct {
            forward_ptr: bool = true,
            searcher_stack_size_mb: usize = 64,
        }) void {
            // Stop any current searching
            self.notifyStopSearch();

            // Reload the searcher's search_board
            self.searcher.search_board.deinit();
            self.searcher.search_board = self.searcher.governing_board.clone(self.allocator) catch unreachable;

            self.search_thread = std.Thread.spawn(
                .{ .stack_size = options.searcher_stack_size_mb * 1024 * 1024 },
                Searcher.search,
                if (options.forward_ptr) .{self.searcher} ++ search_args else search_args,
            ) catch unreachable;

            self.search_start_time_ns = std.time.nanoTimestamp();
            self.alloted_search_time_ns = search_time_ns;
            if (search_time_ns) |limit_ns| {
                self.search_timer_thread = std.Thread.spawn(
                    .{},
                    timerThread,
                    .{ self, limit_ns },
                ) catch unreachable;
            }
        }

        /// Kicks off the timer thread with the given nanosecond time limit.
        fn timerThread(self: *Self, limit_ns: i128) void {
            const start = self.search_start_time_ns orelse return;
            const sleep_interval_ns = 1_000_000_000 / 20;
            var now: i128 = start;

            while (true) {
                std.Thread.sleep(@intCast(sleep_interval_ns));
                now = std.time.nanoTimestamp();
                if (now - start >= limit_ns) {
                    self.searcher.should_stop.store(true, .release);
                    break;
                }

                // If another search began, stop timer
                if (self.alloted_search_time_ns == null) break;
            }
        }

        /// Tells the search thread that it should stop.
        ///
        /// Also halts the search timer.
        fn notifyStopSearch(self: *Self) void {
            self.searcher.should_stop.store(true, .release);
            self.alloted_search_time_ns = null;
            self.search_start_time_ns = null;

            if (self.search_thread) |search_thread| {
                search_thread.join();
                self.search_thread = null;
            }

            if (self.search_timer_thread) |timer| {
                timer.join();
                self.search_timer_thread = null;
            }
        }

        /// Starts the engines UCI compatible event loop. The provided commands are deserialized every input read.
        ///
        /// Some commands are implemented for you, like `d` and `position`.
        /// The `uci` and `isready` commands are also defaults, but have no internal logic and only respond as per the uci spec.
        /// For more information regarding the uci protocol, including what you need to handle:
        /// https://gist.github.com/DOBRO/2592c6dad754ba67e6dcaec8c90165bf
        ///
        /// The 'quit' and 'stop' commands are handled internally. Cleanup of resources is not a responsibility of this function.
        ///
        /// The reader is used for handling user input and should almost always be `stdin`.
        pub fn launch(self: *Self, reader: *std.Io.Reader, comptime commands: struct {
            uci_command: type = default_commands.UciCommand(Searcher),
            ready_command: type = default_commands.ReadyCommand(Searcher),
            position_command: type = default_commands.PositionCommand(Searcher),
            display_command: type = default_commands.DisplayCommand(Searcher),
            go_command: type,
            opt_command: type,
            other_commands: []const type = &.{},
        }) !void {
            const command_list = comptime blk: {
                var list: []const type = &.{};

                for (std.meta.fields(@TypeOf(commands))) |field| {
                    const val = @field(commands, field.name);
                    const field_type = @TypeOf(val);

                    if (field_type == type) {
                        list = list ++ .{val};
                    } else if (field_type == []const type) {
                        list = list ++ val;
                    } else {
                        @compileError("Commands struct must only contain fields and slices of fields");
                    }
                }

                break :blk list;
            };

            const Dispatcher = dispatcher.Dispatcher(command_list, Searcher);
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

                // Manually handle the quit and stop commands as they are constants
                if (line.len == 4) {
                    if (std.mem.startsWith(u8, line, "quit")) {
                        self.notifyStopSearch();
                        break;
                    } else if (std.mem.startsWith(u8, line, "stop")) {
                        self.notifyStopSearch();
                        continue;
                    }
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

    var buffer: [1024]u8 = undefined;
    var discarding = std.Io.Writer.Discarding.init(&buffer);
    const writer = &discarding.writer;

    var board = try Board.init(allocator, .{});
    defer board.deinit();

    const instance = Engine(test_objs.TestSearcher);
    const e = try instance.init(
        allocator,
        writer,
        .{ allocator, board },
    );
    defer e.deinit(.{});

    e.search(null, .{}, .{});
}
