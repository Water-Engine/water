#include <pch.hpp>

#include "game/board.hpp"
#include "game/state.hpp"

GameState::GameState()
    : m_WhiteCastleKingside(false), m_WhiteCastleQueenside(false), m_BlackCastleKingside(false),
      m_BlackCastleQueenside(false), m_EpSquare(-1), m_HalfmoveClock(0),
      m_LastMoveWasCapture(false), m_LastMoveWasPawnMove(false) {}

GameState::GameState(bool wck, bool wcq, bool bck, bool bcq, int ep_square, int hmc)
    : m_WhiteCastleKingside(wck), m_WhiteCastleQueenside(wcq), m_BlackCastleKingside(bck),
      m_BlackCastleQueenside(bcq), m_EpSquare(ep_square), m_HalfmoveClock(hmc),
      m_LastMoveWasCapture(false), m_LastMoveWasPawnMove(false) {}

uint64_t Zobrist::Pieces[12][64];
uint64_t Zobrist::Castling[16];
uint64_t Zobrist::EnPassant[8];
uint64_t Zobrist::Side;

void Zobrist::init() {
    std::mt19937_64 rng(SEED);
    std::uniform_int_distribution<uint64_t> dist(0, UINT64_MAX);

    // Pieces
    for (int p = 0; p < 12; ++p) {
        for (int sq = 0; sq < 64; ++sq) {
            Pieces[p][sq] = dist(rng);
        }
    }

    // Castling
    for (int i = 0; i < 16; ++i) {
        Castling[i] = dist(rng);
    }

    // En passant
    for (int f = 0; f < 8; ++f) {
        EnPassant[f] = dist(rng);
    }

    // Side to move
    Side = dist(rng);
}

void Board::update_hash(const ValidatedMove& move, int old_castling_mask, int old_ep_square,
                        const Piece& captured_piece) {
    int start_square = move.StartCoord.square_idx_unchecked();
    int target_square = move.TargetCoord.square_idx_unchecked();

    // To-move
    m_State.Hash ^= Zobrist::Side;

    // Castling - XOR out old, XOR in new
    m_State.Hash ^= Zobrist::Castling[old_castling_mask];
    m_State.Hash ^= Zobrist::Castling[m_State.castle_flags_mask()];

    // EP - XOR in/out if valid
    if (Coord::valid_square_idx(old_ep_square)) {
        m_State.Hash ^= Zobrist::EnPassant[old_ep_square % 8];
    }

    int new_ep_square = m_State.get_ep_square();
    if (Coord::valid_square_idx(new_ep_square)) {
        m_State.Hash ^= Zobrist::EnPassant[new_ep_square % 8];
    }

// While compiler warning can be helpful, the PieceStart member is guaranteed to be non-none
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Warray-bounds"
    // Moved piece in/out
    m_State.Hash ^= Zobrist::Pieces[move.PieceStart.index()][start_square];
    m_State.Hash ^= Zobrist::Pieces[move.PieceStart.index()][target_square];
#pragma GCC diagnostic pop

    // Captured piece (if any)
    if (!captured_piece.is_none()) {
        m_State.Hash ^=
            Zobrist::Pieces[captured_piece.index()][move.StartCoord.square_idx_unchecked()];
    }

    // Promotion
    if (Move::is_promotion(move.MoveFlag)) {
        m_State.Hash ^=
            Zobrist::Pieces[Piece(PieceType::Pawn, move.PieceStart.color()).index()][target_square];
        m_State.Hash ^=
            Zobrist::Pieces[Move::promotion_piece(move.MoveFlag, move.PieceStart.color()).index()]
                           [target_square];
    }

    // Castling rook movement
    if (move.MoveFlag == CASTLE_FLAG) {
        using namespace Square;
        int rook_from, rook_to;
        if (target_square == G1) {
            rook_from = H1;
            rook_to = F1;
        } else if (target_square == C1) {
            rook_from = A1;
            rook_to = D1;
        } else if (target_square == G8) {
            rook_from = H8;
            rook_to = F8;
        } else if (target_square == C8) {
            rook_from = A8;
            rook_to = D8;
        } else {
            return;
        }

        Piece rook(PieceType::Rook, move.PieceStart.color());
        m_State.Hash ^= Zobrist::Pieces[rook.index()][rook_from];
        m_State.Hash ^= Zobrist::Pieces[rook.index()][rook_to];
    }

    if (captured_piece.is_none() && move.MoveFlag == PAWN_CAPTURE_FLAG) {
        int captured_square = (move.PieceStart.is_white()) ? target_square - 8 : target_square + 8;
        if (Coord::valid_square_idx(captured_square)) {
            Piece captured_pawn(PieceType::Pawn, opposite_color(move.PieceStart.color()));
            m_State.Hash ^= Zobrist::Pieces[captured_pawn.index()][captured_square];
        }
    }
}