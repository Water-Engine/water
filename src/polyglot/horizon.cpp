#include <pch.hpp>

#include "polyglot/horizon.hpp"

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
        return;
    }

    m_Board.makeMove(parsed_move);
    m_NumHalfMovesSoFar++;
}

void PGNVisitor::endPgn() { try_flush(); }

std::string make_polyglot_book(int depth, const std::filesystem::path& pgn_file) {
    PROFILE_FUNCTION();

    if (!std::filesystem::exists(pgn_file)) {
        return std::string();
    }

    std::ifstream file_stream(pgn_file);
    if (!file_stream) {
        return std::string();
    }

    if (pgn_file.extension() != ".pgn") {
        fmt::eprintln("Unsupported opening book file extension: {}", pgn_file.extension());
        return std::string();
    }

    PGNVisitor visitor(depth);
    pgn::StreamParser parser(file_stream);

    parser.readGames(visitor);
    return visitor.to_string();
}