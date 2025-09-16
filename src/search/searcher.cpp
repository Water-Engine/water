#include <pch.hpp>

#include "search/searcher.hpp"

#include "evaluation/evaluation.hpp"
#include "evaluation/ordering.hpp"
#include "evaluation/pst.hpp"

std::pair<Move, int> Searcher::alpha_beta(int depth, int alpha, int beta, int ply,
                                          std::vector<Move>& pv) {
    m_NodesVisited += 1;
    if (ply == 0 && should_stop()) {
        auto bm = m_BestMoveSoFar.unwrap_or(BestMove{});
        return {bm.BestMove, bm.BestMoveEval};
    }

    Movelist moves;
    movegen::legalmoves(moves, *m_Board);
    if (moves.size() == 0) {
        if (m_Board->inCheck()) {
            int score = -MATE_SCORE + ply;
            return {Move::NO_MOVE, adjust_mate_score(score, ply)};
        } else {
            return {Move::NO_MOVE, 0};
        }
    }

    Move tt_move = Move::NO_MOVE;
    auto tt_node_opt = m_TT.probe();
    int alpha_original = alpha;

    if (tt_node_opt.is_some()) {
        auto tt_node = tt_node_opt.unwrap();
        tt_move = tt_node.BestMove;

        // Node is deep enough to use
        if (tt_node.Depth >= depth) {
            NodeType type = tt_node.Type;
            int score = adjust_mate_score(tt_node.EvaluationScore, ply);

            switch (type) {
            case NodeType::Exact:
                pv.push_back(tt_move);
                return {tt_move, score};
            case NodeType::LowerBound:
                alpha = std::max(alpha, score);
                break;
            case NodeType::UpperBound:
                beta = std::min(beta, score);
                break;
            default:
                break;
            }

            if (alpha >= beta) {
                return {tt_move, score};
            }
        }
    }

    if (depth == 0 || should_stop()) {
        // Try Syzygy WDL probe before q search
        if (m_Syzygy.is_loaded()) {
            uint64_t wdl = m_Syzygy.probe_wdl();
            if (wdl != TB_RESULT_FAILED) {
                int score;
                switch (TB_GET_WDL(wdl)) {
                case TB_WIN:
                    score = MATE_SCORE - ply;
                    break;
                case TB_LOSS:
                    score = -MATE_SCORE + ply;
                    break;
                case TB_DRAW:
                    score = 0;
                    break;
                default:
                    score = 0;
                    break;
                }

                return {Move::NO_MOVE, adjust_mate_score(score, ply)};
            }
        }
        
        return {Move::NO_MOVE, quiescence(alpha, beta, ply)};
    }
    m_Orderer.order_moves(m_Board, tt_move, moves, false, 0);

    // Perform null move pruning
    if (depth >= 3 && !m_Board->inCheck() && !is_endgame()) {
        m_Board->makeNullMove();
        int R = std::min(3, depth / 2);
        int score = -alpha_beta(depth - 1 - R, -beta, -beta + 1, ply + 1, pv).second;
        m_Board->unmakeNullMove();
        if (score >= beta) {
            return {Move::NO_MOVE, score};
        }
    }

    Move best_move = moves[0];
    int best_score = -INF;

    bool is_first = true;
    for (auto i = 0; i < moves.size(); ++i) {
        if (should_stop()) {
            break;
        }

        auto& move = moves[i];

        // Futility pruning
        if (depth <= 3 && !m_Board->isCapture(move)) {
            int static_eval = m_Evaluator.evaluate();
            const int FUTILITY_MARGIN = 1.5f * static_cast<float>(PieceScores::Pawn);
            if (static_eval + FUTILITY_MARGIN <= alpha) {
                continue;
            }
        }

        std::vector<Move> child_pv;
        m_Board->makeMove(move);

        int score;
        if (m_Board->isRepetition(1)) {
            score = 0;
        } else {
            if (is_first) {
                score = -alpha_beta(depth - 1, -beta, -alpha, ply + 1, child_pv).second;
                is_first = false;
            } else {
                // Late move reduction
                int reduced_depth = depth - 1;
                if (!m_Board->isCapture(move) && depth >= 3) {
                    int reduction = 1 + std::log(depth) + ((i > 3) ? 1 : 0);
                    reduced_depth = std::max(1, depth - reduction);
                }
                score = -alpha_beta(reduced_depth, -beta, -alpha, ply + 1, child_pv).second;
            }
        }

        m_Board->unmakeMove(move);

        if (!should_stop() && score > best_score) {
            best_move = move;
            best_score = score;

            pv.clear();
            pv.push_back(move);
            pv.insert(pv.end(), child_pv.begin(), child_pv.end());
        }

        if (score >= beta) {
            // Only add non-capture moves as killer moves
            if (!m_Board->isCapture(move) &&
                static_cast<uint64_t>(depth) < m_Orderer.MAX_KILLER_MOVE_PLY) {
                m_Orderer.m_KillersHeuristic[depth].add(move);
            }

            // Update history heuristic for moves causing cutoffs
            int color = static_cast<int>(m_Board->sideToMove());
            int from = move.from().index();
            int to = move.to().index();
            m_Orderer.m_HistoryHeuristic[color][from][to] += depth * depth;

            return {move, score};
        }

        alpha = std::max(alpha, score);
        if (alpha >= beta) {
            break;
        }
    }

    NodeType node_type = NodeType::Exact;
    if (best_score <= alpha_original) {
        node_type = NodeType::UpperBound;
    } else if (best_score >= beta) {
        node_type = NodeType::LowerBound;
    }

    Node node(m_Board->hash(), best_move, depth, best_score, node_type);
    m_TT.insert(node);

    return {best_move, best_score};
}

