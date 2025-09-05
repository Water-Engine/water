#include <pch.hpp>

#include "evaluation/evaluation.hpp"
#include "evaluation/ordering.hpp"
#include "evaluation/pst.hpp"

void MoveOrderer::order_moves(Ref<Board> board, const Move& hash_move, Movelist& moves,
                              bool in_quiescence, size_t ply) {
    PROFILE_FUNCTION();
    std::sort(moves.begin(), moves.end(),
              [](const Move& a, const Move& b) { return a.score() > b.score(); });
}
