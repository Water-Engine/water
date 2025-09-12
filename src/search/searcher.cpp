#include <pch.hpp>

#include "search/searcher.hpp"

#include "evaluation/evaluation.hpp"
#include "evaluation/ordering.hpp"
#include "evaluation/pst.hpp"

std::pair<Move, int> Searcher::alpha_beta(int depth, int alpha, int beta) {
    Move tt_move = Move::NO_MOVE;
    auto tt_node_opt = m_TT.probe();
    int alpha_original = alpha;

    if (tt_node_opt.is_some()) {
        auto tt_node = tt_node_opt.unwrap();
        tt_move = tt_node.BestMove;

        // Node is deep enough to use
        if (tt_node.Depth >= depth) {
            NodeType type = tt_node.Type;
            int score = tt_node.EvaluationScore;

            switch (type) {
            case NodeType::Exact:
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

    Movelist moves;
    movegen::legalmoves(moves, *m_Board);
    if (depth == 0 || moves.size() == 0 || should_stop()) {
        return {Move::NO_MOVE, quiescence(alpha, beta)};
    }
    m_Orderer.order_moves(m_Board, tt_move, moves, depth <= 0, 0);

    Move best_move = 0;
    int best_score = -INF;

    for (auto& move : moves) {
        if (should_stop()) {
            break;
        }

        m_Board->makeMove(move);
        int score = -alpha_beta(depth - 1, -beta, -alpha).second;
        m_Board->unmakeMove(move);

        if (score > best_score) {
            best_move = move;
            best_score = score;
        }

        if (score >= beta) {
            // Only add non-capture moves as killer moves
            if (is_capture(move, m_Board).is_none() &&
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
        if (alpha > beta) {
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

void Searcher::run_iterative_deepening() {
    m_BestMoveSoFar = Option<BestMove>();

    Move best_move = 0;
    int best_eval = -INF;

    for (int depth = 1; m_IsInfiniteSearch || depth <= MAX_SEARCH_DEPTH; ++depth) {
        if (should_stop()) {
            break;
        }

        int alpha = -INF;
        int beta = INF;

        auto [move, eval] = alpha_beta(depth, alpha, beta);

        if (move != Move::NO_MOVE) {
            best_move = move;
            best_eval = eval;
            set_bestmove(best_move, best_eval);
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

int Searcher::quiescence(int alpha, int beta) {
    int eval = m_Evaluator.evaluate();

    if (eval >= beta) {
        return beta;
    }

    if (eval > alpha) {
        alpha = eval;
    }

    Movelist moves;
    movegen::legalmoves<movegen::MoveGenType::CAPTURE>(moves, *m_Board);

    for (auto& move : moves) {
        if (should_stop()) {
            break;
        }

        m_Board->makeMove(move);
        int score = -quiescence(-beta, -alpha);
        m_Board->unmakeMove(move);

        if (score >= beta) {
            return beta;
        }
        if (score > alpha) {
            alpha = score;
        }
    }

    return alpha;
}

void Searcher::find_bestmove(int time_limit_ms) {
    m_StopFlag = false;
    m_IsInfiniteSearch = time_limit_ms <= 0;
    m_TimeLimitMs = time_limit_ms;
    m_StartTime = std::chrono::steady_clock::now();

    // Wait for a previous search to stop
    if (m_SearchThread.joinable()) {
        m_SearchThread.join();
    }

    m_SearchThread = std::thread(&Searcher::run_iterative_deepening, this);
}