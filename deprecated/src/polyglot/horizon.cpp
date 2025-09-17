#include <pch.hpp>

#include "polyglot/horizon.hpp"

using namespace chess;

void PGNVisitor::write_entry(std::ostringstream& oss, const PolyEntry& e) {
    auto put16 = [&](uint16_t v) {
        unsigned char buf[2] = {static_cast<unsigned char>(v >> 8),
                                static_cast<unsigned char>(v & 0xFF)};
        oss.write(reinterpret_cast<const char*>(buf), 2);
    };
    auto put64 = [&](uint64_t v) {
        unsigned char buf[8];
        for (int i = 7; i >= 0; --i) {
            buf[7 - i] = static_cast<unsigned char>((v >> (i * 8)) & 0xFF);
        }
        oss.write(reinterpret_cast<const char*>(buf), 8);
    };

    put64(e.key);
    put16(e.move);
    put16(e.weight);
    put16(e.learn);
}

void PGNVisitor::flush() {
    PROFILE_FUNCTION();
    if (m_Buffer.empty()) {
        return;
    }

    for (const auto& entry : m_Buffer) {
        write_entry(m_OutData, entry);
    }

    m_Buffer.clear();
}

void PGNVisitor::try_flush() {
    PROFILE_FUNCTION();
    for (auto it = m_PositionMap.begin(); it != m_PositionMap.end();) {
        uint64_t key = it->first;
        auto& moves = it->second;

        for (auto move_it = moves.begin(); move_it != moves.end();) {
            uint16_t move = move_it->first;
            uint16_t weight = move_it->second;

            m_Buffer.push_back({key, move, weight, 0});
            move_it = moves.erase(move_it);

            if (m_Buffer.size() >= MAX_BUFFER_SIZE) {
                flush();
            }
        }

        // If all moves for this key are processed, erase the key
        it = moves.empty() ? m_PositionMap.erase(it) : ++it;
    }
}

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