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
        Coord white_1(file + file_offset, rank + 1);
        if (white_1.valid_square_idx()) {
            white_shield.set(white_1);
        }

        Coord black_1(file + file_offset, rank - 1);
        if (black_1.valid_square_idx()) {
            white_shield.set(black_1);
        }

        // Two squares ahead horizontally
        Coord white_2(file + file_offset, rank + 2);
        if (white_2.valid_square_idx()) {
            white_shield.set(white_2);
        }

        Coord black_2(file + file_offset, rank - 2);
        if (black_2.valid_square_idx()) {
            white_shield.set(black_2);
        }
    }

    m_WhiteShields[square] = white_shield;
    m_BlackShields[square] = black_shield;
}