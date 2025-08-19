#include <pch.hpp>

#include "bitboard/bitboard.hpp"

#include "game/board.hpp"

// ================ COORD ================

Coord::Coord(const std::string& square_string) {
    if (square_string.length() != 2) {
        m_FileIdx = -1;
        m_RankIdx = -1;
    }

    std::string lowered = str::to_lower(square_string);
    m_FileIdx = str::char_idx(str::from_view(FILES), lowered[0]);
    m_RankIdx = str::char_idx(str::from_view(RANKS), lowered[1]);
}

bool Coord::valid_square_idx() const {
    int square_idx = square_idx_unchecked();
    return (square_idx >= 0 && square_idx <= 63);
}

bool Coord::valid_square_idx(int square_idx) {
    Coord c(square_idx);
    return c.valid_square_idx();
}

std::string Coord::as_str() const {
    if (!valid_square_idx()) {
        return std::string();
    }

    char file_name = FILES[m_FileIdx];
    char rank_name = RANKS[m_RankIdx];

    char combined[3] = {file_name, rank_name, '\0'};
    return std::string(combined);
}

std::string Coord::as_str(int square_idx) {
    Coord c(square_idx);
    return c.as_str();
}

// ================ POSITION INFO ================

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
                file += c - '0';
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

// ================ BOARD ================

void Board::load_from_position(const PositionInfo& pos) {
    reset();

    m_AllMoves.reserve(pos.m_MoveClock);
    m_HalfmoveClock = pos.m_HalfmoveClock;

    m_StartPos = pos;
    m_State = GameState(pos.m_WhiteCastleKingside, pos.m_WhiteCastleQueenside,
                        pos.m_BlackCastleKingside, pos.m_BlackCastleQueenside, pos.m_EpSquare);

    m_StateHistory.emplace_back(m_State);
    m_StoredPieces = pos.m_Squares;

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

void Board::reset() {
    m_StartPos = PositionInfo{};

    m_StoredPieces.fill(Piece());

    m_WhiteBB.clear();
    m_BlackBB.clear();
    m_PawnBB.clear();
    m_KnightBB.clear();
    m_BishopBB.clear();
    m_RookBB.clear();
    m_QueenBB.clear();
    m_KingBB.clear();

    m_State = GameState{};
    m_WhiteToMove = true;

    m_StateHistory.clear();
    m_AllMoves.clear();

    m_HalfmoveClock = 0;
}

std::string Board::to_string() {
    std::ostringstream oss;
    oss << m_AllMoves.size();
    return oss.str();
}

Bitboard Board::all_pieces() const {
    return m_RookBB | m_KnightBB | m_BishopBB | m_KingBB | m_QueenBB | m_PawnBB;
}

Piece Board::piece_at(int square_idx) {
    if (!Coord::valid_square_idx(square_idx)) {
        return Piece::none();
    }

    return m_StoredPieces[square_idx];
}

void Board::make_move(Move move) { m_AllMoves.push_back(move); }

Result<void, std::string> Board::load_from_fen(const std::string& fen) {
    auto maybe_pos = PositionInfo::from_fen(fen);
    if (maybe_pos.is_err()) {
        return Result<void, std::string>::Err(maybe_pos.unwrap_err());
    }

    load_from_position(maybe_pos.unwrap());
    return Result<void, std::string>();
}
