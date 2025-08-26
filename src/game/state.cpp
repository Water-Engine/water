#include <pch.hpp>

#include "game/state.hpp"

GameState::GameState()
    : m_WhiteCastleKingside(false), m_WhiteCastleQueenside(false), m_BlackCastleKingside(false),
      m_BlackCastleQueenside(false), m_EpSquare(-1), m_HalfmoveClock(0),
      m_LastMoveWasCapture(false), m_LastMoveWasPawnMove(false) {}

GameState::GameState(bool wck, bool wcq, bool bck, bool bcq, int ep_square, int hmc)
    : m_WhiteCastleKingside(wck), m_WhiteCastleQueenside(wcq), m_BlackCastleKingside(bck),
      m_BlackCastleQueenside(bcq), m_EpSquare(ep_square), m_HalfmoveClock(hmc),
      m_LastMoveWasCapture(false), m_LastMoveWasPawnMove(false) {}