int Searcher::quiescence(int alpha, int beta, int ply) {
    m_NodesVisited += 1;
    m_QNodesVisited += 1;

    int eval = m_Evaluator.evaluate();

    if (eval >= beta) {
        return beta;
    }

    alpha = std::max(alpha, eval);

    auto moves = tactical_moves(m_Board);
    MoveOrderer::OrderFlag flags = MoveOrderer::OrderFlag::MVVLVA |
                                   MoveOrderer::OrderFlag::Promotion |
                                   MoveOrderer::OrderFlag::HashMove;
    m_Orderer.order_moves(m_Board, Move::NO_MOVE, moves, true, ply, flags);

    for (auto& move : moves) {
        if (should_stop()) {
            break;
        }

        if (m_Evaluator.see(move) <= 0) {
            continue;
        }

        m_Board->makeMove(move);
        if (m_Board->isRepetition(1)) {
            continue;
        } else if (m_Board->givesCheck(move) != CheckType::NO_CHECK) {
            continue;
        }

        int score = -quiescence(-beta, -alpha, ply + 1);
        m_Board->unmakeMove(move);

        if (score >= beta) {
            return beta;
        }
        if (score > alpha) {
            alpha = score;
        }
    }

    return adjust_mate_score(alpha, ply);
}

void Searcher::run_iterative_deepening() {
    // Try DTZ root probe first before doing any actual searching
    if (m_Syzygy.is_loaded()) {
        auto start = std::chrono::steady_clock::now();
        auto dtz_opt = m_Syzygy.probe_dtz();
        auto end = std::chrono::steady_clock::now();
        auto elapsed_ms =
            std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
        auto nps = 1 * 1000 / std::max(static_cast<int64_t>(1), elapsed_ms);

        if (dtz_opt.is_some()) {
            TbRootMoves root_moves = dtz_opt.unwrap();
            if (root_moves.size > 0) {
                auto selected_move = root_moves.moves[0];
                Move tb_move(selected_move.move);
                int tb_score = root_moves.moves[0].tbScore;

                std::ostringstream oss;
                for (size_t i = 0; i < selected_move.pvSize; ++i) {
                    Move pv_move(selected_move.pv[i]);
                    oss << uci::moveToUci(pv_move) << " ";
                }

                fmt::println("info depth {} score dtz {} nodes {} qnodes {} nps {} time {} pv {}",
                             0, tb_score, 1, 0, nps, oss.str());

                set_bestmove(tb_move, tb_score);
                print_bestmove();
                return;
            }
        }
    }

    m_BestMoveSoFar = Option<BestMove>();

    Move best_move = 0;
    int best_eval = -INF;

    for (int depth = 1; m_IsInfiniteSearch || depth <= MAX_SEARCH_DEPTH; ++depth) {
        if (should_stop()) {
            break;
        }

        int alpha = -INF;
        int beta = INF;

        std::vector<Move> pv;
        auto [move, score] = alpha_beta(depth, alpha, beta, 0, pv);

        auto now = std::chrono::steady_clock::now();
        auto elapsed_ms =
            std::chrono::duration_cast<std::chrono::milliseconds>(now - m_StartTime).count();
        int nps = m_NodesVisited * 1000 / std::max(static_cast<int64_t>(1), elapsed_ms);

        if (!should_stop() && move != Move::NO_MOVE) {
            best_move = move;
            best_eval = score;
            set_bestmove(best_move, best_eval);
        }

        if (!should_stop() && m_SearchInfo) {
            std::ostringstream oss;
            for (auto pv_move : pv) {
                oss << uci::moveToUci(pv_move) << " ";
            }
            if (std::abs(score) > MATE_THRESHOLD) {
                int mate_in = (MATE_SCORE - std::abs(score) + 1) / 2;
                fmt::println("info depth {} score mate {} nodes {} qnodes {} nps {} time {} pv {}",
                             depth, mate_in, m_NodesVisited.load(), m_QNodesVisited.load(), nps,
                             elapsed_ms, oss.str());
            } else {
                fmt::println("info depth {} score cp {} nodes {} qnodes {} nps {} time {} pv {}",
                             depth, score, m_NodesVisited.load(), m_QNodesVisited.load(), nps,
                             elapsed_ms, oss.str());
            }
        }

        if (depth > INFINITE_DEPTH_CAP) {
            stop_search();
            return;
        }
    }

    stop_search();
    print_bestmove();
}

inline bool Searcher::should_stop() const {
    if (m_StopFlag.load(std::memory_order_relaxed)) {
        return true;
    }

    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - m_StartTime).count();

    return !m_IsInfiniteSearch && elapsed >= m_TimeLimitMs;
}

void Searcher::find_bestmove(int time_limit_ms) {
    m_StopFlag = false;
    m_IsInfiniteSearch = time_limit_ms <= 0;
    m_TimeLimitMs = time_limit_ms;
    m_StartTime = std::chrono::steady_clock::now();
    m_NodesVisited = 0;
    m_QNodesVisited = 0;
    m_BestMoveSoFar = Option<BestMove>();

    // Wait for a previous search to stop
    if (m_SearchThread.joinable()) {
        m_SearchThread.join();
    }

    m_SearchThread = std::thread(&Searcher::run_iterative_deepening, this);
}