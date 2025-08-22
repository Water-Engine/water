#pragma once

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

    bool can_white_kingside() const { return m_WhiteCastleKingside; }
    bool can_black_kingside() const { return m_BlackCastleKingside; }
    bool can_white_queenside() const { return m_WhiteCastleQueenside; }
    bool can_black_queenside() const { return m_BlackCastleQueenside; }

    void white_lost_kingside_right() { m_WhiteCastleKingside = false; }
    void black_lost_kingside_right() { m_BlackCastleKingside = false; }
    void white_lost_queenside_right() { m_WhiteCastleQueenside = false; }
    void black_lost_queenside_right() { m_BlackCastleQueenside = false; }

    int pop_ep_square() {
        int previous = m_EpSquare;
        m_EpSquare = -1;
        return previous;
    }

    void clear_ep() { m_EpSquare = -1; }
    void set_ep(int ep_square) { m_EpSquare = ep_square; }
};

class Zobrist {
  private:
  public:
};