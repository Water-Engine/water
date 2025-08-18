#include <pch.hpp>

#include "bitboard/bitboard.hpp"

void Bitboard::set_bit(int bit_to_set) {
    if (bit_to_set < 0 || bit_to_set > 63) {
        return;
    }

    m_BBoard |= (1 << bit_to_set);
}

void Bitboard::toggle_bit(int bit_to_set) {
    if (bit_to_set < 0 || bit_to_set > 63) {
        return;
    }

    m_BBoard ^= (1 << bit_to_set);
}