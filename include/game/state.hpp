#pragma once

class GameState {
  private:
    bool m_WhiteCastleKingside;
    bool m_WhiteCastleQueenside;
    bool m_BlackCastleKingside;
    bool m_BlackCastleQueenside;

    int m_EpSquare;
    int m_HalfmoveClock;

    bool m_LastMoveWasCapture;
    bool m_LastMoveWasPawnMove;

  public:
    GameState() = default;
    GameState(bool wck, bool wcq, bool bck, bool bcq, int ep_square, int hmc)
        : m_WhiteCastleKingside(wck), m_WhiteCastleQueenside(wcq), m_BlackCastleKingside(bck),
          m_BlackCastleQueenside(bcq), m_EpSquare(ep_square), m_HalfmoveClock(hmc),
          m_LastMoveWasCapture(false), m_LastMoveWasPawnMove(false) {}

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

    int halfmove_clock() const { return m_HalfmoveClock; }
    bool was_last_move_capture() const { return m_LastMoveWasCapture; }
    bool was_last_move_pawn() const { return m_LastMoveWasPawnMove; }
    void indicate_pawn_move() { m_LastMoveWasPawnMove = true; }
    void indicate_capture() { m_LastMoveWasCapture = true; }
    void reset_halfmove_clock() {
        m_HalfmoveClock = 0;
        m_LastMoveWasCapture = false;
        m_LastMoveWasPawnMove = false;
    }

    void try_reset_halfmove_clock() {
        if (m_LastMoveWasCapture || m_LastMoveWasPawnMove) {
            reset_halfmove_clock();
        } else {
            m_HalfmoveClock += 1;
        }
    }

    void clear_ep() { m_EpSquare = -1; }
    void set_ep(int ep_square) { m_EpSquare = ep_square; }
    int get_ep_square() const { return m_EpSquare; }
};

class Zobrist {
  private:
  public:
};