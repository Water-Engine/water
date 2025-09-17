#include <pch.hpp>

#include "evaluation/eval_bits.hpp"

using namespace chess;

PawnMasks::PawnMasks() {
    for (size_t square = 0; square < 64; ++square) {
        create_shields(square);
        create_passed(square);
        create_supports(square);
    }
}

void PawnMasks::create_shields(int square) {
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

void PawnMasks::create_passed(int square) {
    int file = Coord::file_from_square(square);
    int rank = Coord::rank_from_square(square);
    uint64_t file_a = static_cast<uint64_t>(File::FILE_A);

    Bitboard adjacent_files(file_a << std::max(0, file - 1) | file_a << std::min(7, file + 1));
    Bitboard white_forward_mask(~(UINT64_MAX >> (64 - 8 * (rank + 1))));
    Bitboard black_forward_mask((1ul << 8 * rank) - 1);

    m_WhitePassedMasks[square] = (file_a << file | adjacent_files) & white_forward_mask;
    m_BlackPassedMasks[square] = (file_a << file | adjacent_files) & black_forward_mask;
}

void PawnMasks::create_supports(int square) {
    int file = Coord::file_from_square(square);
    uint64_t file_a = static_cast<uint64_t>(File::FILE_A);

    Bitboard adjacent_files(file_a << std::max(0, file - 1) | file_a << std::min(7, file + 1));
    Bitboard horiz_adjacent((1ul << (square - 1) | 1ul << (square + 1)) & adjacent_files);

    auto shift_bb = [](Bitboard bb, int to_shift) {
        if (to_shift > 0) {
            return bb << to_shift;
        } else if (to_shift < 0) {
            return bb >> -to_shift;
        } else {
            return bb;
        }
    };

    m_WhiteSupportMasks[square] = horiz_adjacent | shift_bb(horiz_adjacent, -8);
    m_BlackSupportMasks[square] = horiz_adjacent | shift_bb(horiz_adjacent, 8);
}

FileMasks::FileMasks() {
    uint64_t file_a = static_cast<uint64_t>(File::FILE_A);
    for (int i = 0; i < 8; ++i) {
        m_FileMasks[i] = file_a << i;

        Bitboard left(i > 0 ? file_a << (i - 1) : 0);
        Bitboard right(i < 7 ? file_a << (i + 1) : 0);
        m_AdjacentFileMasks[i] = left | right;
    }

    for (int i = 0; i < 8; ++i) {
        if (i == 0 || i == 7) {
            m_TripleFileMasks[i] = m_FileMasks[i] | m_AdjacentFileMasks[i];
        } else {
            Bitboard left = file_a << (i - 1);
            Bitboard right = file_a << (i + 1);
            m_TripleFileMasks[i] = m_FileMasks[i] | left | right;
        }
    }
}

Distance::Distance() {
    for (int square_a = 0; square_a < 64; ++square_a) {
        Coord coord_a(square_a);
        int center_file_dist = std::max(3 - coord_a.file_idx(), coord_a.file_idx() - 4);
        int center_rank_dist = std::max(3 - coord_a.rank_idx(), coord_a.rank_idx() - 4);
        m_CenterManhattanDistance[square_a] = center_file_dist + center_rank_dist;

        for (int square_b = 0; square_b < 64; ++square_b) {
            Coord coord_b(square_b);
            int file_dist = std::abs(coord_a.file_idx() - coord_b.file_idx());
            int rank_dist = std::abs(coord_a.rank_idx() - coord_b.rank_idx());

            m_ChebyshevDistance[square_a][square_b] = std::max(file_dist, rank_dist);
            m_ManhattanDistance[square_a][square_b] = file_dist + rank_dist;
        }
    }
}