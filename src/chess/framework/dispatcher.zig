const std = @import("std");

const engine_ = @import("engine.zig");
const tv = @import("type_validators.zig");

const board_ = @import("../board/board.zig");

pub const DeserializeError = error{
    NoKVPairs,
    InvalidFieldType,
    IntegerParseError,
    FloatParseError,
    BoolParseError,
    TemporaryAllocationError,
    ArrayParseError,
};

/// Deserializes key-value arguments from a UCI string into a struct T. Assumes input as:
///
/// <label> [key1] [val1] [standalone] [key2] [val2] etc... [sentinel] [rest]
///
/// The token iterator is reset to its default state upon returning.
/// The assigned values in the returned type have lifetimes matching the token iterator, when applicable.
/// The keys in the given type should have the names matching the expected tokens.
///
/// Standalone tokens are processed without consuming a value. They are only compatible with bool fields.
/// Standalone tokens injected into a pattern where a value would be expected results in the token being processed as usual.
///
/// T must be a struct with fields that are all default initialized.
pub fn deserializeFields(
    comptime T: type,
    allocator: std.mem.Allocator,
    tokens: *std.mem.TokenIterator(u8, .any),
    comptime standalone_tokens: ?[]const []const u8,
    comptime kv_ignores: ?[]const []const u8,
) DeserializeError!T {
    defer tokens.reset();

    // Verify T's type requirement
    comptime {
        switch (@typeInfo(T)) {
            .@"struct" => |s| {
                for (s.fields) |field| {
                    if (field.default_value_ptr == null) {
                        @compileError(@typeName(T) ++ " cannot have non-default initialized fields");
                    }
                }
            },
            else => @compileError(@typeName(T) ++ " must be a struct"),
        }

        if (standalone_tokens) |toks| {
            for (toks) |token| {
                if (!@hasField(T, token)) {
                    @compileError(@typeName(T) ++ " must contain all provided standalone tokens, but is missing at least " ++ token);
                }
            }
        }
    }
    var result: T = .{};

    const standalones = comptime blk: {
        if (standalone_tokens) |toks| {
            break :blk toks;
        } else break :blk &.{};
    };

    const result_fields = comptime @typeInfo(T).@"struct".fields;

    // Deconstruct the tokens, skipping the label of the command
    _ = tokens.next();
    if (tokens.peek() == null) {
        return error.NoKVPairs;
    }

    outer: while (tokens.next()) |key| {
        // Check for standalone before polling the iterator again for a value
        var is_standalone = false;
        inline for (standalones) |tok| {
            if (std.mem.eql(u8, key, tok)) {
                is_standalone = true;
                break;
            }
        }

        if (is_standalone) {
            inline for (result_fields) |field| {
                if (std.mem.eql(u8, key, field.name)) {
                    if (@typeInfo(field.type) != .bool and
                        !(@typeInfo(field.type) == .optional and @typeInfo(field.type).optional.child == bool))
                    {
                        return error.InvalidFieldType;
                    }
                    @field(result, field.name) = true;
                }
            }
            continue;
        }

        // We already handle the case where only the label is present, so just break on malformed input
        const value = tokens.next() orelse break;
        inline for (result_fields) |field| {
            if (kv_ignores) |ignores| {
                inline for (ignores) |ignore| {
                    if (std.mem.eql(u8, ignore, field.name)) continue :outer;
                }
            }

            if (std.mem.eql(u8, key, field.name)) {
                const FieldType = if (@typeInfo(field.type) == .optional) @typeInfo(field.type).optional.child else field.type;
                switch (@typeInfo(FieldType)) {
                    .bool => {
                        const lowered = std.ascii.allocLowerString(allocator, value) catch {
                            return error.TemporaryAllocationError;
                        };
                        defer allocator.free(lowered);

                        @field(result, field.name) = if (std.mem.eql(u8, "true", lowered)) blk: {
                            break :blk true;
                        } else if (std.mem.eql(u8, "1", lowered)) blk: {
                            break :blk true;
                        } else if (std.mem.eql(u8, "false", lowered)) blk: {
                            break :blk true;
                        } else if (std.mem.eql(u8, "0", lowered)) blk: {
                            break :blk true;
                        } else return error.BoolParseError;
                    },
                    .int => {
                        @field(result, field.name) = std.fmt.parseInt(FieldType, value, 10) catch {
                            return error.IntegerParseError;
                        };
                    },
                    .float => {
                        @field(result, field.name) = std.fmt.parseFloat(FieldType, value) catch {
                            return error.FloatParseError;
                        };
                    },
                    .pointer => |p| {
                        if (p.size == .slice and p.child == u8) {
                            @field(result, field.name) = value;
                        } else {
                            return error.InvalidFieldType;
                        }
                    },
                    else => return error.InvalidFieldType,
                }
            }
        }
    }

    return result;
}

