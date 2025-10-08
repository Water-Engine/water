const std = @import("std");
const water = @import("water");

/// Endgame material value, indexed by [pt][phase].
///
/// Phase is represented as index 1 for endgame and 0 for everything else.
///
/// https://www.chessprogramming.org/PeSTO%27s_Evaluation_Function
pub const material: [6][2]i32 = .{
    .{ 82, 94 },
    .{ 337, 281 },
    .{ 365, 297 },
    .{ 477, 512 },
    .{ 1025, 936 },
    .{ 0, 0 },
};

/// PeSTO PST, indexed by [pt][phase][square].
///
/// Phase is represented as index 1 for endgame and 0 for everything else.
///
/// https://www.chessprogramming.org/PeSTO%27s_Evaluation_Function
///
/// http://www.talkchess.com/forum3/viewtopic.php?f=2&t=68311&start=19
pub const pst: [6][2][64]i32 = .{
    .{
        .{
            0,   0,   0,   0,   0,   0,   0,  0,
            98,  134, 61,  95,  68,  126, 34, -11,
            -6,  7,   26,  31,  65,  56,  25, -20,
            -14, 13,  6,   21,  23,  12,  17, -23,
            -27, -2,  -5,  12,  17,  6,   10, -25,
            -26, -4,  -4,  -10, 3,   3,   33, -12,
            -35, -1,  -20, -23, -15, 24,  38, -22,
            0,   0,   0,   0,   0,   0,   0,  0,
        },
        .{
            0,   0,   0,   0,   0,   0,   0,   0,
            178, 173, 158, 134, 147, 132, 165, 187,
            94,  100, 85,  67,  56,  53,  82,  84,
            32,  24,  13,  5,   -2,  4,   17,  17,
            13,  9,   -3,  -7,  -7,  -8,  3,   -1,
            4,   7,   -6,  1,   0,   -5,  -1,  -8,
            13,  8,   8,   10,  13,  0,   2,   -7,
            0,   0,   0,   0,   0,   0,   0,   0,
        },
    },
    .{
        .{
            -167, -89, -34, -49, 61,  -97, -15, -107,
            -73,  -41, 72,  36,  23,  62,  7,   -17,
            -47,  60,  37,  65,  84,  129, 73,  44,
            -9,   17,  19,  53,  37,  69,  18,  22,
            -13,  4,   16,  13,  28,  19,  21,  -8,
            -23,  -9,  12,  10,  19,  17,  25,  -16,
            -29,  -53, -12, -3,  -1,  18,  -14, -19,
            -105, -21, -58, -33, -17, -28, -19, -23,
        },
        .{
            -58, -38, -13, -28, -31, -27, -63, -99,
            -25, -8,  -25, -2,  -9,  -25, -24, -52,
            -24, -20, 10,  9,   -1,  -9,  -19, -41,
            -17, 3,   22,  22,  22,  11,  8,   -18,
            -18, -6,  16,  25,  16,  17,  4,   -18,
            -23, -3,  -1,  15,  10,  -3,  -20, -22,
            -42, -20, -10, -5,  -2,  -20, -23, -44,
            -29, -51, -23, -15, -22, -18, -50, -64,
        },
    },
    .{
        .{
            -29, 4,  -82, -37, -25, -42, 7,   -8,
            -26, 16, -18, -13, 30,  59,  18,  -47,
            -16, 37, 43,  40,  35,  50,  37,  -2,
            -4,  5,  19,  50,  37,  37,  7,   -2,
            -6,  13, 13,  26,  34,  12,  10,  4,
            0,   15, 15,  15,  14,  27,  18,  10,
            4,   15, 16,  0,   7,   21,  33,  1,
            -33, -3, -14, -21, -13, -12, -39, -21,
        },
        .{
            -14, -21, -11, -8,  -7, -9,  -17, -24,
            -8,  -4,  7,   -12, -3, -13, -4,  -14,
            2,   -8,  0,   -1,  -2, 6,   0,   4,
            -3,  9,   12,  9,   14, 10,  3,   2,
            -6,  3,   13,  19,  7,  10,  -3,  -9,
            -12, -3,  8,   10,  13, 3,   -7,  -15,
            -14, -18, -7,  -1,  4,  -9,  -15, -27,
            -23, -9,  -23, -5,  -9, -16, -5,  -17,
        },
    },
    .{
        .{
            32,  42,  32,  51,  63, 9,  31,  43,
            27,  32,  58,  62,  80, 67, 26,  44,
            -5,  19,  26,  36,  17, 45, 61,  16,
            -24, -11, 7,   26,  24, 35, -8,  -20,
            -36, -26, -12, -1,  9,  -7, 6,   -23,
            -45, -25, -16, -17, 3,  0,  -5,  -33,
            -44, -16, -20, -9,  -1, 11, -6,  -71,
            -19, -13, 1,   17,  16, 7,  -37, -26,
        },
        .{
            13, 10, 18, 15, 12, 12,  8,   5,
            11, 13, 13, 11, -3, 3,   8,   3,
            7,  7,  7,  5,  4,  -3,  -5,  -3,
            4,  3,  13, 1,  2,  1,   -1,  2,
            3,  5,  8,  4,  -5, -6,  -8,  -11,
            -4, 0,  -5, -1, -7, -12, -8,  -16,
            -6, -6, 0,  2,  -9, -9,  -11, -3,
            -9, 2,  3,  -1, -5, -13, 4,   -20,
        },
    },
    .{
        .{
            -28, 0,   29,  12,  59,  44,  43,  45,
            -24, -39, -5,  1,   -16, 57,  28,  54,
            -13, -17, 7,   8,   29,  56,  47,  57,
            -27, -27, -16, -16, -1,  17,  -2,  1,
            -9,  -26, -9,  -10, -2,  -4,  3,   -3,
            -14, 2,   -11, -2,  -5,  2,   14,  5,
            -35, -8,  11,  2,   8,   15,  -3,  1,
            -1,  -18, -9,  10,  -15, -25, -31, -50,
        },
        .{
            -9,  22,  22,  27,  27,  19,  10,  20,
            -17, 20,  32,  41,  58,  25,  30,  0,
            -20, 6,   9,   49,  47,  35,  19,  9,
            3,   22,  24,  45,  57,  40,  57,  36,
            -18, 28,  19,  47,  31,  34,  39,  23,
            -16, -27, 15,  6,   9,   17,  10,  5,
            -22, -23, -30, -16, -16, -23, -36, -32,
            -33, -28, -22, -43, -5,  -32, -20, -41,
        },
    },
    .{
        .{
            -65, 23,  16,  -15, -56, -34, 2,   13,
            29,  -1,  -20, -7,  -8,  -4,  -38, -29,
            -9,  24,  2,   -16, -20, 6,   22,  -22,
            -17, -20, -12, -27, -30, -25, -14, -36,
            -49, -1,  -27, -39, -46, -44, -33, -51,
            -14, -14, -22, -46, -44, -30, -15, -27,
            1,   7,   -8,  -64, -43, -16, 9,   8,
            -15, 36,  12,  -54, 8,   -28, 24,  14,
        },
        .{
            -74, -35, -18, -18, -11, 15,  4,   -17,
            -12, 17,  14,  17,  17,  38,  23,  11,
            10,  17,  23,  15,  20,  45,  44,  13,
            -8,  22,  24,  27,  26,  33,  26,  3,
            -18, -4,  21,  24,  27,  23,  9,   -11,
            -19, -3,  11,  21,  23,  16,  7,   -9,
            -27, -11, 4,   13,  14,  4,   -5,  -17,
            -53, -34, -21, -11, -28, -14, -24, -43,
        },
    },
};

