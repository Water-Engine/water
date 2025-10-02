const std = @import("std");
const help = @import("help");

const board_ = @import("../board/board.zig");
const Board = board_.Board;

/// Validates the given Fn's return type against the Expected type.
///
/// The given message is shown as a compile error if an error is encountered.
fn validateReturnType(comptime Fn: type, comptime Expected: type, comptime msg: []const u8) void {
    const fn_type = @typeInfo(Fn);
    switch (fn_type) {
        .@"fn" => |f| {
            const ret_type = f.return_type;
            if (ret_type) |Actual| {
                if (Actual != Expected) @compileError(msg);
            } else @compileError(msg);
        },
        else => @compileError(msg),
    }
}

/// Validates that the given container has a field of the given name and type.
///
/// The given message is shown as a compile error if an error is encountered.
fn validateField(
    comptime Container: type,
    comptime field_name: []const u8,
    comptime ExpectedFieldType: type,
    comptime msg: []const u8,
) void {
    if (@hasField(Container, field_name)) {
        const ActualFieldType = @FieldType(Container, field_name);
        if (ActualFieldType != ExpectedFieldType) @compileError(msg);
    } else @compileError(msg);
}

/// Creates a uci compatible engine with the provided searcher.
///
/// The Searcher must be a struct that abides to this contract:
/// - A function `init` which takes any arguments but must return `anyerror!*Searcher`
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
                validateField(
                    Searcher,
                    "board",
                    SearcherBoardFieldTypeExpected,
                    "Searcher must have field 'board' of type '" ++ @typeName(SearcherBoardFieldTypeExpected) ++ "'",
                );

                // Validate the contracted function's return types
                validateReturnType(
                    blk: {
                        if (!@hasDecl(Searcher, "init")) @compileError("Searcher must have decl 'init'");
                        break :blk @TypeOf(Searcher.init);
                    },
                    SearcherInitFnExpected,
                    "Searcher decl 'init' must be a function with return type '" ++ @typeName(SearcherInitFnExpected) ++ "'",
                );

                validateReturnType(
                    blk: {
                        if (!@hasDecl(Searcher, "deinit")) @compileError("Searcher must have decl 'deinit'");
                        break :blk @TypeOf(Searcher.deinit);
                    },
                    SearcherDeinitFnExpected,
                    "Searcher decl 'deinit' must be a function with return type '" ++ @typeName(SearcherDeinitFnExpected) ++ "'",
                );

                validateReturnType(
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
        name: ?[]const u8 = null,

        writer: *std.Io.Writer,

        const Self = @This();

        /// Initializes the engine and allocates all its resources.
        ///
        /// The `search_init_args` are forwarded to the Searcher's `init` function.
        pub fn init(allocator: std.mem.Allocator, writer: *std.Io.Writer, search_init_args: anytype) !*Self {
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

        /// Starts the engines UCI compatible event loop.
        ///
        /// The reader is used for handling user input and should almost always be `stdin`.
        pub fn launch(self: *Self, reader: *std.Io.Reader) !void {
            // Introduce the engine (if given)
            if (self.name) |engine_name| {
                try self.writer.print("{s} by the {s} developers (see AUTHORS file)\n", .{ engine_name, engine_name });
                try self.writer.print("Powered by the Water Chess Library v{s}\n", .{help.version});
                try self.writer.flush();
            }

            // Start the main loop, only exiting with an error if not doing so would result in unrecoverable state
            while (true) {
                const line = reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
                    error.EndOfStream, error.ReadFailed => break,
                    else => continue,
                };
                try self.writer.flush();
                try self.writer.print("TODO: {s}\n", .{line});
            }
        }
    };
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

test "Comptime contract validation" {
    const allocator = testing.allocator;

    var test_buffer = std.Io.Writer.Allocating.init(allocator);
    defer test_buffer.deinit();
    const writer = &test_buffer.writer;

    var board = try Board.init(allocator, .{});
    defer board.deinit();

    const TestSearcher = struct {
        const Self = @This();
        allocator: std.mem.Allocator,

        board: *Board,

        pub fn init(a: std.mem.Allocator, b: *Board) anyerror!*Self {
            const searcher = try a.create(Self);
            searcher.* = .{
                .allocator = a,
                .board = b,
            };

            return searcher;
        }

        pub fn deinit(self: *Self) void {
            _ = self;
        }

        pub fn search(self: *Self) anyerror!void {
            _ = self;
        }
    };

    const instance = Engine(TestSearcher);
    const e = try instance.init(
        allocator,
        writer,
        .{ allocator, board },
    );
    defer e.deinit(.{});

    e.search(.{}, .{});
}
