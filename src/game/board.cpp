#include <pch.hpp>

#include "core.hpp"

#include "game/board.hpp"

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

bool Coord::valid_square_idx() const {
    int square_idx = square_idx_unchecked();
    return (square_idx >= 0 && square_idx <= 63);
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
    std::string& ep_square = sections[3];

    // Initialization
    std::array<Piece, 64> squares;
    squares.fill(Piece());
    bool white_to_move = true;

    bool wck = false;
    bool wcq = false;
    bool bck = false;
    bool bcq = false;

    int ep_square_idx = -1;
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
                squares[rank * 8 + file] = p;
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

    ep_square_idx = Coord(ep_square).square_idx();

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

    PositionInfo p(fen, squares, white_to_move, wck, wcq, bck, bcq, ep_square_idx, halfmove_clock,
                   move_clock);
    return Result<PositionInfo, std::string>(p);
}

void Board::load_from_position(const PositionInfo& pos) {
    m_StartPos = pos;
    m_State = GameState(pos.m_WhiteCastleKingside, pos.m_WhiteCastleQueenside,
                        pos.m_BlackCastleKingside, pos.m_BlackCastleQueenside, pos.m_EpSquare);
    m_StateHistory.clear();
    m_AllMoves.clear();
    m_StateHistory.emplace_back(m_State);

    m_AllMoves.reserve(pos.m_MoveClock);
    m_HalfmoveClock = pos.m_HalfmoveClock;

    m_WhiteBB.clear();
    m_BlackBB.clear();
    m_RookBB.clear();
    m_KnightBB.clear();
    m_BishopBB.clear();
    m_QueenBB.clear();
    m_KingBB.clear();
    m_PawnBB.clear();

    for (size_t i = 0; i < pos.m_Squares.size(); i++) {
        Piece piece = pos.m_Squares[i];
        if (piece.is_none()) {
            continue;
        }

        if (piece.is_white()) {
            m_WhiteBB.set_bit(i);
        } else if (piece.is_black()) {
            m_BlackBB.set_bit(i);
        }

        if (piece.is_rook()) {
            m_RookBB.set_bit(i);
        } else if (piece.is_knight()) {
            m_KnightBB.set_bit(i);
        } else if (piece.is_bishop()) {
            m_BishopBB.set_bit(i);
        } else if (piece.is_queen()) {
            m_QueenBB.set_bit(i);
        } else if (piece.is_king()) {
            m_KingBB.set_bit(i);
        } else if (piece.is_pawn()) {
            m_PawnBB.set_bit(i);
        }
    }
}

std::string Board::to_string() { return std::string("Im not finished"); }

Result<void, std::string> Board::load_from_fen(const std::string& fen) {
    auto maybe_pos = PositionInfo::from_fen(fen);
    if (maybe_pos.is_err()) {
        return Result<void, std::string>::Err(maybe_pos.unwrap_err());
    }

    load_from_position(maybe_pos.unwrap());
    return Result<void, std::string>();
}
