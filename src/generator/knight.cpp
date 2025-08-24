#include <pch.hpp>

#include "game/coord.hpp"

#include "generator/knight.hpp"

Bitboard Knight::attacked_squares(int square_idx, const Bitboard&) {
    if (!Coord::valid_square_idx(square_idx)) {
        return Bitboard(0);
    }

    return Bitboard(KNIGHT_MOVES[square_idx]);
}

bool Knight::can_move_to(int knight_square_idx, int other_square_idx, const Bitboard&) {
    if (!Coord::valid_square_idx(knight_square_idx) || !Coord::valid_square_idx(other_square_idx)) {
        return false;
    }

    Bitboard b(KNIGHT_MOVES[knight_square_idx]);
    return b.bit_value_at(other_square_idx) == 1;
}