pub const PeSTOEval = struct {
    score_mg: i32 = 0,
    score_eg_mat: i32 = 0,
    score_eg_non_mat: i32 = 0,
};

/// Gathers data related to PeSTO's evaluation function.
///
/// Using SIMD here loses performance. See benchmark at bottom of containing file.
/// Average performance of this function is 20ns.
///
/// https://www.chessprogramming.org/PeSTO%27s_Evaluation_Function
pub fn pestoEval(board: *const water.Board) PeSTOEval {
    var mg: i32 = 0;
    var eg_material: i32 = 0;
    var eg_non_material: i32 = 0;

    for (board.mailbox, 0..) |piece, i| {
        if (piece == .none) continue;

        const pt_idx = piece.asType().index();

        if (piece.color().isWhite()) {
            mg += material[pt_idx][0];
            mg += pst[pt_idx][0][i ^ 56];
            eg_material += material[pt_idx][1];
            eg_non_material += pst[pt_idx][1][i ^ 56];
        } else if (piece.color().isBlack()) {
            mg -= material[pt_idx][0];
            mg -= pst[pt_idx][0][i];
            eg_material -= material[pt_idx][1];
            eg_non_material -= pst[pt_idx][1][i];
        }
    }

    return .{
        .score_mg = mg,
        .score_eg_mat = eg_material,
        .score_eg_non_mat = eg_non_material,
    };
}

