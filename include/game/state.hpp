#pragma once

#include "game/piece.hpp"

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

    bool m_WasEpCaptured;
    PieceType m_CapturedPieceType;

  public:
    GameState() = default;
    GameState(bool wck, bool wcq, bool bck, bool bcq, int ep_square, int hmc);

    inline bool can_white_kingside() const { return m_WhiteCastleKingside; }
    inline bool can_black_kingside() const { return m_BlackCastleKingside; }
    inline bool can_white_queenside() const { return m_WhiteCastleQueenside; }
    inline bool can_black_queenside() const { return m_BlackCastleQueenside; }

    inline void white_lost_kingside_right() { m_WhiteCastleKingside = false; }
    inline void black_lost_kingside_right() { m_BlackCastleKingside = false; }
    inline void white_lost_queenside_right() { m_WhiteCastleQueenside = false; }
    inline void black_lost_queenside_right() { m_BlackCastleQueenside = false; }

    inline int pop_ep_square() {
        int previous = m_EpSquare;
        m_EpSquare = -1;
        return previous;
    }

    inline int halfmove_clock() const { return m_HalfmoveClock; }
    inline bool was_last_move_capture() const { return m_LastMoveWasCapture; }
    inline bool was_last_move_pawn() const { return m_LastMoveWasPawnMove; }
    inline void indicate_pawn_move() { m_LastMoveWasPawnMove = true; }
    inline void indicate_capture() { m_LastMoveWasCapture = true; }
    inline void reset_halfmove_clock() {
        m_HalfmoveClock = 0;
        m_LastMoveWasCapture = false;
        m_LastMoveWasPawnMove = false;
    }

    inline void try_reset_halfmove_clock() {
        if (m_LastMoveWasCapture || m_LastMoveWasPawnMove) {
            reset_halfmove_clock();
        } else {
            m_HalfmoveClock += 1;
        }
    }

    inline void capture_piece(const Piece& piece) {
        m_CapturedPieceType = piece.type();
        indicate_capture();
    }

    inline bool was_piece_captured() const { return m_CapturedPieceType != PieceType::None; }
    inline PieceType captured_piece_type() const { return m_CapturedPieceType; }

    inline void capture_ep() { m_WasEpCaptured = true; }
    inline bool was_ep_captured() const { return m_WasEpCaptured; }

    inline void clear_ep() { m_EpSquare = -1; }
    inline void set_ep(int ep_square) { m_EpSquare = ep_square; }
    inline int get_ep_square() const { return m_EpSquare; }
};

class Zobrist {
  private:
  public:
};