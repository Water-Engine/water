#pragma once

#include "game/utils.hpp"

/// Pawn Shields - protective squares for pawns around a king
class PawnShields {
  private:
    std::array<Bitboard, 64> m_WhiteShields;
    std::array<Bitboard, 64> m_BlackShields;

  private:
    PawnShields();

    /// Generated colored pawn shields; guarantees square is valid
    void create_shields(int square);

  public:
    PawnShields(const PawnShields&) = delete;
    PawnShields& operator=(const PawnShields&) = delete;
    PawnShields(PawnShields&&) = delete;
    PawnShields& operator=(PawnShields&&) = delete;

    static PawnShields& instance() {
        static PawnShields s_instance;
        return s_instance;
    }

    inline Bitboard get_unchecked(Color C, int king_square) const {
        if (C.internal() == Color::WHITE) {
            return m_WhiteShields[king_square];
        } else {
            return m_BlackShields[king_square];
        }
    };

    inline Bitboard get(Color C, int king_square) const {
        if (!Coord::valid_square_idx(king_square)) {
            return Bitboard(0);
        }

        return get_unchecked(C, king_square);
    };
};