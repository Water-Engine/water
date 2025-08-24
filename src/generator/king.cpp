#include <pch.hpp>

#include "game/coord.hpp"

#include "generator/king.hpp"

Bitboard King::attacked_squares(int square_idx, const Bitboard&) {
    if (!Coord::valid_square_idx(square_idx)) {
        return Bitboard(0);
    }

    return Bitboard(KING_MOVES[square_idx]);
}

bool King::can_move_to(int king_square_idx, int other_square_idx, const Bitboard&) {
    if (!Coord::valid_square_idx(king_square_idx) || !Coord::valid_square_idx(other_square_idx)) {
        return false;
    }

    Bitboard b(KING_MOVES[king_square_idx]);
    return b.bit_value_at(other_square_idx) == 1;
}