#include <pch.hpp>

#include "builder/visitor.hpp"

void PGNVisitor::startPgn() {
    m_Board.setFen(constants::STARTPOS);
    m_NumHalfMovesSoFar = 0;
}

void PGNVisitor::move(std::string_view move, [[maybe_unused]] std::string_view comment) {
    uint64_t halfmove_cutoff = m_MaxOpeningDepth * 2;
    uint64_t key = m_Board.hash();

    Move parsed_move = uci::parseSan(m_Board, move);
    uint16_t encoded_move = parsed_move.move();

    if (m_NumHalfMovesSoFar < halfmove_cutoff) {
        add_to_map(key, encoded_move);
    }

    Movelist moves;
    movegen::legalmoves(moves, m_Board);
    if (!contains(moves, parsed_move)) {
        m_IllegalCounter += 1;
        return;
    }

    m_Board.makeMove(parsed_move);
    m_LegalCounter += 1;
    m_NumHalfMovesSoFar++;
}

void PGNVisitor::endPgn() {
    try_flush();
    m_GameCounter += 1;
}
