#pragma once

#include "core.hpp"

class GameState {
  private:
    bool m_WhiteCastleKingside;
    bool m_WhiteCastleQueenside;
    bool m_BlackCastleKingside;
    bool m_BlackCastleQueenside;

    int m_EpSquare;

  public:
    GameState() = default;
    GameState(bool wck, bool wcq, bool bck, bool bcq, int ep_square)
        : m_WhiteCastleKingside(wck), m_WhiteCastleQueenside(wcq), m_BlackCastleKingside(bck),
          m_BlackCastleQueenside(bcq), m_EpSquare(ep_square) {}
};

class Zobrist {
  private:
  public:
};