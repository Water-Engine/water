#pragma once

class Bitboard {
  private:
    uint64_t m_BBoard;

  public:
    Bitboard() : m_BBoard(0) {};
    Bitboard(uint64_t value) : m_BBoard(value) {};
    void set_bit(int bit_to_set);
    void toggle_bit(int bit_to_set);
    static int pop_lsb(uint64_t& value);
    int pop_lsb() { return pop_lsb(m_BBoard); }

    void clear() { m_BBoard = 0; }

    friend Bitboard operator|(const Bitboard& a, const Bitboard& b) {
        return Bitboard(a.m_BBoard | b.m_BBoard);
    }
    friend Bitboard operator&(const Bitboard& a, const Bitboard& b) {
        return Bitboard(a.m_BBoard & b.m_BBoard);
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

    operator uint64_t() { return m_BBoard; }
};