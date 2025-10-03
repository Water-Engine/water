//! A collection of comptime type validators.

const std = @import("std");

/// Validates the given Fn's parameter types against the Expected types.
///
/// The given message is shown as a compile error if an error is encountered.
pub fn validateParameterTypes(comptime Fn: type, comptime expected_param_types: []const type, comptime msg: []const u8) void {
    const fn_type = @typeInfo(Fn);
    switch (fn_type) {
        .@"fn" => |f| {
            if (f.params.len != expected_param_types.len) @compileError(msg);
            inline for (expected_param_types, f.params) |Expected, actual| {
                if (actual.type) |Actual| {
                    if (Actual != Expected) @compileError(msg);
                } else @compileError(msg);
            }
        },
        else => @compileError(msg),
    }
}

/// Validates the given Fn's return type against the Expected type.
///
/// The given message is shown as a compile error if an error is encountered.
pub fn validateReturnType(comptime Fn: type, comptime Expected: type, comptime msg: []const u8) void {
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
pub fn validateField(
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

/// A valid Command type is a struct that must expose:
/// - A constant (comptime) string declaration: `command_name: []const u8`
/// - A function: `deserialize(std.mem.Allocator, *std.mem.TokenIterator(u8, .any)) anyerror!Command`
/// - Any number of fields to deserialize into, or none if you so choose
pub fn validateCommand(comptime Command: type) void {
    const info = @typeInfo(Command);

    // Validate the presence of the comptime command_name
    const field_msg: []const u8 = @typeName(Command) ++ " must have field 'command_name' of type '[]const u8'";
    switch (info) {
        .@"struct" => {
            if (!@hasDecl(Command, "command_name")) @compileError(field_msg);
            if (@TypeOf(Command.command_name) != []const u8) @compileError(field_msg);
        },
        else => @compileError(@typeName(Command) ++ " must be a struct"),
    }

    // Validate the deserialize function
    const fn_msg: []const u8 = @typeName(Command) ++ " must have function of type 'deserialize(std.mem.Allocator, *std.mem.TokenIterator(u8, .any)) anyerror!Command'";
    if (!@hasDecl(Command, "deserialize")) @compileError(fn_msg);

    validateParameterTypes(
        @TypeOf(Command.deserialize),
        &[_]type{ std.mem.Allocator, *std.mem.TokenIterator(u8, .any) },
        fn_msg,
    );

    validateReturnType(@TypeOf(Command.deserialize), anyerror!Command, fn_msg);
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

test "Command validation" {
    const TestCommand = struct {
        const Self = @This();

        const command_name: []const u8 = "go";

        pub fn deserialize(
            allocator: std.mem.Allocator,
            tokens: *std.mem.TokenIterator(u8, .any),
        ) anyerror!Self {
            _ = allocator;
            _ = tokens;
        }
    };

    validateCommand(TestCommand);
}
