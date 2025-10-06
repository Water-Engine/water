const std = @import("std");
const water = @import("water");

pub const megabytes: usize = 1 << 20;
pub const kilobytes: usize = 1 << 10;

pub const default_tt_size: usize = 16 * megabytes / @sizeOf(TTEntry);

pub var lock_global_tt = false;
pub var global_tt: TranspositionTable = undefined;

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

/// A high performance transposition table courtesy.
///
/// The TT is thread safe by design courtesy of https://github.com/SnowballSH/Avalanche
pub const TranspositionTable = struct {
    allocator: std.mem.Allocator,

    // i128 is used as the TTEntry struct has a size of 16 bytes (128 bits)
    data: std.ArrayList(i128),
    size: usize,
    age: u6,

    /// Creates a transposition table with the TT size.
    ///
    /// Passing null for `size_mb` forces a default size `default_tt_size`.
    pub fn init(allocator: std.mem.Allocator, size_mb: ?usize) !TranspositionTable {
        const desired_size = if (size_mb) |mb| mb * megabytes / @sizeOf(TTEntry) else default_tt_size;
        var tt = TranspositionTable{
            .allocator = allocator,
            .data = try std.ArrayList(i128).initCapacity(allocator, desired_size),
            .size = desired_size,
            .age = 0,
        };

        try tt.data.ensureTotalCapacity(tt.allocator, tt.size);
        tt.data.expandToCapacity();

        return tt;
    }

    /// Frees all memory allocated by the arena.
    pub fn deinit(self: *TranspositionTable) void {
        self.data.deinit(self.allocator);
    }

    /// Reloads the table, clearing all entries and restoring age.
    ///
    /// Passing null for `size_mb` forces a default size `default_tt_size`.
    pub fn reset(self: *TranspositionTable, size_mb: ?usize) !void {
        self.deinit();
        self.* = try .init(self.allocator, size_mb);
    }

    /// Clears all stored pointers in the table.
    pub fn clear(self: *TranspositionTable) void {
        for (self.data.items) |*ptr| {
            ptr.* = 0;
        }
    }

    /// Increments the internal age of the table.
    pub fn incAge(self: *TranspositionTable) void {
        self.age +%= 1;
    }

    pub fn index(self: *TranspositionTable, hash: u64) u64 {
        return @intCast(@as(u128, @intCast(hash)) * @as(u128, @intCast(self.size)) >> 64);
    }

    pub fn set(self: *TranspositionTable, entry: TTEntry) void {
        const p = &self.data.items[self.index(entry.hash)];
        const p_val: TTEntry = @as(*TTEntry, @ptrCast(p)).*;

        // We overwrite entry if:
        // 1. It's empty
        // 2. New entry is exact
        // 3. Previous entry is from older search
        // 4. It is a different position
        // 5. Previous entry is from same search but has lower depth
        if (p.* == 0 or entry.flag == .exact or p_val.age != self.age or p_val.hash != entry.hash or p_val.depth <= entry.depth + 4) {
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
    pub fn prefetch(self: *TranspositionTable, hash: u64) void {
        @prefetch(&self.data.items[self.index(hash)], .{
            .rw = .read,
            .locality = 1,
            .cache = .data,
        });
    }

    /// Tries to retrieve the given hash from the table.
    pub fn get(self: *TranspositionTable, hash: u64) ?TTEntry {
        const entry: *TTEntry = @ptrCast(&self.data.items[self.index(hash)]);
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

    // Age the table and ensure .do_age works
    const old_age = tt.age;
    tt.incAge();
    try expectEqual(@as(u6, old_age +% 1), tt.age);

    // Clear and ensure it's zeroed
    tt.clear();
    var zero_count: usize = 0;
    for (tt.data.items) |item| {
        if (item == 0) zero_count += 1;
    }
    try expect(zero_count == tt.data.items.len);

    // Reset the table with a smaller size to verify resizing
    try tt.reset(1); // 1 MB
    try expect(tt.size > 0);
    try expect(tt.data.items.len > 0);
}
