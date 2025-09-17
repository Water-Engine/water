#include <pch.hpp>

#include "bot.hpp"

using namespace chess;

uint64_t Bot::perft_recursive(Board& board, int depth) {
    if (depth == 0) {
        return 1;
    }

    uint64_t total_nodes = 0;
    Movelist moves;
    movegen::legalmoves(moves, *m_Board);
    for (auto& move : moves) {
        board.makeMove(move);
        total_nodes += perft_recursive(board, depth - 1);
        board.unmakeMove(move);
    }

    return total_nodes;
}

uint64_t Bot::perft(int depth) { return perft_recursive(*m_Board, depth); }
