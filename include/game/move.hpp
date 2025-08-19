#pragma once

#include "game/piece.hpp"

const uint16_t START_SQUARE_MASK = 0b0000000000111111;
const uint16_t TARGET_SQUARE_MASK = 0b0000111111000000;

const int NO_FLAG = 0b0000;
const int EN_PASSANT_CAPTURE_FLAG = 0b0001;
const int CASTLE_FLAG = 0b0010;
const int PAWN_TWO_UP_FLAG = 0b0011;

const int QUEEN_PROMOTION_FLAG = 0b0100;
const int BISHOP_PROMOTION_FLAG = 0b0101;
const int KNIGHT_PROMOTION_FLAG = 0b0110;
const int ROOK_PROMOTION_FLAG = 0b0111;

class Board;

class Move {
  private:
    /*
     * Compact Move representation (ffffttttttssssss)
     * - Bits [0, 5]: start square, range [0, 63]
     * - Bits [6, 11]: target square, range [0, 63]
     * - Bits [12, 15]: start square, range [0, 15]
     */
    uint16_t m_Compact;

  public:
    Move() = default;
    Move(uint16_t value) : m_Compact(value) {}
    Move(int start_square, int target_square);
    Move(int start_square, int target_square, int move_flag);
    Move(Ref<Board> board, const std::string& move_uci);

    int start_square() const { return m_Compact & START_SQUARE_MASK; }
    int target_square() const { return (m_Compact & TARGET_SQUARE_MASK) >> 6; }
    int flag() const { return m_Compact >> 12; }

    bool is_promotion() const;
    PieceType promotion_type() const;

    static int flag_from_promotion_char(char c);
    static std::string str_from_promotion_flag(int flag);

    std::string to_uci() const;
};