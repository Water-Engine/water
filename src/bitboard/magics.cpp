#include <pch.hpp>

#include "bitboard/magics.hpp"

Magics::Magics() {
    PROFILE_FUNCTION();
    std::array<Bitboard, 64> rook_mask = {};
    std::array<Bitboard, 64> bishop_mask = {};

    for (size_t square_idx = 0; square_idx < 64; ++square_idx) {
        rook_mask[square_idx] = create_movement_mask(square_idx, true);
        bishop_mask[square_idx] = create_movement_mask(square_idx, false);
    }

    std::array<std::vector<Bitboard>, 64> rook_attacks = {};
    std::array<std::vector<Bitboard>, 64> bishop_attacks = {};

    for (size_t i = 0; i < 64; ++i) {
        rook_attacks[i] = create_table(i, true, ROOK_MAGICS[i], ROOK_SHIFTS[i]);
        bishop_attacks[i] = create_table(i, false, BISHOP_MAGICS[i], BISHOP_SHIFTS[i]);
    }

    m_RookMask = rook_mask;
    m_BishopMask = bishop_mask;
    m_RookAttacks = rook_attacks;
    m_BishopAttacks = bishop_attacks;
}

std::vector<Bitboard> Magics::create_table(int square_idx, bool is_ortho_slider, uint64_t magic,
                                           int left_shift) {
    int num_bits = 64 - left_shift;
    size_t lookup_size = 1ULL << num_bits;
    std::vector<Bitboard> table(lookup_size, Bitboard(0));

    auto movement_mask = create_movement_mask(square_idx, is_ortho_slider);
    auto blockers = create_all_blockers(movement_mask);

    for (const auto& pattern : blockers) {
        uint64_t idx = (pattern * magic) >> left_shift;
        Bitboard moves = legal_move_bb(square_idx, pattern, is_ortho_slider);
        table[idx] = moves;
    }

    return table;
}

std::vector<Bitboard> Magics::create_all_blockers(const Bitboard& movement_mask) {
    std::vector<int> move_square_indices;
    move_square_indices.reserve(16);
    for (int i = 0; i < 64; ++i) {
        if (movement_mask.bit_value_at(i) == 1) {
            move_square_indices.push_back(i);
        }
    }

    size_t num_patterns = 1ULL << move_square_indices.size();
    std::vector<Bitboard> blocker_bbs(num_patterns, Bitboard(0));

    for (size_t pattern_idx = 0; pattern_idx < num_patterns; ++pattern_idx) {
        for (size_t bit_idx = 0; bit_idx < move_square_indices.size(); ++bit_idx) {
            uint64_t bit = (pattern_idx >> bit_idx) & 1ULL;
            blocker_bbs[pattern_idx] =
                blocker_bbs[pattern_idx] | (bit << move_square_indices[bit_idx]);
        }
    }

    return blocker_bbs;
}

Bitboard Magics::create_movement_mask(int square_idx, bool is_ortho_slider) {
    Bitboard mask = 0;
    auto& directions = is_ortho_slider ? ROOK_DIRECTIONS : BISHOP_DIRECTIONS;
    Coord start_coord(square_idx);

    for (const auto& dir : directions) {
        for (int dst = 1; dst < 8; ++dst) {
            Coord coord = start_coord + dir * dst;
            Coord next_coord = start_coord + dir * (dst + 1);

            if (next_coord.valid_square_idx()) {
                mask.set_bit(coord.square_idx_unchecked());
            } else {
                break;
            }
        }
    }

    return mask;
}

Bitboard Magics::legal_move_bb(int square_idx, const Bitboard& blocker_bb, bool is_ortho_slider) {
    Bitboard bb = 0;
    auto& directions = is_ortho_slider ? ROOK_DIRECTIONS : BISHOP_DIRECTIONS;
    Coord start_coord(square_idx);

    for (const auto& dir : directions) {
        for (int dst = 1; dst < 8; ++dst) {
            Coord coord = start_coord + dir * dst;

            if (coord.valid_square_idx()) {
                int index = coord.square_idx_unchecked();
                bb.set_bit(index);
                if (blocker_bb.contains_square(index)) {
                    break;
                }
            } else {
                break;
            }
        }
    }

    return bb;
}

Bitboard Magics::get_rook_attacks(int square, const Bitboard& blockers) {
    uint64_t masked_blockers = blockers & m_RookMask[square];
    uint64_t key = (masked_blockers * ROOK_MAGICS[square]) >> ROOK_SHIFTS[square];
    return m_RookAttacks[square][key];
}

Bitboard Magics::get_bishop_attacks(int square, const Bitboard& blockers) {
    uint64_t masked_blockers = blockers & m_BishopMask[square];
    uint64_t key = (masked_blockers * BISHOP_MAGICS[square]) >> BISHOP_SHIFTS[square];
    return m_BishopAttacks[square][key];
}