// ================ TESTING ================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "PeSTO evaluation" {
    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    const expected_starting: [3]i32 = .{ 0, 0, 0 };
    const actual_starting = pestoEval(board);
    try expectEqual(expected_starting[0], actual_starting.score_mg);
    try expectEqual(expected_starting[1], actual_starting.score_eg_mat);
    try expectEqual(expected_starting[2], actual_starting.score_eg_non_mat);

    try expect(try board.setFen("8/3r4/pr1Pk1p1/8/7P/6P1/3R3K/5R2 w - - 20 80", true));
    const expected_mid: [3]i32 = .{ 198, 94, 9 };
    const actual_mid = pestoEval(board);
    try expectEqual(expected_mid[0], actual_mid.score_mg);
    try expectEqual(expected_mid[1], actual_mid.score_eg_mat);
    try expectEqual(expected_mid[2], actual_mid.score_eg_non_mat);

    try expect(try board.setFen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1 ", true));
    const expected_end: [3]i32 = .{ 70, 0, 31 };
    const actual_end = pestoEval(board);
    try expectEqual(expected_end[0], actual_end.score_mg);
    try expectEqual(expected_end[1], actual_end.score_eg_mat);
    try expectEqual(expected_end[2], actual_end.score_eg_non_mat);
}

test "PeSTO evaluation benchmark" {
    // Hack to skip the test without other errors
    if (true) return error.SkipZigTest;

    const allocator = testing.allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();

    const pestoSimd = struct {
        /// The PeSTO evaluation function from https://www.chessprogramming.org/PeSTO%27s_Evaluation_Function
        ///
        /// Implemented using SIMD
        pub fn pestoSimd(b: *const water.Board) PeSTOEval {
            const Vec = @Vector(4, i32);

            // 1. Calculate Material Score
            var mg_material_score: i32 = 0;
            var eg_material_score: i32 = 0;
            inline for (water.PieceType.all) |pt| {
                const pt_idx = pt.index();
                const white_count: i32 = @intCast(b.pieces(.white, pt).count());
                const black_count: i32 = @intCast(b.pieces(.black, pt).count());
                mg_material_score += material[pt_idx][0] * (white_count - black_count);
                eg_material_score += material[pt_idx][1] * (white_count - black_count);
            }

            // 2. Calculate PST Score
            var mg_pst_vec_sum: Vec = @splat(0);
            var eg_pst_vec_sum: Vec = @splat(0);
            var mg_pst_scalar_rem: i32 = 0;
            var eg_pst_scalar_rem: i32 = 0;

            inline for (water.PieceType.all) |pt| {
                const pt_idx = pt.index();

                // Chunk white for efficient computation
                var bb_white = b.pieces(.white, pt);
                while (bb_white.count() >= 4) {
                    const @"i0" = bb_white.popLsb().index();
                    const @"i1" = bb_white.popLsb().index();
                    const @"i2" = bb_white.popLsb().index();
                    const @"i3" = bb_white.popLsb().index();
                    mg_pst_vec_sum += Vec{
                        pst[pt_idx][0][@"i0" ^ 56], pst[pt_idx][0][@"i1" ^ 56],
                        pst[pt_idx][0][@"i2" ^ 56], pst[pt_idx][0][@"i3" ^ 56],
                    };
                    eg_pst_vec_sum += Vec{
                        pst[pt_idx][1][@"i0" ^ 56], pst[pt_idx][1][@"i1" ^ 56],
                        pst[pt_idx][1][@"i2" ^ 56], pst[pt_idx][1][@"i3" ^ 56],
                    };
                }

                // Scalar remainder handling for white remaining
                while (bb_white.nonzero()) {
                    const i = bb_white.popLsb().index();
                    mg_pst_scalar_rem += pst[pt_idx][0][i ^ 56];
                    eg_pst_scalar_rem += pst[pt_idx][1][i ^ 56];
                }

                // Chunk black for efficient computation
                var bb_black = b.pieces(.black, pt);
                while (bb_black.count() >= 4) {
                    const @"i0" = bb_black.popLsb().index();
                    const @"i1" = bb_black.popLsb().index();
                    const @"i2" = bb_black.popLsb().index();
                    const @"i3" = bb_black.popLsb().index();
                    mg_pst_vec_sum -= Vec{
                        pst[pt_idx][0][@"i0"], pst[pt_idx][0][@"i1"],
                        pst[pt_idx][0][@"i2"], pst[pt_idx][0][@"i3"],
                    };
                    eg_pst_vec_sum -= Vec{
                        pst[pt_idx][1][@"i0"], pst[pt_idx][1][@"i1"],
                        pst[pt_idx][1][@"i2"], pst[pt_idx][1][@"i3"],
                    };
                }

                // Scalar remainder handling for black remaining
                while (bb_black.nonzero()) {
                    const i = bb_black.popLsb().index();
                    mg_pst_scalar_rem -= pst[pt_idx][0][i];
                    eg_pst_scalar_rem -= pst[pt_idx][1][i];
                }
            }

            // 3. Horizontal Sum and combine with scalar remainder
            const mg_pst_from_vec = @reduce(.Add, mg_pst_vec_sum);
            const eg_pst_from_vec = @reduce(.Add, eg_pst_vec_sum);

            const mg_pst_score = mg_pst_from_vec + mg_pst_scalar_rem;
            const eg_pst_score = eg_pst_from_vec + eg_pst_scalar_rem;

            // 4. Return Final Scores
            return .{
                .score_mg = mg_material_score + mg_pst_score,
                .score_eg_mat = eg_material_score,
                .score_eg_non_mat = eg_pst_score,
            };
        }
    }.pestoSimd;

    const pestoReference = struct {
        /// The PeSTO evaluation function from https://www.chessprogramming.org/PeSTO%27s_Evaluation_Function
        ///
        /// Used in https://github.com/SnowballSH/Avalanche
        pub fn pestoReference(b: *const water.Board) PeSTOEval {
            var mg: i32 = 0;
            var eg_material: i32 = 0;
            var eg_non_material: i32 = 0;

            for (b.mailbox, 0..) |piece, i| {
                if (piece == .none) continue;

                const pt_idx = piece.asType().index();

                if (piece.color().isWhite()) {
                    mg += material[pt_idx][0];
                    mg += pst[pt_idx][0][i ^ 56];
                    eg_material += material[pt_idx][1];
                    eg_non_material += pst[pt_idx][1][i ^ 56];
                } else if (piece.color().isBlack()) {
                    mg -= material[pt_idx][0];
                    mg -= pst[pt_idx][0][i];
                    eg_material -= material[pt_idx][1];
                    eg_non_material -= pst[pt_idx][1][i];
                }
            }

            return .{
                .score_mg = mg,
                .score_eg_mat = eg_material,
                .score_eg_non_mat = eg_non_material,
            };
        }
    }.pestoReference;

    const pestoBranched = struct {
        /// The PeSTO evaluation function opting for simd for large positions only
        pub fn pestoBranched(b: *const water.Board) PeSTOEval {
            return if (b.occ().count() > 10)
                pestoSimd(b)
            else
                pestoReference(b);
        }
    }.pestoBranched;

    // Random FEN strings from http://bernd.bplaced.net/fengenerator/fengenerator.html
    const short_fens = [_][]const u8{
        "8/4k3/8/2K5/8/P5P1/6B1/8 w - - 0 1",
        "8/2k5/6P1/3K2p1/6n1/8/8/8 w - - 0 1",
        "6Q1/8/7k/2b5/3N4/8/8/5K2 w - - 0 1",
        "8/3P1p2/3b4/8/5k2/8/3K4/8 w - - 0 1",
        "1N6/4p3/6K1/8/8/4Bk2/8/8 w - - 0 1",
        "8/8/K7/8/B7/Q7/6k1/7b w - - 0 1",
        "8/8/4P3/4kp2/1K6/8/1p6/8 w - - 0 1",
        "8/8/1k1n4/5p2/5p2/8/4K3/8 w - - 0 1",
        "8/1p6/7K/8/3k4/P7/1r6/8 w - - 0 1",
        "6K1/p7/p7/6k1/8/8/4p3/8 w - - 0 1",
    };

    const long_fens = [_][]const u8{
        "r1N1R3/pPb3R1/q4BNP/PPpK4/b1rP2P1/pP2Pn1n/k1ppp1pp/5B1Q w - - 0 1",
        "R6N/RbBp1Pp1/1p1n1k1p/1P1B2qp/P1PP2Pn/1p2NP1K/1p2pPQ1/1r2b1r1 w - - 0 1",
        "b3NBK1/R4pp1/1PqPR1NP/4p3/2rPPpnb/2k1PP1P/p1p2prp/nQ5B w - - 0 1",
        "2q2n1b/p1P2BQP/p1PN1p1K/5PP1/N1Rprppn/2B3P1/1pPpb2P/1R4rk w - - 0 1",
        "8/1pP2bRP/P1rppp1P/PP1kp2p/p1N2nNb/1PqPnp1Q/1Br4R/3B3K w - - 0 1",
        "7K/1N1Qpr2/p1PB1rPk/pPp5/q2n1Rpp/P1PPPbpB/p1P5/bR1N3n w - - 0 1",
        "BR1n3Q/1P1pbr1P/Pp2p3/1NrpPP2/p2PR2p/Bn1ppk2/KP5P/1N2q2b w - - 0 1",
        "1R1q4/n2bP1rR/1BNP1n1p/PPpp3p/kP3PP1/br4p1/BpP1p2p/1K2QN2 w - - 0 1",
        "2N3N1/pnR2BP1/P1b2PpQ/1p1R1PKP/q3P2p/1Pb1nr1p/k1pp1pP1/4B1r1 w - - 0 1",
        "B6N/QP2pPbR/2q1p2p/2PRp2p/Pk2p1r1/nP1PPr2/1Kpp2PN/1bB3n1 w - - 0 1",
    };

    // Compare the simd and reference for correctness
    for (long_fens, short_fens) |long_fen, short_fen| {
        // Long fen verification
        try expect(try board.setFen(long_fen, true));
        const expected_long = pestoReference(board);
        const actual_long = pestoSimd(board);

        try expect(std.meta.eql(expected_long, actual_long));

        // Short fen verification
        try expect(try board.setFen(short_fen, true));
        const expected_short = pestoReference(board);
        const actual_short = pestoSimd(board);

        try expect(std.meta.eql(expected_short, actual_short));
    }

    var simd_times: [long_fens.len + short_fens.len]i128 = @splat(0);
    var simd_sum: i128 = 0;
    var ref_times: [long_fens.len + short_fens.len]i128 = @splat(0);
    var ref_sum: i128 = 0;
    var branched_times: [long_fens.len + short_fens.len]i128 = @splat(0);
    var branched_sum: i128 = 0;

    // Time the execution of each function
    for (long_fens ++ short_fens, 0..) |fen, i| {
        _ = try board.setFen(fen, true);

        const s_simd = std.time.nanoTimestamp();
        _ = pestoSimd(board);
        const e_simd = std.time.nanoTimestamp();

        const s_ref = std.time.nanoTimestamp();
        _ = pestoReference(board);
        const e_ref = std.time.nanoTimestamp();

        const s_branched = std.time.nanoTimestamp();
        _ = pestoBranched(board);
        const e_branched = std.time.nanoTimestamp();

        simd_times[i] = e_simd - s_simd;
        simd_sum += simd_times[i];
        ref_times[i] = e_ref - s_ref;
        ref_sum += ref_times[i];
        branched_times[i] = e_branched - s_branched;
        branched_sum += branched_times[i];
    }

    // Performance information
    const average_simd_ns = @divTrunc(simd_sum, simd_times.len);
    const average_ref_ns = @divTrunc(ref_sum, ref_times.len);
    const average_branched_ns = @divTrunc(branched_sum, branched_times.len);
    std.debug.print("SIMD: {d}ns\nBranched: {d}ns\nReference: {d}ns\n", .{
        average_simd_ns,
        average_branched_ns,
        average_ref_ns,
    });
}
