#include <pch.hpp>

#include "bitboard/bitboard.hpp"

#include "game/coord.hpp"
#include "game/piece.hpp"

#include "generator/pawn.hpp"

template <PieceColor Color> inline Bitboard Pawn::attacked_squares(int square_idx) {
    if (!Coord::valid_square_idx(square_idx)) {
        return Bitboard(0);
    }

    if constexpr (Color == PieceColor::White) {
        return Bitboard(WHITE_PAWN_ATTACKS[square_idx]);
    } else {
        return Bitboard(BLACK_PAWN_ATTACKS[square_idx]);
    }
}

template <PieceColor Color>
inline bool Pawn::can_attack(int pawn_square_idx, int other_square_idx) {
    if (!Coord::valid_square_idx(pawn_square_idx) || !Coord::valid_square_idx(other_square_idx)) {
        return false;
    }

    Bitboard b;
    if constexpr (Color == PieceColor::White) {
        b = Bitboard(WHITE_PAWN_ATTACKS[pawn_square_idx]);
    } else {
        b = Bitboard(BLACK_PAWN_ATTACKS[pawn_square_idx]);
    }

    return b.bit_value_at(other_square_idx) == 1;
}
