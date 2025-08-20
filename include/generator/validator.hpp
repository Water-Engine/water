#pragma once

#include "bitboard/bitboard.hpp"

constexpr uint64_t A_FILE = 0x8080808080808080;

class Board;

class Validator {
  private:
    Ref<Board> m_Board;

    Bitboard m_FriendlyPieces;
    Bitboard m_EnemyPieces;
    Bitboard m_EnemySliderMask;

  public:
    Validator(Ref<Board> board);
};