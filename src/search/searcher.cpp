#include <pch.hpp>

#include "search/searcher.hpp"

#include "evaluation/evaluation.hpp"
#include "evaluation/ordering.hpp"

#include "generator/generator.hpp"

void Searcher::find_bestmove() {
    auto moves = Generator::generate(*m_Board);
    if (moves.size() == 0) {
        return;
    }

    MoveOrderer().order_moves(m_Board, 0, moves, false, 0);
    set_bestmove(moves[0], 0);
}