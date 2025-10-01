const std = @import("std");

/// Validates the given Fn's return type against the Expected type.
///
/// The given message is shown as a compile error if an error is encountered.
fn validateReturnType(comptime Fn: type, comptime Expected: type, comptime msg: []const u8) void {
    const fn_type = @typeInfo(Fn);
    switch (fn_type) {
        .@"fn" => |f| {
            const ret_type = f.return_type;
            // Destructure return types
            if (ret_type) |Actual| {
                if (Actual != Expected) @compileError(msg);
            } else @compileError(msg);
        },
        else => @compileError(msg),
    }
}

/// Creates a uci compatible engine with the provided searcher.
///
/// The Searcher must be a struct that abides to this contract:
/// - A function `init` which takes any arguments but must return `anyerror!*Searcher`
/// - A function 'deinit' which takes any arguments but must return `void`
/// - A function `search` which takes any arguments and returns `void`
///
/// Any Searcher that violates this contract results in a compilation error.
pub fn Engine(comptime Searcher: type) type {
    const SearcherInitFnExpected = anyerror!*Searcher;
    const SearcherDeinitFnExpected = void;
    const SearchFnExpected = void;

    // Verify the Searcher's contract with some beautiful metaprogramming
    comptime {
        const searcher = @typeInfo(Searcher);
        switch (searcher) {
            .@"struct" => |searcher_struct| {
                if (searcher_struct.is_tuple) @compileError("Searcher must be a non-tuple 'struct'");

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

        const Self = @This();

        /// Initializes the engine and allocates all its resources.
        ///
        /// The `search_init_args` are forwarded to the Searcher's `init` function.
        pub fn init(allocator: std.mem.Allocator, search_init_args: anytype) !*Self {
            const engine = try allocator.create(Self);
            engine.* = .{
                .allocator = allocator,
                .searcher = try @call(.auto, Searcher.init, search_init_args),
            };

            return engine;
        }

        /// Deinitializes the engine, fully freeing all constituent resources.
        ///
        /// The `search_deinit_args` are forwarded to the Searcher's `deinit` function.
        /// The function automatically handles the first argument for the `deinit` call.
        ///
        /// The user is responsible for destroying the pointer to the instance itself.
        pub fn deinit(self: *Self, search_deinit_args: anytype) void {
            // Defer the deallocation of key resources
            defer self.allocator.destroy(self.searcher);

            // Free all other resources safely
            @call(
                .auto,
                Searcher.deinit,
                .{self.searcher} ++ search_deinit_args,
            );
        }
    };
}
