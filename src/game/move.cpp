#include <pch.hpp>

#include "game/board.hpp"
#include "game/move.hpp"

Move::Move(int start_square, int target_square) { m_Compact = start_square | target_square << 6; }

Move::Move(int start_square, int target_square, int move_flag) {
    m_Compact = start_square | target_square << 6 | move_flag << 12;
}

Move::Move(Ref<Board> board, const std::string& move_uci) {
    if (move_uci.length() < 4) {
        m_Compact = 0;
        return;
    }

    Coord start_coord(move_uci.substr(0, 2));
    int start = start_coord.square_idx();
    Coord target_coord(move_uci.substr(2, 2));
    int target = target_coord.square_idx();

    if (!start_coord.valid_square_idx() || !target_coord.valid_square_idx()) {
        m_Compact = 0;
        return;
    }

    Piece moved_piece = board->piece_at(start);
    int flag = NO_FLAG;

    if (moved_piece.type() == PieceType::Pawn) {
        if (move_uci.length() > 4) {
            flag = flag_from_promotion_char(move_uci[move_uci.length() - 1]);
        } else if (std::abs(start_coord.rank_idx() - target_coord.rank_idx()) == 2) {
            flag = PAWN_TWO_UP_FLAG;
        } else if ((start_coord.file_idx() != target_coord.file_idx()) &&
                   board->piece_at(target) == Piece::none()) {
            flag = EN_PASSANT_CAPTURE_FLAG;
        }
    } else if (moved_piece.type() == PieceType::King) {
        if (std::abs(start_coord.file_idx() - target_coord.file_idx()) > 1) {
            flag = CASTLE_FLAG;
        }
    }

    m_Compact = start | target << 6 | flag << 12;
}

bool Move::is_promotion() const { return flag() >= QUEEN_PROMOTION_FLAG; }

PieceType Move::promotion_type() const {
    switch (flag()) {
    case QUEEN_PROMOTION_FLAG:
        return PieceType::Queen;
    case BISHOP_PROMOTION_FLAG:
        return PieceType::Bishop;
    case KNIGHT_PROMOTION_FLAG:
        return PieceType::Knight;
    case ROOK_PROMOTION_FLAG:
        return PieceType::Rook;
    default:
        return PieceType::None;
    }
}

int Move::flag_from_promotion_char(char c) {
    switch (c) {
    case 'q':
        return QUEEN_PROMOTION_FLAG;
    case 'b':
        return BISHOP_PROMOTION_FLAG;
    case 'n':
        return KNIGHT_PROMOTION_FLAG;
    case 'r':
        return ROOK_PROMOTION_FLAG;
    default:
        return NO_FLAG;
    }
}

std::string Move::str_from_promotion_flag(int flag) {
    switch (flag) {
    case QUEEN_PROMOTION_FLAG:
        return std::string("q");
    case BISHOP_PROMOTION_FLAG:
        return std::string("b");
    case KNIGHT_PROMOTION_FLAG:
        return std::string("n");
    case ROOK_PROMOTION_FLAG:
        return std::string("r");
    default:
        return std::string();
    }
}

std::string Move::to_uci() const {
    std::string start_square_name = Coord(start_square()).as_str();
    std::string target_square_name = Coord(target_square()).as_str();

    std::ostringstream oss;
    oss << start_square_name;
    oss << target_square_name;

    if (is_promotion()) {
        oss << str_from_promotion_flag(flag());
    }

    return oss.str();
}