#pragma once

class Bitboard {
  private:
    uint64_t m_BBoard;

  public:
    Bitboard() : m_BBoard(0) {};
    Bitboard(uint64_t value) : m_BBoard(value) {};

    void set_bit(int bit_to_set);
    void clear_bit(int bit_to_set);
    void toggle_bit(int bit_to_set);
    void toggle_bits(int first_bit, int second_bit);

    static int pop_lsb(uint64_t& value);
    int pop_lsb() { return pop_lsb(m_BBoard); }

    void clear() { m_BBoard = 0; }

    int bit_value_at(int index);

    std::string bin_str() const;
    std::string as_square_board_str() const;

    friend Bitboard operator|(const Bitboard& a, const Bitboard& b) {
        return Bitboard(a.m_BBoard | b.m_BBoard);
    }
    friend Bitboard operator|(const Bitboard& a, const uint64_t& value) {
        return a | Bitboard(value);
    }
    friend Bitboard operator&(const Bitboard& a, const Bitboard& b) {
        return Bitboard(a.m_BBoard & b.m_BBoard);
    }
    friend Bitboard operator&(const Bitboard& a, const uint64_t& value) {
        return a & Bitboard(value);
    }
    friend Bitboard operator+(const Bitboard& a, const Bitboard& b) {
        return Bitboard(a.m_BBoard + b.m_BBoard);
    }
    friend Bitboard operator-(const Bitboard& a, const Bitboard& b) {
        return Bitboard(a.m_BBoard - b.m_BBoard);
    }
    friend Bitboard operator*(const Bitboard& a, const Bitboard& b) {
        return Bitboard(a.m_BBoard * b.m_BBoard);
    }
    friend Bitboard operator*(const Bitboard& a, const uint64_t& value) {
        return a * Bitboard(value);
    }

    operator uint64_t() { return m_BBoard; }
};