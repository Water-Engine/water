const std = @import("std");

fn validateReturnType(comptime Fn: type, comptime Expected: type, comptime msg: []const u8) void {
    const fn_type = @typeInfo(Fn);
    switch (fn_type) {
        .@"fn" => |f| {
            const ret_type = f.return_type;
            if (ret_type) |return_type| {
                // Destructure return types
                const actual = @typeInfo(return_type);
                const expected = @typeInfo(Expected);
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
    // Verify the Searcher's contract
    comptime {
        const searcher = @typeInfo(Searcher);
        switch (searcher) {
            .@"struct" => |searcher_struct| {
                if (searcher_struct.is_tuple) @compileError("Searcher must be a non-tuple 'struct'");

                // Check contract declarations
                if (!@hasDecl(Searcher, "init")) @compileError("Searcher must have decl 'init'");
                if (!@hasDecl(Searcher, "deinit")) @compileError("Searcher must have decl 'deinit'");
                if (!@hasDecl(Searcher, "search")) @compileError("Searcher must have decl 'search'");

                // Check contract declaration return types (safe due to decl checks)
                validateReturnType(
                    @TypeOf(Searcher.init),
                    !*Searcher,
                    "Searcher decl 'init' must be a function with return type 'anyerror!*Searcher'",
                );

                const deinit_fn = @typeInfo(@TypeOf(Searcher.deinit));
                if (deinit_fn != .@"fn") @compileError("Searcher decl 'deinit' must be a function");
                const deinit_ret = deinit_fn.@"fn".return_type;
                if (deinit_ret) |return_type| {
                    _ = return_type;
                } else @compileError("Searcher decl 'deinit' must have return type void");

                const search_fn = @typeInfo(@TypeOf(Searcher.search));
                if (search_fn != .@"fn") @compileError("Searcher decl 'search' must be a function");
                const search_ret = search_fn.@"fn".return_type;
                if (search_ret) |return_type| {
                    _ = return_type;
                } else @compileError("Searcher decl 'search' must have return type !*Searcher");
            },
            else => @compileError("Searcher must be of type 'struct'"),
        }
    }

    return struct {
        const Self = @This();
    };
}
