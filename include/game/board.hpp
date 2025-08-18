#pragma once

#include "core.hpp"

constexpr std::string_view STARTING_FEN =
    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

constexpr std::string_view FILES = "abcdefgh";
constexpr std::string_view RANKS = "12345678";

class Coord {
  private:
    int m_FileIdx;
    int m_RankIdx;

  public:
    Coord() : m_FileIdx(-1), m_RankIdx(-1) {}
    Coord(int file_idx, int rank_idx) : m_FileIdx(file_idx), m_RankIdx(rank_idx) {}

    Coord(const std::string& square_string);
    Coord(int square);

    int file_idx() const { return m_FileIdx; }
    int rank_idx() const { return m_RankIdx; }
    int square_idx() const { return m_RankIdx * 8 + m_FileIdx; }
};

/*
 * Reading:
 * Bitboard information: https://www.chessprogramming.org/Bitboards#The_Board_of_Sets
 * High-level Overview:
 * https://dev.to/namanvashistha/building-a-modern-chess-engine-a-deep-dive-into-bitboard-based-move-generation-345d
 * FEN notation: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation
 */

class PositionInfo {
  public:
    std::string m_Fen;
    std::array<int, 64> m_Squares;
    bool m_WhiteToMove;

    bool m_WhiteCastleKingside;
    bool m_WhiteCastleQueenside;
    bool m_BlackCastleKingside;
    bool m_BlackCastleQueenside;

    int m_EpFile;
    int m_HalfmoveClock;
    int m_MoveClock;

  private:
    PositionInfo(std::string fen, std::array<int, 64> squares, bool white_to_move, bool wck,
                 bool wcq, bool bck, bool bcq, int ep, int halfmove_clock, int move_clock)
        : m_Fen(fen), m_Squares(squares), m_WhiteToMove(white_to_move), m_WhiteCastleKingside(wck),
          m_WhiteCastleQueenside(wcq), m_BlackCastleKingside(bck), m_BlackCastleQueenside(bcq),
          m_EpFile(ep), m_HalfmoveClock(halfmove_clock), m_MoveClock(move_clock) {}

  public:
    PositionInfo() = default;
    static Result<PositionInfo, std::string> from_fen(const std::string& fen);
};

class Board {
  private:
    PositionInfo m_StartPos;

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
