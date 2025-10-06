const std = @import("std");
const water = @import("water");

const searcher_ = @import("searcher.zig");
const parameters = @import("parameters.zig");

pub fn negamax(
    searcher: *searcher_.Searcher,
    depth: i32,
    alpha: i32,
    beta: i32,
    comptime flags: struct {
        color: water.Color,
        is_null: bool,
        node: searcher_.NodeType,
        cutnode: bool,
    },
) i32 {
    _ = searcher;
    _ = depth;
    _ = alpha;
    _ = beta;
    _ = flags;
    unreachable;
}

pub fn quiescence(
    searcher: *searcher_.Searcher,
    color: water.Color,
    alpha: i32,
    beta: i32,
) i32 {
    _ = searcher;
    _ = alpha;
    _ = beta;
    _ = color;
    unreachable;
}
