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
    for (int p = 0; p < 12; p++) {
        for (int sq = 0; sq < 64; sq++) {
            Pieces[p][sq] = dist(rng);
        }
    }

    // Castling
    for (int i = 0; i < 16; i++) {
        Castling[i] = dist(rng);
    }

    // En passant
    for (int f = 0; f < 8; f++) {
        EnPassant[f] = dist(rng);
    }

    // Side to move
    Side = dist(rng);
}

void Board::update_hash(const ValidatedMove& move, int old_castling_mask, int old_ep_square,
                        const Piece& captured_piece) {
    m_State.Hash ^= Zobrist::Side;
    m_State.Hash ^= Zobrist::Castling[old_castling_mask];
}