#pragma once

#include "bitboard/bitboard.hpp"

#include "game/coord.hpp"
#include "game/piece.hpp"

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

    template <PieceColor Color> inline Bitboard get_unchecked(int king_square) const {
        if constexpr (Color == PieceColor::White) {
            return m_WhiteShields[king_square];
        } else {
            return m_BlackShields[king_square];
        }
    };

    inline Bitboard get_unchecked(PieceColor color, int king_square) const {
        if (color == PieceColor::White) {
            return m_WhiteShields[king_square];
        } else {
            return m_BlackShields[king_square];
        }
    };

    inline Bitboard get(PieceColor color, int king_square) const {
        if (!Coord::valid_square_idx(king_square)) {
            return Bitboard(0);
        }

        return get_unchecked(color, king_square);
    };
};