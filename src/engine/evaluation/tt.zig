const std = @import("std");
const builtin = @import("builtin");
const water = @import("water");

pub const megabytes: usize = 1 << 20;

pub var lock_global_tt = false;
pub var global_tt: TranspositionTable = undefined;

/// Max hash size for the target architecture.
///
///  Bounds from https://github.com/official-stockfish/Stockfish/blob/e18ed795f2603d6482ac18bc0a6546e2a18406ae/src/engine.cpp#L50
pub const MaxHashSize = struct {
    pub const mb_size: usize = switch (builtin.target.ptrBitWidth()) {
        64 => 33554432,
        16 => @compileError("Unsupported CPU architecture"),
        else => 2048,
    };

    pub const mb_string: []const u8 = switch (builtin.target.ptrBitWidth()) {
        64 => "33554432",
        16 => @compileError("Unsupported CPU architecture"),
        else => "2048",
    };
};

pub const Bound = enum(u2) {
    none,
    exact, // PV Nodes
    lower, // Cut Nodes
    upper, // All Nodes
};

pub const TTEntry = packed struct {
    hash: u64,
    eval: i32,
    bestmove: u16,
    flag: Bound,
    depth: u8,
    age: u6,
};

const entry_size = blk: {
    const size: usize = @sizeOf(TTEntry);
    if (size != 16) {
        @compileError("TTEntry must be 16 bytes exactly");
    }
    break :blk size;
};
const max_entries = (MaxHashSize.mb_size * megabytes) / entry_size;

/// A high performance transposition table.
pub const TranspositionTable = struct {
    allocator: std.mem.Allocator,

    data: []i128,
    entries: usize,
    mask: usize,
    age: u6,

    /// Creates a transposition table with the TT size.
    ///
    /// Passing null or an invalid value defaults to the 16MB starting size.
    pub fn init(allocator: std.mem.Allocator, size_mb: ?usize) !TranspositionTable {
        const desired_bytes = (size_mb orelse 16) * megabytes;
        var num_entries = desired_bytes / entry_size;
        num_entries = std.math.clamp(num_entries, 1, max_entries);
        num_entries = std.math.floorPowerOfTwo(usize, num_entries);

        const buf: []i128 = try allocator.alloc(i128, num_entries);
        @memset(buf, 0);

        return .{
            .allocator = allocator,
            .data = buf,
            .entries = num_entries,
            .mask = num_entries - 1,
            .age = 0,
        };
    }

    /// Frees all memory allocated by the arena.
    pub fn deinit(self: *TranspositionTable) void {
        self.allocator.free(self.data);
        self.data = &.{};
    }

    /// Reloads the table, clearing all entries and restoring age.
    ///
    /// Passing null for `size_mb` uses the previous size.
    pub fn reset(self: *TranspositionTable, size_mb: ?usize) !void {
        self.deinit();
        self.* = try init(
            self.allocator,
            size_mb orelse ((self.entries * entry_size) / megabytes),
        );
    }

    /// Clears all stored pointers in the table.
    pub fn clear(self: *TranspositionTable) void {
        @memset(self.data, 0);
    }

    /// Increments the internal age of the table.
    pub inline fn incAge(self: *TranspositionTable) void {
        self.age +%= 1;
    }

    pub inline fn index(self: *TranspositionTable, hash: u64) u64 {
        return @intCast(hash & self.mask);
    }

    pub inline fn set(self: *TranspositionTable, entry: TTEntry) void {
        const p = &self.data[self.index(entry.hash)];
        const p_val = @as(*TTEntry, @ptrCast(p)).*;

        // We overwrite entry if:
        // 1. It's empty
        // 2. New entry is exact
        // 3. Previous entry is from older search
        // 4. It is a different position
        // 5. Previous entry is from same search but has lower depth
        if (p.* == 0 or entry.flag == .exact or p_val.age != self.age or p_val.hash != entry.hash or p_val.depth <= entry.depth + 4) {
            // Wizardry, do not modify!
            _ = @atomicRmw(
                i64,
                @as(*i64, @ptrFromInt(@intFromPtr(p))),
                .Xchg,
                @as(*const i64, @ptrFromInt(@intFromPtr(&entry))).*,
                .acquire,
            );

            _ = @atomicRmw(
                i64,
                @as(*i64, @ptrFromInt(@intFromPtr(p) + 8)),
                .Xchg,
                @as(*const i64, @ptrFromInt(@intFromPtr(&entry) + 8)).*,
                .acquire,
            );
        }
    }

    /// Performs the builtin prefetch operation, if supported.
    pub inline fn prefetch(self: *TranspositionTable, hash: u64) void {
        @prefetch(&self.data[self.index(hash)], .{
            .rw = .read,
            .locality = 1,
            .cache = .data,
        });
    }

    /// Tries to retrieve the given hash from the table.
    pub inline fn get(self: *TranspositionTable, hash: u64) ?TTEntry {
        const entry: *TTEntry = @ptrCast(&self.data[self.index(hash)]);
        if (entry.flag != Bound.none and entry.hash == hash) {
            return entry.*;
        }
        return null;
    }
};

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "Transposition table usage" {
    const allocator = testing.allocator;
    var tt = try TranspositionTable.init(allocator, null);
    defer tt.deinit();

    // Create a dummy TTEntry
    const entry = TTEntry{
        .hash = 0xABCDEF1234567890,
        .eval = 42,
        .bestmove = 1234,
        .flag = .exact,
        .depth = 12,
        .age = tt.age,
    };

    // Insert the entry
    tt.set(entry);

    // Retrieve it
    const found = tt.get(entry.hash);
    try expect(found != null);

    const retrieved = found.?;
    try expectEqual(entry.hash, retrieved.hash);
    try expectEqual(entry.eval, retrieved.eval);
    try expectEqual(entry.bestmove, retrieved.bestmove);
    try expectEqual(entry.flag, retrieved.flag);
    try expectEqual(entry.depth, retrieved.depth);
    try expectEqual(entry.age, retrieved.age);

    // Test prefetch (no crash = pass)
    tt.prefetch(entry.hash);

    const old_age = tt.age;
    tt.incAge();
    try expectEqual(@as(u6, old_age +% 1), tt.age);

    // Clear and ensure it's zeroed
    tt.clear();
    var zero_count: usize = 0;
    for (tt.data) |item| {
        if (item == 0) zero_count += 1;
    }
    try expect(zero_count == tt.data.len);

    // Reset the table with a smaller size to verify resizing
    try tt.reset(1);
    try expect(tt.entries > 0);
    try expect(tt.data.len > 0);
}
