const std = @import("std");

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
/// <label> [key1] [val1] [key2] [val2] [standalone] etc...
///
/// The token iterator is reset to its default state upon returning.
/// The assigned values in the returned type have lifetimes matching the token iterator, when necessary.
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
) DeserializeError!T {
    defer tokens.reset();

    // Comptime struct initialization - technically overkill but done for strict compliance checking
    var result = comptime blk: {
        var result: T = undefined;

        switch (@typeInfo(T)) {
            .@"struct" => |s| {
                for (s.fields) |field| {
                    if (field.default_value_ptr) |default| {
                        const typed_ptr = @as(*const field.type, @ptrCast(@alignCast(default)));
                        @field(result, field.name) = typed_ptr.*;
                    } else @compileError(@typeName(T) ++ " cannot have non-default initialized fields");
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

        break :blk result;
    };

    const standalones = comptime blk: {
        if (standalone_tokens) |toks| {
            break :blk toks;
        } else break :blk &[_][]const u8{};
    };

    const result_fields = comptime @typeInfo(T).@"struct".fields;

    // Deconstruct the tokens, skipping the label of the command
    _ = tokens.next();
    if (tokens.peek() == null) {
        return error.NoKVPairs;
    }

    while (tokens.next()) |key| {
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

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

const TestCommand = struct {
    const command_name: []const u8 = "go";

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
};

test "Basic field deserialize use" {
    const allocator = testing.allocator;

    var tokens = std.mem.tokenizeAny(u8, "buffer: []const T", " ");
    const result = try deserializeFields(TestCommand, allocator, &tokens, null);

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

    var tokens = std.mem.tokenizeAny(u8, "go wtime 10 crunched btime 9 winc 1 msize -67 binc 2 name john fsize 100.2 tsize -3.0", " ");
    const result = try deserializeFields(TestCommand, allocator, &tokens, &[_][]const u8{"crunched"});

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
                TestCommand,
                allocator,
                &tokens,
                &[_][]const u8{"crunched"},
            ),
        );
    }

    // IntegerParseError
    {
        var tokens = std.mem.tokenizeAny(u8, "go msize not_an_int", " ");
        try testing.expectError(
            error.IntegerParseError,
            deserializeFields(
                TestCommand,
                allocator,
                &tokens,
                &[_][]const u8{"crunched"},
            ),
        );
    }

    // FloatParseError
    {
        var tokens = std.mem.tokenizeAny(u8, "go fsize not_a_float", " ");
        try testing.expectError(
            error.FloatParseError,
            deserializeFields(
                TestCommand,
                allocator,
                &tokens,
                &[_][]const u8{"crunched"},
            ),
        );
    }

    // BoolParseError (invalid value for bool)
    {
        var tokens = std.mem.tokenizeAny(u8, "go infinite maybe", " ");
        try testing.expectError(
            error.BoolParseError,
            deserializeFields(
                TestCommand,
                allocator,
                &tokens,
                &[_][]const u8{"crunched"},
            ),
        );
    }

    // InvalidFieldType: Make a struct with a field type not supported
    const BadStruct = struct { label: ?void = null };
    {
        var tokens = std.mem.tokenizeAny(u8, "go label 123", " ");
        try testing.expectError(
            error.InvalidFieldType,
            deserializeFields(BadStruct, allocator, &tokens, null),
        );
    }

    // InvalidFieldType: use []i32 instead of []u8
    const BadArray = struct { arr: []i32 = &[_]i32{} };
    {
        var tokens = std.mem.tokenizeAny(u8, "go arr 123", " ");
        try testing.expectError(
            error.InvalidFieldType,
            deserializeFields(BadArray, allocator, &tokens, null),
        );
    }
}
