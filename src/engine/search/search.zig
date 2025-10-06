const std = @import("std");
const water = @import("water");

const searcher_ = @import("searcher.zig");
const parameters = @import("parameters.zig");

const tt = @import("../evaluation/tt.zig");
const evaluator = @import("../evaluation/evaluator.zig");
const orderer = @import("../evaluation/orderer.zig");

pub fn negamax(
    searcher: *searcher_.Searcher,
    depth: i32,
    alpha: i32,
    beta: i32,
    comptime flags: struct {
        is_null: bool,
        node: searcher_.NodeType,
        cutnode: bool,
    },
) i32 {
    const color = searcher.search_board.side_to_move;
    var alpha_val = alpha;
    var beta_val = beta;
    var depth_val = depth;

    searcher.pv_size[searcher.ply] = 0;

    // Stop searching if time is up. Only check every 2048 nodes
    if (searcher.nodes & 2047 == 0 and searcher.should_stop.load(.acquire)) {
        return 0;
    }

    searcher.seldepth = @intCast(@max(searcher.seldepth, searcher.ply));
    const is_root = flags.node == .root;
    const on_pv: bool = flags.node != .non_pv;

    // Check for a ply overflow
    if (searcher.ply == searcher_.max_ply) {
        return evaluator.evaluate(searcher.search_board, false);
    }

    // Check extension
    const in_check = searcher.search_board.inCheck(.{});
    if (in_check) depth_val += 1;

    // Prevent Horizon effect at 0 depth
    if (depth_val == 0) {
        return quiescence(searcher, alpha_val, beta_val);
    }

    // Distance to mate
    if (!is_root) {
        const r_alpha = @max(-evaluator.mate_score + @as(i32, @intCast(searcher.ply)), alpha_val);
        const r_beta = @max(evaluator.mate_score - @as(i32, @intCast(searcher.ply)) - 1, beta_val);

        if (r_alpha >= r_beta) {
            return r_alpha;
        }
    }

    searcher.nodes += 1;

    // Move generation and draw checking to save recomputing
    var movelist = water.movegen.Movelist{};
    water.movegen.legalmoves(searcher.search_board, &movelist, .{});
    const hm_draw = water.arbiter.halfmove(searcher.search_board, &movelist);
    if (!is_root and (hm_draw != null or searcher.search_board.isRepetition(1))) {
        return 0;
    }

    // Transposition table probing
    var hashmove = water.Move.init();
    var tthit = false;
    var tt_eval: i32 = 0;
    const maybe_entry = tt.global_tt.get(searcher.search_board.key);
    if (maybe_entry) |entry| {
        tthit = true;
        tt_eval = entry.eval;
        if (tt_eval > evaluator.mate_score - evaluator.max_mate and tt_eval <= evaluator.mate_score) {
            tt_eval -= @intCast(searcher.ply);
        } else if (tt_eval < -evaluator.mate_score + evaluator.max_mate and tt_eval >= -evaluator.mate_score) {
            tt_eval += @intCast(searcher.ply);
        }

        // Only set the internal bestmove to the tt move at the root
        hashmove = water.Move.fromMove(entry.bestmove);
        if (is_root) {
            searcher.best_move = hashmove;
        }

        if (!flags.is_null and !on_pv and !is_root and entry.depth >= depth_val) {
            const last = searcher.search_board.previous_states.getLastOrNull();
            const fifty = if (last) |l| l.half_moves else 0;
            if (fifty < 90 and (depth_val == 0 or !on_pv)) {
                switch (entry.flag) {
                    .exact => return tt_eval,
                    .lower => alpha_val = @max(alpha_val, tt_eval),
                    .upper => beta_val = @min(beta_val, tt_eval),
                    .none => {},
                }

                if (alpha_val >= beta_val) return tt_eval;
            }
        }
    }

    const static_eval = blk: {
        if (in_check) {
            break :blk -evaluator.mate_score + @as(i32, @intCast(searcher.ply));
        } else if (tthit) {
            break :blk maybe_entry.?.eval;
        } else if (flags.is_null) {
            break :blk -searcher.history.evaluations[searcher.ply - 1];
        } else if (searcher.exclude_move[searcher.ply].move != 0) {
            break :blk searcher.history.evaluations[searcher.ply];
        } else {
            break :blk evaluator.evaluate(searcher.search_board, false);
        }
    };
    var best_score: i32 = static_eval;
    var low_estimate: i32 = -evaluator.mate_score - 1;

    searcher.history.evaluations[searcher.ply] = static_eval;

    const improving = !in_check and searcher.ply >= 2 and static_eval > searcher.history.evaluations[searcher.ply - 2];
    const has_non_pawns = searcher.search_board.nonPawnMaterial(searcher.search_board.side_to_move) != 0;
    var last_move = if (searcher.ply > 0) searcher.history.moves[searcher.ply - 1] else water.Move.init();
    var three_moves_ago = if (searcher.ply > 2) searcher.history.moves[searcher.ply - 3] else water.Move.init();

    // Perform a variation of internal iterative deepening
    // https://talkchess.com/forum3/viewtopic.php?f=7&t=74769&sid=85d340ce4f4af0ed413fba3188189cd1
    if (depth_val >= 3 and !in_check and !tthit and searcher.exclude_move[searcher.ply].move == 0 and (on_pv or flags.cutnode)) {
        depth_val -= 1;
    }

    // All pruning
    if (!in_check and !on_pv and searcher.exclude_move[searcher.ply].move == 0) {
        low_estimate = if (!tthit or maybe_entry.?.flag == .lower) static_eval else maybe_entry.?.eval;

        // Reverse futility pruning
        if (@abs(beta_val) < evaluator.mate_score - evaluator.max_mate and depth_val <= parameters.rfp_depth) {
            var n = depth_val * parameters.rfp_multiplier;
            if (improving) {
                n -= parameters.rfp_improving_deduction;
            }

            if (static_eval - n >= beta_val) return beta_val;
        }

        // Null move pruning
        var nmp_static_eval = static_eval;
        if (improving) {
            nmp_static_eval += parameters.nmp_improving_margin;
        }

        if (!flags.is_null and depth_val >= 3 and searcher.ply >= searcher.nmp_min_ply and nmp_static_eval >= beta_val and has_non_pawns) {
            var r: usize = parameters.nmp_base + @divTrunc(@as(usize, @intCast(depth_val)), parameters.nmp_depth_divisor);
            r += @min(4, @as(usize, @intCast(@divTrunc(static_eval - beta_val, parameters.nmp_beta_divisor))));
            r = @min(r, @as(usize, @intCast(depth_val)));

            searcher.ply += 1;
            searcher.search_board.makeNullMove();
            var null_score = -negamax(searcher, depth_val - @as(i32, @intCast(r)), -beta_val, -beta_val + 1, .{
                .cutnode = !flags.cutnode,
                .is_null = true,
                .node = .non_pv,
            });
            searcher.ply -= 1;
            searcher.search_board.unmakeNullMove();

            if (searcher.should_stop.load(.acquire)) return 0;

            if (null_score >= beta_val) {
                if (null_score >= evaluator.mate_score - evaluator.max_mate) {
                    null_score = beta_val;
                }

                if (depth_val < 12 or searcher.nmp_min_ply > 0) {
                    return null_score;
                }

                searcher.nmp_min_ply = searcher.ply + @divFloor(@as(usize, @intCast(depth_val)) - r * 3, 4);
                const verify_score = negamax(searcher, depth_val, beta_val - 1, beta_val, .{
                    .cutnode = false,
                    .is_null = false,
                    .node = .non_pv,
                });
                searcher.nmp_min_ply = 0;

                if (searcher.should_stop.load(.acquire)) return 0;
                if (verify_score >= beta_val) return verify_score;
            }
        }

        // Razoring
        if (depth_val <= 3 and static_eval - parameters.razoring_base + parameters.razoring_margin * depth_val < alpha_val) {
            return quiescence(searcher, alpha_val, beta_val);
        }
    }

    // Clean up movelist generation from earlier and prep quiets
    var quiets = water.movegen.Movelist{};
    searcher.killers[searcher.ply + 1][0] = .init();
    searcher.killers[searcher.ply + 1][1] = .init();

    if (movelist.size == 0) {
        if (in_check) {
            return -evaluator.mate_score + @as(i32, @intCast(searcher.ply));
        } else {
            return 0;
        }
    }
    orderer.orderMoves(searcher, &movelist, hashmove, flags.is_null);

    // Move iteration
    var best_move = water.Move.init();
    best_score = -evaluator.mate_score + @as(i32, @intCast(searcher.ply));
    var skip_quiet = false;
    var legals: usize = 0;

    for (movelist.moves[0..movelist.size], 0..) |move, i| {
        if (move.orderByMove(searcher.exclude_move[searcher.ply]) == .eq) {
            continue;
        }

        const is_capture = searcher.search_board.isCapture(move);
        const is_killer = (move.orderByMove(searcher.killers[searcher.ply][0]) == .eq) or (move.orderByMove(searcher.killers[searcher.ply][1]) == .eq);

        if (!is_capture) {
            quiets.add(move);
        }

        const is_important = is_killer or move.typeOf(water.MoveType) == .promotion;
        if (skip_quiet and !is_capture and !is_important) continue;

        if (!is_root and i > 1 and !in_check and !on_pv and has_non_pawns) {
            if (!is_important and !is_capture and depth_val <= 5) {
                var late = 4 + depth_val * depth_val;
                if (improving) {
                    late += 1 + @divTrunc(depth_val, 2);
                }

                if (quiets.size > @as(usize, @intCast(late))) {
                    skip_quiet = true;
                }
            }
        }

        legals += 1;
        var extension: i32 = 0;

        // Singular extension
        // zig fmt: off
        if (searcher.ply > 0
            and !is_root
            and searcher.ply < depth_val * 2
            and depth_val >= 7
            and tthit
            and maybe_entry.?.flag != .upper
            and !evaluator.mateish(maybe_entry.?.eval)
            and hashmove.orderByMove(move) == .eq
            and maybe_entry.?.depth >= depth_val - 3
        ) {
        // zig fmt: on
            const margin = depth_val;
            const singular_beta = @max(tt_eval - margin, -evaluator.mate_score + evaluator.max_mate);

            searcher.exclude_move[searcher.ply] = hashmove;
            const singular_score = negamax(searcher, @divFloor(depth_val - 1, 2), singular_beta - 1, singular_beta, .{
                .cutnode = flags.cutnode,
                .is_null = true,
                .node = .non_pv,
            });
            searcher.exclude_move[searcher.ply] = .init();

            if (singular_score < singular_beta) {
                extension = 1;
            } else if (singular_beta >= beta_val) {
                return singular_beta;
            } else if (tt_eval >= beta_val) {
                extension = -2;
            } else if (flags.cutnode) {
                extension = -1;
            }
        } else if (on_pv and !is_root and searcher.ply < @as(usize, @intCast(depth_val)) * 2) {
            // Recapture extension
            if (is_capture and ((searcher.search_board.isCapture(last_move) and move.to().order(
                last_move.to(),
            ) == .eq) or searcher.search_board.isCapture(three_moves_ago) and move.to().order(
                three_moves_ago.to(),
            ) == .eq)) {
                extension = 1;
            }
        }

        const new_depth = @as(usize, @intCast(depth_val + extension - 1));

        searcher.history.moves[searcher.ply] = move;
        searcher.history.moved_pieces[searcher.ply] = searcher.search_board.at(water.Piece, move.from());
        searcher.ply += 1;
        searcher.search_board.makeMove(move, .{});

        tt.global_tt.prefetch(searcher.search_board.key);

        var score: i32 = 0;
        const min_lmr_move: usize = if (on_pv) 5 else 3;
        const is_winning_capture = is_capture and movelist.moves[i].score >= orderer.winning_capture_bonus - 200;
        var do_full_search = false;

        if (on_pv and legals == 1) {
            score = -negamax(searcher, @intCast(new_depth), -beta_val, -alpha_val, .{
                .cutnode = false,
                .is_null = false,
                .node = .pv,
            });
        } else {
            if (!in_check and depth_val >= 3 and i >= min_lmr_move and (!is_capture or !is_winning_capture)) {
                // Late move reduction
                var reduction = searcher_.quiet_lmr[@min(63, @as(usize, @intCast(depth_val)))][@min(63, i)];
                reduction -= 1;

                if (improving) reduction -= 1;
                if (!on_pv) reduction += 1;

                reduction -= @divTrunc(
                    searcher.history.heuristic[color.index()][move.from().index()][move.to().index()],
                    6144,
                );

                const rd: usize = @intCast(std.math.clamp(@as(i32, @intCast(new_depth)) - reduction, 1, new_depth + 1));
                score -= negamax(searcher, @intCast(rd), -alpha_val - 1, -alpha_val, .{
                    .cutnode = true,
                    .is_null = false,
                    .node = .non_pv,
                });

                do_full_search = score > alpha_val and rd < new_depth;
            } else {
                do_full_search = !on_pv or i > 0;
            }

            if (do_full_search) {
                score = -negamax(searcher, @intCast(new_depth), -alpha_val - 1, -alpha_val, .{
                    .cutnode = !flags.cutnode,
                    .is_null = false,
                    .node = .non_pv,
                });
            }

            if (on_pv and ((score > alpha_val and score < beta_val) or i == 0)) {
                score = -negamax(searcher, @intCast(new_depth), -beta_val, -alpha_val, .{
                    .cutnode = false,
                    .is_null = false,
                    .node = .pv,
                });
            }
        }

        searcher.ply -= 1;
        searcher.search_board.unmakeMove(move);

        // Check for stopping condition before ab pruning
        if (searcher.should_stop.load(.acquire)) return 0;
        if (score > best_score) {
            best_score = score;
            best_move = move;

            if (is_root) {
                searcher.best_move = move;
            }

            if (!flags.is_null) {
                searcher.pv[searcher.ply][0] = move;
                std.mem.copyForwards(
                    water.Move,
                    searcher.pv[searcher.ply][1..(searcher.pv_size[searcher.ply + 1] + 1)],
                    searcher.pv[searcher.ply + 1][0..(searcher.pv_size[searcher.ply + 1])],
                );
                searcher.pv_size[searcher.ply] = searcher.pv_size[searcher.ply + 1] + 1;
            }

            if (score > alpha_val) {
                alpha_val = score;

                if (alpha_val >= beta_val) {
                    break;
                }
            }
        }
    }

    if (alpha_val > beta_val and !searcher.search_board.isCapture(
        best_move,
    ) and best_move.typeOf(
        water.MoveType,
    ) != .promotion) {
        const temp = searcher.killers[searcher.ply][0];
        if (temp.orderByMove(best_move) == .eq) {
            searcher.killers[searcher.ply][0] = best_move;
            searcher.killers[searcher.ply][1] = temp;
        }

        const adj: i32 = @min(1536, (if (static_eval <= alpha_val) depth_val + 1 else depth_val) * 384 - 384);
        if (!flags.is_null and searcher.ply >= 1) {
            const last = searcher.history.moves[searcher.ply - 1];
            searcher.counter_moves[color.index()][last.from().index()][last.to().index()] = best_move;
        }

        const bm = best_move;
        const max_history: i32 = 16384;
        for (quiets.moves[0..quiets.size]) |move| {
            // HIstory heuristic
            const is_best = move.orderByMove(bm) == .eq;
            const hist = searcher.history.heuristic[color.index()][move.from().index()][move.to().index()];
            if (is_best) {
                searcher.history.heuristic[color.index()][move.from().index()][move.to().index()] += adj - @divTrunc(hist, max_history);
            } else {
                searcher.history.heuristic[color.index()][move.from().index()][move.to().index()] += -adj - @divTrunc(hist, max_history);
            }

            // Continuation heuristic
            if (!flags.is_null and searcher.ply >= 1) {
                const plies: [3]usize = .{ 0, 1, 3 };
                for (plies) |plies_ago| {
                    if (searcher.ply >= plies_ago + 1) {
                        const prev = searcher.history.moves[searcher.ply - plies_ago - 1];
                        if (!prev.valid()) continue;

                        const cont = searcher.continuation[searcher.history.moved_pieces[searcher.ply - plies_ago - 1].index()][prev.to().index()][move.from().index()][move.to().index()] * adj;
                        if (is_best) {
                            searcher.continuation[searcher.history.moved_pieces[searcher.ply - plies_ago - 1].index()][prev.to().index()][move.from().index()][move.to().index()] += adj - @divTrunc(
                                cont,
                                max_history,
                            );
                        } else {
                            searcher.continuation[searcher.history.moved_pieces[searcher.ply - plies_ago - 1].index()][prev.to().index()][move.from().index()][move.to().index()] += -adj - @divTrunc(
                                cont,
                                max_history,
                            );
                        }
                    }
                }
            }
        }
    }

    // Transposition table update
    if (!skip_quiet and searcher.exclude_move[searcher.ply].move == 0) {
        const tt_flag: tt.Bound = blk: {
            if (best_score >= beta_val) {
                break :blk .lower;
            } else if (alpha_val != alpha) {
                break :blk .exact;
            } else break :blk .upper;
        };

        tt.global_tt.set(.{
            .eval = best_score,
            .bestmove = best_move.move,
            .flag = tt_flag,
            .depth = @intCast(depth_val),
            .hash = searcher.search_board.key,
            .age = tt.global_tt.age,
        });
    }

    return best_score;
}

