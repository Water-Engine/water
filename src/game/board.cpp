#include <pch.hpp>

#include "core.hpp"
#include "game/board.hpp"
#include "game/piece.hpp"

Coord::Coord(const std::string& square_string) {
    if (square_string.length() != 2) {
        m_FileIdx = -1;
        m_RankIdx = -1;
    }

    std::string lowered = str::to_lower(square_string);
    m_FileIdx = str::char_idx(str::from_view(FILES), lowered[0]);
    m_RankIdx = str::char_idx(str::from_view(RANKS), lowered[1]);
}

Coord::Coord(int square) {
    m_FileIdx = square % 8;
    m_RankIdx = square - m_FileIdx;
}

// Example: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
Result<PositionInfo, std::string> PositionInfo::from_fen(const std::string& fen) {
    auto sections = str::split(fen);
    if (sections.size() < 4) {
        return Result<PositionInfo, std::string>::Err(
            "FEN notation requires at least 4 distinct fields");
    }

    std::string& position = sections[0];
    std::string& to_move = sections[1];
    std::string& castling_rights = sections[2];
    std::string& ep_file = sections[3];

    // Initialization
    std::array<int, 64> squares;
    squares.fill(0);
    bool white_to_move = true;

    bool wck = false;
    bool wcq = false;
    bool bck = false;
    bool bcq = false;

    int ep = -1;
    int halfmove_clock = 0;
    int move_clock = 0;

    // Decode the position string into a board of pieces
    int file = 0;
    int rank = 7;
    for (const char c : position) {
        if (c == '/') {
            file = 0;
            rank -= 1;
        } else {
            if (std::isdigit(c)) {
                file += (int)c;
            } else {
                Piece p(c);
                squares[rank * 8 + file] = p.value();
                file += 1;
            }
        }
    }
    
    // Who's move is it
    if (to_move[0] == 'b') {
        white_to_move = false;
    }

    // Castling rights
    if (str::contains(castling_rights, 'K')) {
        wck = true;
    } else if (str::contains(castling_rights, 'Q')) {
        wcq = true;
    } else if (str::contains(castling_rights, 'k')) {
        bck = true;
    } else if (str::contains(castling_rights, 'q')) {
        bcq = true;
    }

    ep = Coord(ep_file).square_idx();

    if (sections.size() >= 5) {
        try {
            halfmove_clock = std::stoi(sections[4]);
        } catch (...) {
        }
    }

    if (sections.size() >= 6) {
        try {
            move_clock = std::stoi(sections[5]);
        } catch (...) {
        }
    }

    PositionInfo p(fen, squares, white_to_move, wck, wcq, bck, bcq, ep, halfmove_clock, move_clock);
    return Result<PositionInfo, std::string>(p);
}

std::string Board::to_string() { return std::string("Im not finished"); }

Result<void, std::string> Board::load_from_fen(const std::string& fen) {
    auto maybe_pos = PositionInfo::from_fen(fen);
    if (maybe_pos.is_err()) {
        return Result<void, std::string>::Err(maybe_pos.unwrap_err());
    }

    m_StartPos = maybe_pos.unwrap();
    return Result<void, std::string>::Err("Im not finished");
}
