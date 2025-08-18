#pragma once

#include "core.hpp"

constexpr std::string_view STARTING_FEN =
    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

/*
 * Reading:
 * Bitboard information: https://www.chessprogramming.org/Bitboards#The_Board_of_Sets
 * High-level Overview:
 * https://dev.to/namanvashistha/building-a-modern-chess-engine-a-deep-dive-into-bitboard-based-move-generation-345d
 * FEN notation: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation
 */

class PositionInfo {
  public:
    std::string fen;
    std::array<int, 64> squares;

    bool white_castle_kingside;
    bool black_castle_kingside;
    bool white_castle_queenside;
    bool black_castle_queenside;

    int ep_file;
    bool white_to_move;
    int halfmove_clock;
    int move_count;

  public:
    PositionInfo(std::string fen);
};

class Board {
  private:
    uint64_t m_WhiteBB = 0;
    uint64_t m_BlackBB = 0;
    uint64_t m_PawnBB = 0;
    uint64_t m_KnightBB = 0;
    uint64_t m_BishopBB = 0;
    uint64_t m_RookBB = 0;
    uint64_t m_QueenBB = 0;
    uint64_t m_KingBB = 0;

  public:
    Board() {}

    Result<void, std::string> load_from_fen(const std::string& fen);
    std::string to_string();
};