/// Returns a string containing all of the tokens after the given keyword.
///
/// The token iterator is returned in a reset state.
/// The returned string has a lifetime matching the token iterator.
pub fn tokensAfter(
    tokens: *std.mem.TokenIterator(u8, .any),
    keyword: []const u8,
) ?[]const u8 {
    defer tokens.reset();
    while (tokens.next()) |next| {
        if (std.mem.eql(u8, keyword, next)) {
            break;
        }
    } else return null;

    return tokens.rest();
}

/// Creates a dispatcher equipped to dispatch functionality among the Commands.
///
/// All Commands must fulfil the contract enforced by `validateCommand`.
pub fn Dispatcher(comptime commands: []const type, comptime Searcher: type) type {
    inline for (commands) |Cmd| {
        tv.validateCommand(Cmd, Searcher);
    }

    return struct {
        /// Dispatches the token input to the matching Command.
        pub fn dispatch(
            tokens: *std.mem.TokenIterator(u8, .any),
            engine: *engine_.Engine(Searcher),
        ) anyerror!void {
            const command_name = tokens.peek() orelse return error.NoCommandName;
            inline for (commands) |Cmd| {
                if (std.mem.eql(u8, command_name, Cmd.command_name)) {
                    const payload = try @call(.auto, Cmd.deserialize, .{ engine.allocator, tokens });
                    try payload.dispatch(engine);
                    return;
                }
            } else return error.NoMatchingCommand;
        }
    };
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

const test_objs = @import("test_objs.zig");

test "Basic field deserialize use" {
    const allocator = testing.allocator;

    var tokens = std.mem.tokenizeAny(u8, "buffer: []const T", " ");
    const result = try deserializeFields(
        test_objs.TestCommand(test_objs.TestSearcher),
        allocator,
        &tokens,
        null,
        null,
    );

    try expectEqual(0.0, result.fsize);
    try expectEqual(0.0, result.tsize);
    try expectEqual(null, result.wtime);
    try expectEqual(null, result.btime);
    try expectEqual(null, result.winc);
    try expectEqual(null, result.binc);
    try expect(!result.infinite);
    try expect(!result.crunched);
    try expectEqualSlices(u8, "test", result.name);
    try expectEqual(-1, result.msize);
}

test "Actual field deserialize use" {
    const allocator = testing.allocator;

    var tokens = std.mem.tokenizeAny(
        u8,
        "go wtime 10 crunched btime 9 winc 1 msize -67 binc 2 name john fsize 100.2 tsize -3.0",
        " ",
    );
    const result = try deserializeFields(
        test_objs.TestCommand(test_objs.TestSearcher),
        allocator,
        &tokens,
        &.{"crunched"},
        null,
    );

    try expectEqual(10, result.wtime);
    try expectEqual(9, result.btime);
    try expectEqual(1, result.winc);
    try expectEqual(2, result.binc);
    try expect(!result.infinite);
    try expectEqualSlices(u8, "john", result.name);

    try expectEqual(100.2, result.fsize);
    try expectEqual(-3.0, result.tsize);

    try expectEqual(-67, result.msize);
    try expect(result.crunched);
}

test "Runtime deserialization errors" {
    const allocator = testing.allocator;

    // NoKVPairs: only label present
    {
        var tokens = std.mem.tokenizeAny(u8, "go", " ");
        try testing.expectError(
            error.NoKVPairs,
            deserializeFields(
                test_objs.TestCommand(test_objs.TestSearcher),
                allocator,
                &tokens,
                &.{"crunched"},
                null,
            ),
        );
    }

    // IntegerParseError
    {
        var tokens = std.mem.tokenizeAny(u8, "go msize not_an_int", " ");
        try testing.expectError(
            error.IntegerParseError,
            deserializeFields(
                test_objs.TestCommand(test_objs.TestSearcher),
                allocator,
                &tokens,
                &.{"crunched"},
                null,
            ),
        );
    }

    // FloatParseError
    {
        var tokens = std.mem.tokenizeAny(u8, "go fsize not_a_float", " ");
        try testing.expectError(
            error.FloatParseError,
            deserializeFields(
                test_objs.TestCommand(test_objs.TestSearcher),
                allocator,
                &tokens,
                &.{"crunched"},
                null,
            ),
        );
    }

    // BoolParseError (invalid value for bool)
    {
        var tokens = std.mem.tokenizeAny(u8, "go infinite maybe", " ");
        try testing.expectError(
            error.BoolParseError,
            deserializeFields(
                test_objs.TestCommand(test_objs.TestSearcher),
                allocator,
                &tokens,
                &.{"crunched"},
                null,
            ),
        );
    }

    // InvalidFieldType: Make a struct with a field type not supported
    const BadStruct = struct { label: ?void = null };
    {
        var tokens = std.mem.tokenizeAny(u8, "go label 123", " ");
        try testing.expectError(
            error.InvalidFieldType,
            deserializeFields(
                BadStruct,
                allocator,
                &tokens,
                null,
                null,
            ),
        );
    }

    // InvalidFieldType: use []i32 instead of []u8
    const BadArray = struct { arr: []i32 = &.{} };
    {
        var tokens = std.mem.tokenizeAny(u8, "go arr 123", " ");
        try testing.expectError(
            error.InvalidFieldType,
            deserializeFields(
                BadArray,
                allocator,
                &tokens,
                null,
                null,
            ),
        );
    }
}

test "Tokens after" {
    var tokens_missing = std.mem.tokenizeAny(u8, "go arr 123 a123 223 09 asdw arr", " ");
    const after_missing = tokensAfter(&tokens_missing, "moves");
    try expect(after_missing == null);

    var tokens_containing = std.mem.tokenizeAny(u8, "go arr 123 a123 223 09 asdw arr", " ");
    const after_containing = tokensAfter(&tokens_containing, "arr");
    try expect(after_containing != null);
    try expectEqualSlices(u8, after_containing.?, "123 a123 223 09 asdw arr");
}

test "Dispatcher usage" {
    const allocator = testing.allocator;
    const D = Dispatcher(
        &.{ test_objs.CommandOne(test_objs.TestSearcher), test_objs.CommandTwo(test_objs.TestSearcher) },
        test_objs.TestSearcher,
    );

    var one_tokens = std.mem.tokenizeAny(u8, "one label 123", " ");

    var test_buffer = std.Io.Writer.Allocating.init(allocator);
    defer test_buffer.deinit();
    const writer = &test_buffer.writer;

    var board = try board_.Board.init(allocator, .{});
    defer board.deinit();

    const instance = engine_.Engine(test_objs.TestSearcher);
    const e = try instance.init(
        allocator,
        writer,
        .{ allocator, board },
    );
    defer e.deinit(.{});

    try D.dispatch(&one_tokens, e);
    try expectEqualSlices(u8, "Hello from command one!", writer.buffered());
}