pub fn quiescence(
    searcher: *searcher_.Searcher,
    alpha: i32,
    beta: i32,
) i32 {
    var alpha_val = alpha;
    const beta_val = beta;

    // Stop searching if time is up. Only check every 2048 nodes
    if (searcher.nodes & 2047 == 0 and searcher.should_stop.load(.acquire)) {
        return 0;
    }

    searcher.pv_size[searcher.ply] = 0;

    // Check for material draw and ply overflow
    if (water.arbiter.insufficientMaterial(searcher.search_board)) {
        return 0;
    } else if (searcher.ply == searcher_.max_ply) {
        return evaluator.evaluate(searcher.search_board, false);
    }

    searcher.nodes += 1;
    const in_check = searcher.search_board.inCheck(.{});

    var best_score = -evaluator.mate_score + @as(i32, @intCast(searcher.ply));
    var static_eval = best_score;
    if (!in_check) {
        static_eval = evaluator.evaluate(searcher.search_board, false);
        best_score = static_eval;

        // Standpat pruning
        if (best_score >= beta_val) {
            return beta_val;
        } else if (best_score > alpha_val) {
            alpha_val = best_score;
        }
    }

    // Transposition table probing
    var hashmove = water.Move.init();
    if (tt.global_tt.get(searcher.search_board.key)) |entry| {
        hashmove = water.Move.fromMove(entry.bestmove);
        if (entry.flag == .exact) {
            return entry.eval;
        } else if (entry.flag == .lower and entry.eval >= beta_val) {
            return entry.eval;
        } else if (entry.flag == .upper and entry.eval <= alpha_val) {
            return entry.eval;
        }
    }

    // Move generation & ordering
    var movelist = water.movegen.Movelist{};
    if (in_check) {
        // Generate all legal moves in check and check for checkmate
        water.movegen.legalmoves(searcher.search_board, &movelist, .{});
        if (movelist.empty()) {
            return -evaluator.mate_score + @as(i32, @intCast(searcher.ply));
        }
    } else {
        water.movegen.legalmoves(searcher.search_board, &movelist, .{ .gen_type = .quiet });
    }
    orderer.orderMoves(searcher, &movelist, hashmove, false);

    // Iterate through the sorted moves
    for (movelist.moves[0..movelist.size], 0..) |move, i| {
        const is_capture = searcher.search_board.isCapture(move);

        // SEE pruning
        if (is_capture and i > 0) {
            if (move.score < orderer.winning_capture_bonus - 2048) {
                continue;
            }
        }

        // Update the searcher's state
        searcher.history.moves[searcher.ply] = move;
        searcher.history.moved_pieces[searcher.ply] = searcher.search_board.at(water.Piece, move.from());
        searcher.ply += 1;

        // Play the move and prefetch the hash for the next iteration
        searcher.search_board.makeMove(move, .{});
        tt.global_tt.prefetch(searcher.search_board.key);
        const score = -quiescence(searcher, -beta_val, -alpha_val);
        searcher.ply -= 1;
        searcher.search_board.unmakeMove(move);

        // Check for a stop signal out of the recursive call before pruning
        if (searcher.should_stop.load(.acquire)) return 0;

        if (score > best_score) {
            best_score = score;
            if (score > alpha_val) {
                if (score >= beta_val) {
                    return beta_val;
                }

                alpha_val = score;
            }
        }
    }

    return best_score;
}
