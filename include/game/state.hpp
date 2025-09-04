#pragma once

#include "bitboard/bitboard.hpp"
#include "game/piece.hpp"

class GameState {
  public:
    int EpSquare;
    int HalfmoveClock;
    int CastlingRights;
    uint64_t Hash;

    Piece MovedPiece;
    Piece CapturedPiece;
    int CapturedSquare;

  public:
    GameState()
        : EpSquare(-1), HalfmoveClock(0), CastlingRights(0b1111), Hash(0), MovedPiece(Pieces::NONE),
          CapturedPiece(Pieces::NONE), CapturedSquare(-1) {}

    GameState(bool wk, bool wq, bool bk, bool bq, int ep, int halfmove)
        : EpSquare(ep), HalfmoveClock(halfmove), Hash(0), MovedPiece(Pieces::NONE),
          CapturedPiece(Pieces::NONE), CapturedSquare(-1) {
        CastlingRights = 0;
        if (wk) {
            CastlingRights |= 1;
        }
        if (wq) {
            CastlingRights |= 2;
        }
        if (bk) {
            CastlingRights |= 4;
        }
        if (bq) {
            CastlingRights |= 8;
        }
    }

    inline void try_reset_halfmove_clock() {
        if (!CapturedPiece.is_none() || CapturedPiece.is_pawn()) {
            HalfmoveClock = 0;
        } else {
            HalfmoveClock += 1;
        }
    }

    // Query castling availability
    inline bool can_white_kingside() const { return CastlingRights & (1 << 0); }
    inline bool can_white_queenside() const { return CastlingRights & (1 << 1); }
    inline bool can_black_kingside() const { return CastlingRights & (1 << 2); }
    inline bool can_black_queenside() const { return CastlingRights & (1 << 3); }

    inline bool has_castle_right(PieceColor color, bool kingside) const {
        if (color == PieceColor::White) {
            if (kingside) {
                return can_white_kingside();
            } else {
                return can_white_queenside();
            }
        } else {
            if (kingside) {
                return can_black_kingside();
            } else {
                return can_black_queenside();
            }
        }
    }

    inline bool can_anyone_castle() const {
        return can_white_kingside() || can_white_queenside() || can_black_kingside() ||
               can_black_queenside();
    }

    // Revoke castling rights
    inline void white_lost_kingside_right() { CastlingRights &= ~(1 << 0); }
    inline void white_lost_queenside_right() { CastlingRights &= ~(1 << 1); }
    inline void black_lost_kingside_right() { CastlingRights &= ~(1 << 2); }
    inline void black_lost_queenside_right() { CastlingRights &= ~(1 << 3); }

    inline void revoke_castle_rights(PieceColor color) {
        if (color == PieceColor::White) {
            white_lost_kingside_right();
            white_lost_queenside_right();
        } else {
            black_lost_kingside_right();
            black_lost_queenside_right();
        }
    }

    friend bool operator==(const GameState& a, const GameState& b) {
        bool same_castle = a.CastlingRights == b.CastlingRights;
        bool same_ep = a.EpSquare == b.EpSquare;
        bool same_clock = a.HalfmoveClock == b.HalfmoveClock;
        bool same_move_piece = a.MovedPiece == b.MovedPiece;
        bool same_capture_piece = a.CapturedPiece == b.CapturedPiece;
        bool same_capture_square = a.CapturedSquare == b.CapturedSquare;
        bool same_hash = a.Hash == b.Hash;

        if (!(same_castle && same_ep && same_clock && same_move_piece && same_capture_piece &&
              same_capture_square && same_hash)) {
            std::cerr << "GameState mismatch:\n";
            if (!same_castle)
                std::cerr << "  CastlingRights differ: " << a.CastlingRights << " vs "
                          << b.CastlingRights << "\n";
            if (!same_ep)
                std::cerr << "  EpSquare differ: " << a.EpSquare << " vs " << b.EpSquare << "\n";
            if (!same_clock)
                std::cerr << "  HalfmoveClock differ: " << a.HalfmoveClock << " vs "
                          << b.HalfmoveClock << "\n";
            if (!same_move_piece)
                std::cerr << "  MovedPiece differ: " << (int)a.MovedPiece << " vs "
                          << (int)b.MovedPiece << "\n";
            if (!same_capture_piece)
                std::cerr << "  CapturedPiece differ: " << (int)a.CapturedPiece << " vs "
                          << (int)b.CapturedPiece << "\n";
            if (!same_capture_square)
                std::cerr << "  CapturedSquare differ: " << a.CapturedSquare << " vs "
                          << b.CapturedSquare << "\n";
            if (!same_hash)
                std::cerr << "  Hash differ: " << a.Hash << " vs " << b.Hash << "\n";
        }

        return same_castle && same_ep && same_clock && same_move_piece && same_capture_piece &&
               same_capture_square && same_hash;
    }
};

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

class GameStateOld {
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
    uint64_t Hash;

  public:
    GameStateOld();
    GameStateOld(bool wck, bool wcq, bool bck, bool bcq, int ep_square, int hmc);

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

    inline uint64_t hash() const { return Hash; }
    inline void hash(uint64_t& hash) { Hash = hash; }

    inline int castle_flags_mask() const {
        int castling_mask = 0b0000;
        if (m_WhiteCastleKingside) {
            castling_mask |= 0b0001;
        }
        if (m_WhiteCastleQueenside) {
            castling_mask |= 0b0010;
        }
        if (m_BlackCastleKingside) {
            castling_mask |= 0b0100;
        }
        if (m_BlackCastleQueenside) {
            castling_mask |= 0b1000;
        }

        return castling_mask;
    }

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

    friend bool operator==(const GameStateOld& a, const GameStateOld& b) {
        bool same_castle = (a.m_WhiteCastleKingside == b.m_WhiteCastleKingside) &&
                           (a.m_WhiteCastleQueenside == b.m_WhiteCastleQueenside) &&
                           (a.m_BlackCastleKingside == b.m_BlackCastleKingside) &&
                           (a.m_BlackCastleQueenside == b.m_BlackCastleQueenside);
        bool same_ep = a.m_EpSquare == b.m_EpSquare;
        bool same_clock = a.m_HalfmoveClock == b.m_HalfmoveClock;
        bool same_capture = a.m_LastMoveWasCapture == b.m_LastMoveWasCapture;
        bool same_pawn = a.m_LastMoveWasPawnMove == b.m_LastMoveWasPawnMove;

        for (size_t i = 0; i < 64; ++i) {
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