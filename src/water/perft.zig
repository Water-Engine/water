const std = @import("std");
const water = @import("water");

const fischer: []const u8 = "benchmarks/perft/epd/fischer.epd";
const marcel: []const u8 = "benchmarks/perft/epd/marcel.epd";
const medium: []const u8 = "benchmarks/perft/epd/medium.epd";
const reduced: []const u8 = "benchmarks/perft/epd/reduced.epd";
const standard: []const u8 = "benchmarks/perft/epd/standard.epd";
const terje: []const u8 = "benchmarks/perft/epd/terje_frc.epd";

const result_filename: []const u8 = "benchmarks/perft/epd/results.txt";

const TestCase = struct {
    fen: []const u8,
    depth: usize,
    expected_nodes: usize,
};

var total_cases: usize = 0;
var total_passed: usize = 0;
var total_failed: usize = 0;
var total_nodes: u128 = 0;

/// Executes and times the test case on the given board.
///
/// Writes results to the passed writer. Assumes the board already has the position set.
fn perft(board: *water.Board, writer: *std.Io.Writer, test_case: TestCase) !void {
    std.debug.assert(try board.setFen(test_case.fen, true));
    total_cases += 1;

    const start = std.time.nanoTimestamp();
    const nodes = board.perft(test_case.depth, .{});
    const end = std.time.nanoTimestamp();

    const elapsed_float_ms = @as(f128, @floatFromInt(end - start)) / 1_000_000.0;
    const nps_float = (@as(f128, @floatFromInt(nodes)) * 1000.0) / (elapsed_float_ms + 1.0);

    const elapsed_ms: u64 = @intFromFloat(elapsed_float_ms);
    const nps: u64 = @intFromFloat(nps_float);

    if (nodes != test_case.expected_nodes) {
        try writer.print(
            "[ERROR] depth {d:<2} time {d:<5} nodes [expected: {d:<12} | actual: {d:<12}] nps {d:<9} fen {s:<87}\n",
            .{ test_case.depth, elapsed_ms, test_case.expected_nodes, nodes, nps, test_case.fen },
        );
        total_failed += 1;
    } else {
        try writer.print(
            "depth {d:<2} time {d:<5} nodes {d:<12} nps {d:<9} fen {s:<87}\n",
            .{ test_case.depth, elapsed_ms, nodes, nps, test_case.fen },
        );
        total_passed += 1;
    }

    total_nodes += nodes;
}

/// Collects the total number of tests to execute and returns the total count.
///
/// This is the first pass of the files, and also ensures all files can be accessed before dispatching.
/// Malformed files do not error as they are skipped during the real test.
/// All allocations are internal, and are the only source of failure besides file opening.
///
/// Inefficient? Of course!
fn accumulate(allocator: std.mem.Allocator, files: []const []const u8) !usize {
    var count: usize = 0;
    for (files) |file| {
        var input_file = try std.fs.cwd().openFile(file, .{ .mode = .read_only });
        defer input_file.close();

        const file_contents = try input_file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(file_contents);

        var lines = std.mem.tokenizeAny(u8, file_contents, "\n\r");
        while (lines.next()) |line| {
            var components = std.mem.tokenizeScalar(u8, line, ';');
            _ = components.next() orelse continue;

            // Now the components iterator only has depth values
            while (components.next()) |depth_case| {
                var split = std.mem.tokenizeScalar(u8, depth_case, ' ');

                // Depth entries are formatted as "D<depth> <expected>"
                const depth_str = split.next() orelse continue;
                if (depth_str.len == 1) continue;
                const expected_str = split.next() orelse continue;

                _ = std.fmt.parseInt(usize, depth_str[1..], 10) catch continue;
                _ = std.fmt.parseInt(usize, expected_str, 10) catch continue;

                count += 1;
            }
        }
    }

    return count;
}

/// Parses and fully executes the epd-style perft test cases in the format:
///
/// 4k3/8/8/8/8/8/8/4K2R b K - 0 1 ;D1 5 ;D2 75 ;D3 459 ;D4 8290 ;D5 47635 ;D6 899442
///
/// This is the second pass of the file.
///
/// Inefficient? Of course!
fn dispatch(allocator: std.mem.Allocator, case_filename: []const u8, frc: bool, writer: *std.Io.Writer, progress: *std.Progress.Node) !void {
    var child_case = progress.start(case_filename, 0);
    defer child_case.end();

    try writer.print("Running tests from '{s}'\n", .{case_filename});
    var input_file = try std.fs.cwd().openFile(case_filename, .{ .mode = .read_only });
    defer input_file.close();

    const file_contents = try input_file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(file_contents);

    var board = try water.Board.init(allocator, .{ .fischer_random = frc });
    defer board.deinit();

    // Loop through all the lines, ignoring errors along the way since we're lazy
    var lines = std.mem.tokenizeAny(u8, file_contents, "\n\r");
    while (lines.next()) |line| {
        var components = std.mem.tokenizeScalar(u8, line, ';');
        const fen = components.next() orelse continue;
        _ = board.setFen(fen, true) catch continue;

        // Now the components iterator only has depth values
        while (components.next()) |depth_case| {
            var split = std.mem.tokenizeScalar(u8, depth_case, ' ');

            // Depth entries are formatted as "D<depth> <expected>"
            const depth_str = split.next() orelse continue;
            if (depth_str.len == 1) continue;
            const expected_str = split.next() orelse continue;

            const depth = std.fmt.parseInt(usize, depth_str[1..], 10) catch continue;
            const expected = std.fmt.parseInt(usize, expected_str, 10) catch continue;

            // Since we already went past the initial set fen check, this can only fail from writing and allocating
            try perft(board, writer, .{
                .fen = fen,
                .depth = depth,
                .expected_nodes = expected,
            });
            progress.completeOne();
        }
    }

    try writer.writeByte('\n');
    try writer.flush();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var output_file = try std.fs.cwd().createFile(result_filename, .{});
    defer output_file.close();

    var buf: [0x2000]u8 = undefined;
    var file_writer = output_file.writer(&buf);
    const writer = &file_writer.interface;

    const total_tests = try accumulate(allocator, &.{
        fischer,
        marcel,
        medium,
        reduced,
        standard,
        terje,
    });

    var progress = std.Progress.start(.{
        .estimated_total_items = total_tests,
        .root_name = "Perft Suite",
    });
    defer progress.end();

    // Dispatch the tests synchronously
    const start = std.time.nanoTimestamp();
    try dispatch(allocator, fischer, true, writer, &progress);
    try dispatch(allocator, marcel, false, writer, &progress);
    try dispatch(allocator, medium, false, writer, &progress);
    try dispatch(allocator, reduced, false, writer, &progress);
    try dispatch(allocator, standard, false, writer, &progress);
    try dispatch(allocator, terje, true, writer, &progress);
    const end = std.time.nanoTimestamp();

    try writer.flush();

    // Print out the stats
    var stdout_buf: [0x100]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;

    const elapsed_s: u128 = @intCast(@divTrunc(end - start, std.time.ns_per_s));

    try stdout.print("\n\nPerft Suite Completed:\n", .{});
    try stdout.print("  Total cases:  {d}\n", .{total_cases});
    try stdout.print("    Total passed: {d}\n", .{total_passed});
    try stdout.print("    Total failed: {d}\n", .{total_failed});
    try stdout.print("  Total nodes:  {d}\n", .{total_nodes});
    try stdout.print("  Total elapsed: {d}s\n", .{elapsed_s});

    try stdout.flush();
}
