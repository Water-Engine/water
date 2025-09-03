#pragma once

#include "game/board.hpp"
#include "game/move.hpp"

#include "evaluation/evaluation.hpp"

struct BestMove {
    Move BestMove;
    int BestMoveEval;
};

class Searcher {
  private:
    Ref<Board> m_Board;
    Evaluator m_Evaluator;
    Option<BestMove> m_BestMoveSoFar{};

  public:
    Searcher(Ref<Board> board) : m_Board(board), m_Evaluator(board) {}

    void find_bestmove();

    inline void set_bestmove(const Move& best_move, int best_evaluation) {
        m_BestMoveSoFar = Option<BestMove>({best_move, best_evaluation});
    };

    inline std::string retrieve_bestmove() const {
        return fmt::interpolate("bestmove {}", m_BestMoveSoFar.unwrap_or(BestMove{}).BestMove.to_uci());
    }
};