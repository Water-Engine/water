#include <pch.hpp>

#include "bitboard/bitboard.hpp"

void Bitboard::set_bit(int bit_to_set) {
    if (bit_to_set < 0 || bit_to_set > 63) {
        return;
    }

    m_BBoard |= (1ULL << bit_to_set);
}

void Bitboard::toggle_bit(int bit_to_set) {
    if (bit_to_set < 0 || bit_to_set > 63) {
        return;
    }

    m_BBoard ^= (1ULL << bit_to_set);
}

int Bitboard::pop_lsb(uint64_t& value) {
    if (value == 0) {
        return -1;
    }

    int index = __builtin_ctzll(value);
    value &= (value - 1);

    return index;
}
