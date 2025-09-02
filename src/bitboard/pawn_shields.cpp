#include <pch.hpp>

#include "bitboard/pawn_shields.hpp"

PawnShields::PawnShields() {
    for (size_t square = 0; square < 64; ++square) {
        create_shields(square);
    }
}

void PawnShields::create_shields(int square) {
    Bitboard white_shield;
    Bitboard black_shield;

    Coord square_coord(square);
    int rank = square_coord.rank_idx();
    int file = square_coord.file_idx();

    for (int file_offset = -1; file_offset <= 1; ++file_offset) {
        // One square ahead horizontally
        white_shield.set_bit(Coord(file + file_offset, rank + 1));
        black_shield.set_bit(Coord(file + file_offset, rank - 1));

        // Two squares ahead horizontally
        white_shield.set_bit(Coord(file + file_offset, rank + 2));
        black_shield.set_bit(Coord(file + file_offset, rank - 2));
    }

    m_WhiteShields[square] = white_shield;
    m_BlackShields[square] = black_shield;
}