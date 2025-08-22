#include <pch.hpp>

#include "bitboard/bitboard.hpp"

#include "game/coord.hpp"
#include "game/piece.hpp"

#include "generator/sliders.hpp"

// ================ ROOK MOVES ================

Bitboard Rook::attacked_squares(int square_idx, const Bitboard& occupancy) {
    if (!Coord::valid_square_idx(square_idx)) {
        return Bitboard(0);
    }

    Magics& magics = Magics::instance();
    return magics.get_rook_attacks(square_idx, occupancy);
}

bool Rook::can_move_to(int rook_square_idx, int other_square_idx, const Bitboard& occupancy) {
    if (!Coord::valid_square_idx(rook_square_idx) || !Coord::valid_square_idx(other_square_idx)) {
        return false;
    }

    auto b = attacked_squares(rook_square_idx, occupancy);
    return b.bit_value_at(other_square_idx) == 1;
}

// ================ BISHOP MOVES ================

Bitboard Bishop::attacked_squares(int square_idx, const Bitboard& occupancy) {
    if (!Coord::valid_square_idx(square_idx)) {
        return Bitboard(0);
    }

    Magics& magics = Magics::instance();
    return magics.get_bishop_attacks(square_idx, occupancy);
}

bool Bishop::can_move_to(int bishop_square_idx, int other_square_idx, const Bitboard& occupancy) {
    if (!Coord::valid_square_idx(bishop_square_idx) || !Coord::valid_square_idx(other_square_idx)) {
        return false;
    }

    auto b = attacked_squares(bishop_square_idx, occupancy);
    return b.bit_value_at(other_square_idx) == 1;
}

// ================ QUEEN MOVES ================

Bitboard Queen::attacked_squares(int square_idx, const Bitboard& occupancy) {
    return Rook::attacked_squares(square_idx, occupancy) |
           Bishop::attacked_squares(square_idx, occupancy);
}

bool Queen::can_move_to(int queen_square_idx, int other_square_idx, const Bitboard& occupancy) {
    return Rook::can_move_to(queen_square_idx, other_square_idx, occupancy) ||
           Bishop::can_move_to(queen_square_idx, other_square_idx, occupancy);
}
