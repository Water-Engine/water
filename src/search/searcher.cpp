#include <pch.hpp>

#include "search/searcher.hpp"

#include "evaluation/evaluation.hpp"
#include "evaluation/ordering.hpp"
#include "evaluation/pst.hpp"

std::pair<Move, int> Searcher::naive_ab(int depth, int alpha, int beta) {
    Movelist moves;
    movegen::legalmoves(moves, *m_Board);
    if (depth == 0 || moves.size() == 0) {
        return {0, m_Evaluator.evaluate()};
    }

    Move best_move = 0;
    int best_score = -INF;

    for (auto& move : moves) {
        {
            PROFILE_SCOPE("Search Make");
            m_Board->makeMove(move);
        }
        int score = -naive_ab(depth - 1, -beta, -alpha).second;
        {
            PROFILE_SCOPE("Search Unmake");
            m_Board->unmakeMove(move);
        }

        if (score > best_score) {
            best_move = move;
            best_score = score;
        }

        alpha = std::max(alpha, score);
        if (alpha > beta) {
            break;
        }
    }

    return {best_move, best_score};
}

void Searcher::find_bestmove() {
    m_BestMoveSoFar = Option<BestMove>();

    Move best_move = 0;
    int best_eval = -INF;

    for (int depth = 1; depth <= MAX_SEARCH_DEPTH; ++depth) {
        int alpha = -INF;
        int beta = INF;

        auto [move, eval] = naive_ab(depth, alpha, beta);

        if (move != Move::NO_MOVE) {
            best_move = move;
            best_eval = eval;
            set_bestmove(best_move, best_eval);
        }
    }
}