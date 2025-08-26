#include <pch.hpp>

#include "bitboard/bitboard.hpp"

#include "game/board.hpp"
#include "game/coord.hpp"

void Bitboard::set_bit(int bit_to_set) {
    if (bit_to_set < 0 || bit_to_set > 63) {
        return;
    }

    set_bit_unchecked(bit_to_set);
}

void Bitboard::set_bit_unchecked(int bit_to_set) { m_BBoard |= (1ULL << bit_to_set); }

void Bitboard::clear_bit(int bit_to_clear) {
    if (bit_to_clear < 0 || bit_to_clear > 63) {
        return;
    }

    clear_bit_unchecked(bit_to_clear);
}

void Bitboard::clear_bit_unchecked(int bit_to_clear) { m_BBoard &= ~(1ULL << bit_to_clear); }

void Bitboard::toggle_bit(int bit_to_set) {
    if (bit_to_set < 0 || bit_to_set > 63) {
        return;
    }

    m_BBoard ^= (1ULL << bit_to_set);
}

void Bitboard::toggle_bits(int first_bit, int second_bit) {
    toggle_bit(first_bit);
    toggle_bit(second_bit);
}

bool Bitboard::contains_square(int square_idx) const {
    int at = bit_value_at(square_idx);
    if (at == -1) {
        return false;
    }

    return at != 0;
}

int Bitboard::pop_lsb(uint64_t& value) {
    if (value == 0) {
        return -1;
    }

    int index = __builtin_ctzll(value);
    value &= (value - 1);

    return index;
}

int Bitboard::bit_value_at(int index) const {
    if (!Coord::valid_square_idx(index)) {
        return -1;
    }

    return (m_BBoard >> index) & 1;
}

std::string Bitboard::bin_str() const {
    std::bitset<64> binary(m_BBoard);
    std::string binary_str = binary.to_string();
    std::ostringstream oss;

    for (size_t i = 0; i < binary_str.length(); i += 8) {
        oss << binary_str.substr(i, 8) << " ";
    }

    return oss.str();
}

std::string Bitboard::as_square_board_str() const {
    std::bitset<64> binary(m_BBoard);
    std::string binary_str = binary.to_string();
    std::ostringstream oss;

    for (size_t i = 0; i < binary_str.length(); i += 8) {
        std::string substr = binary_str.substr(i, 8);
        for (const auto& c : substr) {
            if (c == '0') {
                oss << ". ";
            } else {
                oss << c << " ";
            }
        }
        oss << "\n";
    }

    return oss.str();
}
