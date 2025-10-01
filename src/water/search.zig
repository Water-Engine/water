const std = @import("std");

pub const Search = struct {
    pub fn init(allocator: std.mem.Allocator) anyerror!*Search {
        const s = try allocator.create(Search);
        return s;
    }

    pub fn deinit(self: *Search) void {
        _ = self;
    }

    pub fn search() void {}
};
