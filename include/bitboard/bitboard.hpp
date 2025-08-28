#pragma once

class Bitboard {
  private:
    uint64_t m_BBoard;

  public:
    Bitboard() : m_BBoard(0) {};
    Bitboard(uint64_t value) : m_BBoard(value) {};

    void set_bit(int bit_to_set);
    void set_bit_unchecked(int bit_to_set);

    void clear_bit(int bit_to_clear);
    void clear_bit_unchecked(int bit_to_clear);

    void toggle_bit(int bit_to_set);
    void toggle_bits(int first_bit, int second_bit);
    bool contains_square(int square_idx) const;

    static int pop_lsb(uint64_t& value);
    int pop_lsb() { return pop_lsb(m_BBoard); }
    uint64_t value() const { return m_BBoard; }

    void clear() { m_BBoard = 0; }

    int bit_value_at(int index) const;

    std::string bin_str() const;
    std::string as_square_board_str() const;

    int popcount() const { return std::popcount(m_BBoard); };

    // ================ BITWISE ================

    friend Bitboard operator|(const Bitboard& a, const Bitboard& b) {
        return Bitboard(a.m_BBoard | b.m_BBoard);
    }
    friend Bitboard operator|(const Bitboard& a, const uint64_t& value) {
        return a | Bitboard(value);
    }

    friend Bitboard& operator|=(Bitboard& a, const Bitboard& b) {
        a.m_BBoard |= b.m_BBoard;
        return a;
    }
    friend Bitboard& operator|=(Bitboard& a, const uint64_t& value) {
        a.m_BBoard |= value;
        return a;
    }

    friend Bitboard operator&(const Bitboard& a, const Bitboard& b) {
        return Bitboard(a.m_BBoard & b.m_BBoard);
    }
    friend Bitboard operator&(const Bitboard& a, const uint64_t& value) {
        return a & Bitboard(value);
    }

    friend Bitboard& operator&=(Bitboard& a, const Bitboard& b) {
        a.m_BBoard &= b.m_BBoard;
        return a;
    }
    friend Bitboard& operator&=(Bitboard& a, const uint64_t& value) {
        a.m_BBoard &= value;
        return a;
    }

    friend Bitboard operator<<(const Bitboard& a, int shift) {
        return Bitboard(a.m_BBoard << shift);
    }

    friend Bitboard operator>>(const Bitboard& a, int shift) {
        return Bitboard(a.m_BBoard >> shift);
    }

    friend uint64_t operator<<(uint64_t value, const Bitboard& a) { return value << a.m_BBoard; }

    // ================ ARITHMETIC ================

    friend Bitboard operator+(const Bitboard& a, const Bitboard& b) {
        return Bitboard(a.m_BBoard + b.m_BBoard);
    }
    friend Bitboard operator+(const Bitboard& a, const uint64_t& value) {
        return a + Bitboard(value);
    }

    friend Bitboard operator-(const Bitboard& a, const Bitboard& b) {
        return Bitboard(a.m_BBoard - b.m_BBoard);
    }
    friend Bitboard operator-(const Bitboard& a, const uint64_t& value) {
        return a - Bitboard(value);
    }

    friend Bitboard operator*(const Bitboard& a, const Bitboard& b) {
        return Bitboard(a.m_BBoard * b.m_BBoard);
    }
    friend Bitboard operator*(const Bitboard& a, const uint64_t& value) {
        return a * Bitboard(value);
    }

    // ================ COMPARATIVE (fake overload) ================

    inline bool equals(const Bitboard& other) const { return m_BBoard == other.m_BBoard; }

    operator uint64_t() { return m_BBoard; }
    operator uint64_t() const { return m_BBoard; }
};