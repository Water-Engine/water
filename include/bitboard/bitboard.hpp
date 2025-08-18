#pragma once

class Bitboard {
  private:
    uint64_t m_BBoard;

  public:
    Bitboard() = default;
    void set_bit(int bit_to_set);
    void toggle_bit(int bit_to_set);
};