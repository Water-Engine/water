const std = @import("std");

pub const Search = struct {
    allocator: std.mem.Allocator,

    writer: *std.Io.Writer,

    pub fn init(allocator: std.mem.Allocator, writer: *std.Io.Writer) anyerror!*Search {
        const searcher = try allocator.create(Search);
        searcher.* = .{
            .allocator = allocator,
            .writer = writer,
        };

        return searcher;
    }

    pub fn deinit(self: *Search) void {
        _ = self;
    }

    pub fn search(self: *Search) anyerror!void {
        try self.writer.print("Hello from a thread somewhere in the background!", .{});
        std.Thread.sleep(1_000_000);
    }
};
