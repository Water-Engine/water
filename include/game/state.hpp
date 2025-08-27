#pragma once

#include "bitboard/bitboard.hpp"
#include "game/piece.hpp"

struct BoardBoards {
    std::array<Piece, 64> StoredPieces;

    Bitboard WhiteBB;
    Bitboard BlackBB;

    Bitboard PawnBB;
    Bitboard KnightBB;
    Bitboard BishopBB;
    Bitboard RookBB;
    Bitboard QueenBB;
    Bitboard KingBB;

    Bitboard AllPieceBB;
};

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

    // Naive make/unmake move
    std::array<Piece, 64> m_StoredPieces;

    Bitboard m_WhiteBB;
    Bitboard m_BlackBB;

    Bitboard m_PawnBB;
    Bitboard m_KnightBB;
    Bitboard m_BishopBB;
    Bitboard m_RookBB;
    Bitboard m_QueenBB;
    Bitboard m_KingBB;

    Bitboard m_AllPieceBB;

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

    inline bool can_anyone_castle() const {
        return m_WhiteCastleKingside || m_BlackCastleKingside || m_WhiteCastleQueenside ||
               m_BlackCastleQueenside;
    }

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

    inline void clear_ep() { m_EpSquare = -1; }
    inline void set_ep(int ep_square) { m_EpSquare = ep_square; }
    inline int get_ep_square() const { return m_EpSquare; }

    inline void cache_board(const std::array<Piece, 64>& stored_pieces, const Bitboard& white_bb,
                            const Bitboard& black_bb, const Bitboard& pawn_bb,
                            const Bitboard& knight_bb, const Bitboard& bishop_bb,
                            const Bitboard& rook_bb, const Bitboard& queen_bb,
                            const Bitboard& king_bb, const Bitboard& all_piece) {
        m_StoredPieces = stored_pieces;
        m_WhiteBB = white_bb;
        m_BlackBB = black_bb;
        m_PawnBB = pawn_bb;
        m_KnightBB = knight_bb;
        m_BishopBB = bishop_bb;
        m_RookBB = rook_bb;
        m_QueenBB = queen_bb;
        m_KingBB = king_bb;
        m_AllPieceBB = all_piece;
    }

    inline BoardBoards get_cache() const {
        return BoardBoards{
            .StoredPieces = m_StoredPieces,
            .WhiteBB = m_WhiteBB,
            .BlackBB = m_BlackBB,
            .PawnBB = m_PawnBB,
            .KnightBB = m_KnightBB,
            .BishopBB = m_BishopBB,
            .RookBB = m_RookBB,
            .QueenBB = m_QueenBB,
            .KingBB = m_KingBB,
            .AllPieceBB = m_AllPieceBB,
        };
    }

    friend bool operator==(const GameState& a, const GameState& b) {
        bool same_castle = (a.m_WhiteCastleKingside == b.m_WhiteCastleKingside) &&
                           (a.m_WhiteCastleQueenside == b.m_WhiteCastleQueenside) &&
                           (a.m_BlackCastleKingside == b.m_BlackCastleKingside) &&
                           (a.m_BlackCastleQueenside == b.m_BlackCastleQueenside);
        bool same_ep = a.m_EpSquare == b.m_EpSquare;
        bool same_clock = a.m_HalfmoveClock == b.m_HalfmoveClock;
        bool same_capture = a.m_LastMoveWasCapture == b.m_LastMoveWasCapture;
        bool same_pawn = a.m_LastMoveWasPawnMove == b.m_LastMoveWasPawnMove;

        for (size_t i = 0; i < 64; i++) {
            if (a.m_StoredPieces[i] != b.m_StoredPieces[i]) {
                return false;
            }
        }

        bool boards_match =
            (a.m_WhiteBB.equals(b.m_WhiteBB)) && (a.m_BlackBB.equals(b.m_BlackBB)) &&
            (a.m_PawnBB.equals(b.m_PawnBB)) && (a.m_KnightBB.equals(b.m_KnightBB)) &&
            (a.m_BishopBB.equals(b.m_BishopBB)) && (a.m_RookBB.equals(b.m_RookBB)) &&
            (a.m_QueenBB.equals(b.m_QueenBB)) && (a.m_KingBB.equals(b.m_KingBB)) &&
            (a.m_AllPieceBB.equals(b.m_AllPieceBB));

        return same_castle & same_ep & same_clock & same_capture & same_pawn & boards_match;
    }

    friend class Board;
};

// Randomly generated seed for hashing reproducibility
const uint64_t SEED = 18274927;

struct Zobrist {
    static uint64_t Pieces[12][64];
    static uint64_t Castling[16];
    static uint64_t EnPassant[8];
    static uint64_t Side;

    static void init();
};