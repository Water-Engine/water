#include <pch.hpp>

#include "bitboard/bitboard.hpp"

#include "game/board.hpp"
#include "game/coord.hpp"

#include "generator/knight.hpp"

// ================ POSITION INFO ================

// Example: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
Result<PositionInfo, std::string> PositionInfo::from_fen(const std::string& fen) {
    PROFILE_FUNCTION();
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
    PROFILE_FUNCTION();
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

    m_AllPieceBB = m_WhiteBB | m_BlackBB;
}

void Board::reset() {
    PROFILE_FUNCTION();
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

    m_AllPieceBB.clear();

    m_State = GameState{};
    m_WhiteToMove = true;

    m_StateHistory.clear();
    m_AllMoves.clear();

    m_HalfmoveClock = 0;
}

std::string Board::diagram(bool black_at_top, bool include_fen, bool include_hash) const {
    PROFILE_FUNCTION();
    std::ostringstream oss;
    int last_move_square = -1;
    if (m_AllMoves.size() > 0) {
        last_move_square = m_AllMoves[m_AllMoves.size() - 1].target_square();
    }

    for (int y = 0; y < 8; y++) {
        int rank_idx = black_at_top ? 7 - y : y;
        oss << "+---+---+---+---+---+---+---+---+\n";
        for (int x = 0; x < 8; x++) {
            int file_idx = black_at_top ? x : 7 - x;
            Coord square_coord(file_idx, rank_idx);
            if (!square_coord.valid_square_idx()) {
                continue;
            }

            int square_idx = square_coord.square_idx();
            bool highlight = square_idx == last_move_square;
            const Piece& piece = m_StoredPieces[square_idx];

            if (highlight) {
                oss << fmt::interpolate("|({})", (char)piece);
            } else {
                oss << fmt::interpolate("| {} ", (char)piece);
            }
        }

        oss << fmt::interpolate("| {}\n", rank_idx + 1);
    }

    oss << "+---+---+---+---+---+---+---+---+\n";
    if (black_at_top) {
        oss << "  a   b   c   d   e   f   g   h  \n\n";
    } else {
        oss << "  h   g   f   e   d   c   b   a  \n\n";
    }

    if (include_fen) {
        oss << fmt::interpolate("Fen         : {}\n", "Not implemented");
    }

    if (include_hash) {
        oss << fmt::interpolate("Hash        : {}", "Not implemented");
    }

    return oss.str();
}

bool Board::make_rook_move(Coord start_coord, Coord target_coord, int move_flag, Piece piece_from,
                           Piece piece_to) {
    PROFILE_FUNCTION();
    fmt::println("A rook is trying to move, but not implemented");
    return false;
}

bool Board::make_knight_move(Coord start_coord, Coord target_coord, Piece piece_from,
                             Piece piece_to) {
    PROFILE_FUNCTION();
    int knight_idx = start_coord.square_idx();
    int target_idx = target_coord.square_idx();
    if (!Knight::can_move_to(knight_idx, target_idx)) {
        return false;
    }

    Bitboard attack_mask = Knight::avaialable_squares(knight_idx);
    Bitboard overlap = attack_mask & m_AllPieceBB;

    if (overlap.bit_value_at(target_idx) == 0) {
        // We can make this move without thinking of captures or friendly pieces
        m_KnightBB.toggle_bits(knight_idx, target_idx);
        if (piece_from.is_white()) {
            m_WhiteBB.toggle_bits(knight_idx, target_idx);
        } else {
            m_BlackBB.toggle_bits(knight_idx, target_idx);
        }
    } else {
        // The knight is now trying to capture, but cannot take its friend
        if (piece_from.color() == piece_to.color()) {
            return false;
        }

        if (piece_from.is_white()) {
            m_WhiteBB.toggle_bit(knight_idx);
            m_BlackBB.toggle_bit(target_idx);
        } else {
            m_BlackBB.toggle_bit(knight_idx);
            m_WhiteBB.toggle_bit(target_idx);
        }
    }

    m_AllPieceBB.toggle_bits(knight_idx, target_idx);
    m_StoredPieces[knight_idx].clear();
    m_StoredPieces[target_idx] =
        piece_from.is_white() ? Piece::white_knight() : Piece::black_knight();

    return true;
}

bool Board::make_bishop_move(Coord start_coord, Coord target_coord, Piece piece_from,
                             Piece piece_to) {
    PROFILE_FUNCTION();
    fmt::println("A bishop is trying to move, but not implemented");
    return false;
}

bool Board::make_queen_move(Coord start_coord, Coord target_coord, Piece piece_from,
                            Piece piece_to) {
    PROFILE_FUNCTION();
    fmt::println("A queen is trying to move, but not implemented");
    return false;
}

bool Board::make_king_move(Coord start_coord, Coord target_coord, int move_flag, Piece piece_from,
                           Piece piece_to) {
    PROFILE_FUNCTION();
    fmt::println("A king is trying to move, but not implemented");
    return false;
}

bool Board::make_pawn_move(Coord start_coord, Coord target_coord, int move_flag, Piece piece_from,
                           Piece piece_to) {
    PROFILE_FUNCTION();
    fmt::println("A pawn is trying to move, but not implemented");
    return false;
}

Piece Board::piece_at(int square_idx) {
    if (!Coord::valid_square_idx(square_idx)) {
        return Piece::none();
    }

    return m_StoredPieces[square_idx];
}

void Board::make_move(Move move) {
    PROFILE_FUNCTION();
    Coord target_coord(move.target_square());
    Coord start_coord(move.start_square());
    Piece piece_start = piece_at(start_coord.square_idx());
    Piece piece_target = piece_at(target_coord.square_idx());
    int move_flag = move.flag();

    // piece move handlers assume valid start and end coords
    if (piece_start.is_none() || start_coord == target_coord) {
        return;
    } else if (!start_coord.valid_square_idx() || !target_coord.valid_square_idx()) {
        return;
    } else if (piece_start.color() != (m_WhiteToMove ? PieceColor::White : PieceColor::Black)) {
        return;
    }

    // the start piece must exist at this point and thus has a color, so piece move helpers'
    // assumptions are valid
    PieceColor start_color = piece_start.color();
    bool was_valid;
    switch (piece_start.type()) {
    case PieceType::Rook:
        was_valid = make_rook_move(start_coord, target_coord, move_flag, piece_start, piece_target);
        break;
    case PieceType::Knight:
        was_valid = make_knight_move(start_coord, target_coord, piece_start, piece_target);
        break;
    case PieceType::Bishop:
        was_valid = make_bishop_move(start_coord, target_coord, piece_start, piece_target);
        break;
    case PieceType::Queen:
        was_valid = make_queen_move(start_coord, target_coord, piece_start, piece_target);
        break;
    case PieceType::King:
        was_valid = make_king_move(start_coord, target_coord, move_flag, piece_start, piece_target);
        break;
    case PieceType::Pawn:
        was_valid = make_pawn_move(start_coord, target_coord, move_flag, piece_start, piece_target);
        break;
    default:
        return;
    }

    if (!was_valid) {
        return;
    }

    m_AllMoves.push_back(move);
    m_WhiteToMove = !m_WhiteToMove;
}

Result<void, std::string> Board::load_from_fen(const std::string& fen) {
    PROFILE_FUNCTION();
    auto maybe_pos = PositionInfo::from_fen(fen);
    if (maybe_pos.is_err()) {
        return Result<void, std::string>::Err(maybe_pos.unwrap_err());
    }

    load_from_position(maybe_pos.unwrap());
    return Result<void, std::string>();
}
