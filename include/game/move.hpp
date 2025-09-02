#pragma once

#include "game/piece.hpp"

constexpr uint16_t START_SQUARE_MASK = 0b0000000000111111;
constexpr uint16_t TARGET_SQUARE_MASK = 0b0000111111000000;

constexpr int NO_FLAG = 0b0000;
constexpr int PAWN_CAPTURE_FLAG = 0b0001;
constexpr int CASTLE_FLAG = 0b0010;
constexpr int PAWN_TWO_UP_FLAG = 0b0011;

constexpr int QUEEN_PROMOTION_FLAG = 0b0100;
constexpr int BISHOP_PROMOTION_FLAG = 0b0101;
constexpr int KNIGHT_PROMOTION_FLAG = 0b0110;
constexpr int ROOK_PROMOTION_FLAG = 0b0111;

constexpr int EP_FLAG = 0b1000;

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
    Move() : m_Compact(0) {};
    Move(uint16_t value) : m_Compact(value) {}
    Move(int start_square, int target_square);
    Move(int start_square, int target_square, int move_flag);
    Move(Ref<Board> board, const std::string& move_uci);

    int start_square() const { return m_Compact & START_SQUARE_MASK; }
    int target_square() const { return (m_Compact & TARGET_SQUARE_MASK) >> 6; }
    int flag() const { return m_Compact >> 12; }

    inline bool is_promotion() const { return is_promotion(flag()); };
    inline static bool is_promotion(int flag) {
        return flag >= QUEEN_PROMOTION_FLAG && flag <= ROOK_PROMOTION_FLAG;
    }

    inline bool is_queen_promotion() const { return flag() == QUEEN_PROMOTION_FLAG; }
    inline bool is_bishop_promotion() const { return flag() == BISHOP_PROMOTION_FLAG; }
    inline bool is_knight_promotion() const { return flag() == KNIGHT_PROMOTION_FLAG; }
    inline bool is_rook_promotion() const { return flag() == ROOK_PROMOTION_FLAG; }

    inline bool is_castle() const { return is_castle(flag()); }
    inline static bool is_castle(int flag) { return flag == CASTLE_FLAG; }

    inline bool is_kingside_castle() const { return is_castle() && (target_square() % 8 == 6); }
    inline bool is_queenside_castle() const { return is_castle() && (target_square() % 8 == 2); }

    inline bool is_ep() { return is_ep(flag()); }
    inline static bool is_ep(int flag) { return flag == EP_FLAG; }

    inline bool is_pawn_double_push() { return is_pawn_double_push(flag()); }
    inline static bool is_pawn_double_push(int flag) { return flag == PAWN_TWO_UP_FLAG; }

    inline bool is_pawn_capture() { return is_pawn_capture(flag()); }
    inline static bool is_pawn_capture(int flag) { return flag == PAWN_CAPTURE_FLAG; }

    inline PieceType promotion_type() const { return promotion_type(flag()); }
    static PieceType promotion_type(int flag);

    static Piece promotion_piece(int flag, PieceColor color);

    static int flag_from_promotion_char(char c);
    static std::string str_from_promotion_flag(int flag);
    static std::string str_from_flag(int flag);

    bool valid_move() const { return m_Compact != 0; }

    std::string to_uci() const;
    std::string to_string() const { return to_uci(); };

    friend bool operator==(const Move& a, const Move& b) { return a.m_Compact == b.m_Compact; }
    friend bool operator!=(const Move& a, const Move& b) { return !(a == b); }

    friend std::ostream& operator<<(std::ostream& os, const Move& move) {
        os << move.to_uci();
        return os;
    }
};