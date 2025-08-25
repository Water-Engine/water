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
    Piece m_CapturedPiece;

    Piece m_MovedPiece;
    int m_MovedFrom;
    int m_MovedTo;
    int m_MoveFlag;

    // For castling only
    Piece m_RookPiece;
    int m_RookFrom;
    int m_RookTo;

  public:
    GameState();
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
        m_CapturedPiece = piece;
        indicate_capture();
    }

    inline bool was_piece_captured() const { return m_CapturedPieceType != PieceType::None; }
    inline Piece captured_piece() const { return m_CapturedPiece; }
    inline PieceType captured_piece_type() const { return m_CapturedPieceType; }

    inline void capture_ep() { m_WasEpCaptured = true; }
    inline bool was_ep_captured() const { return m_WasEpCaptured; }

    inline void clear_ep() { m_EpSquare = -1; }
    inline void set_ep(int ep_square) { m_EpSquare = ep_square; }
    inline int get_ep_square() const { return m_EpSquare; }

    inline void set_moved_piece(Piece moved) { m_MovedPiece = moved; }
    inline Piece get_moved_piece() const { return m_MovedPiece; }

    inline void set_moved_from(int idx) { m_MovedFrom = idx; }
    inline int get_moved_from() const { return m_MovedFrom; }

    inline void set_moved_to(int idx) { m_MovedTo = idx; }
    inline int get_moved_to() const { return m_MovedTo; }

    inline void set_move_flag(int flag) { m_MoveFlag = flag; }
    inline int get_move_flag() const { return m_MoveFlag; }

    inline void set_rook_piece(Piece piece) { m_RookPiece = piece; }
    inline Piece get_rook_piece() const { return m_RookPiece; }

    inline void set_rook_from(int rook_from_idx) { m_RookFrom = rook_from_idx; }
    inline int get_rook_from() const { return m_RookFrom; }

    inline void set_rook_to(int rook_to_idx) { m_RookTo = rook_to_idx; }
    inline int get_rook_to() const { return m_RookTo; }

    friend class Board;
};

class Zobrist {
  private:
  public:
};