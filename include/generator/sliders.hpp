#pragma once

#include "game/piece.hpp"

#include "bitboard/magics.hpp"

class Rook {
  public:
    Rook() = delete;
    Rook(const Rook&) = delete;

    static Bitboard attacked_squares(int square_idx, const Bitboard& occupancy);
    static bool can_move_to(int rook_square_idx, int other_square_idx, const Bitboard& occupancy);
    constexpr inline static PieceType as_piece_type() { return PieceType::Rook; }
};

class Bishop {
  public:
    Bishop() = delete;
    Bishop(const Bishop&) = delete;

    static Bitboard attacked_squares(int square_idx, const Bitboard& occupancy);
    static bool can_move_to(int bishop_square_idx, int other_square_idx, const Bitboard& occupancy);
    constexpr inline static PieceType as_piece_type() { return PieceType::Bishop; }
};

class Queen {
  public:
    Queen() = delete;
    Queen(const Queen&) = delete;

    static Bitboard attacked_squares(int square_idx, const Bitboard& occupancy);
    static bool can_move_to(int queen_square_idx, int other_square_idx, const Bitboard& occupancy);
    constexpr inline static PieceType as_piece_type() { return PieceType::Queen; }
};
