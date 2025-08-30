#pragma once

#include "game/board.hpp"
#include "game/piece.hpp"

const int INF = 1000000000;
const int NEG_INF = -INF;

// ================ MATERIAL SCORE ================

struct MaterialScore {
  private:
    static const int BISHOP_ENDGAME_WEIGHT = 10;
    static const int KNIGHT_ENDGAME_WEIGHT = 10;
    static const int ROOK_ENDGAME_WEIGHT = 20;
    static const int QUEEN_ENDGAME_WEIGHT = 45;
    static constexpr int ENDGAME_START_WEIGHT = 2 * BISHOP_ENDGAME_WEIGHT +
                                                2 * KNIGHT_ENDGAME_WEIGHT +
                                                2 * ROOK_ENDGAME_WEIGHT + QUEEN_ENDGAME_WEIGHT;

  public:
    int Aggregate;

    int NumPawns;
    int NumKnights;
    int NumBishops;
    int NumRooks;
    int NumQueens;

    int NumMajors;
    int NumMinors;

    uint64_t FriendlyPawns;
    uint64_t EnemyPawns;

    float EndgameTransition;

    MaterialScore(int num_pawns, int num_knights, int num_bishops, int num_rooks, int num_queens,
                  uint64_t friendly_pawns, uint64_t enemy_pawns);

    inline int non_pawn_score() const { return Aggregate - pawn_score(); }
    inline int pawn_score() const { return PieceScores::Pawn * NumPawns; }
};

// ================ EVALUATOR ================

class Evaluator {
  private:
    Ref<Board> m_Board;

  private:
    MaterialScore get_score(PieceColor color) const;
    template <PieceColor Color> MaterialScore get_score() const {
        auto friendly_color_bb =
            (Color == PieceColor::White) ? m_Board->m_WhiteBB : m_Board->m_BlackBB;
        auto enemy_color_bb =
            (Color == PieceColor::White) ? m_Board->m_BlackBB : m_Board->m_WhiteBB;

        auto friendly_pawns = friendly_color_bb | m_Board->m_PawnBB;
        auto enemy_pawns = enemy_color_bb | m_Board->m_PawnBB;
        auto friendly_knights = friendly_color_bb | m_Board->m_KnightBB;
        auto friendly_bishops = friendly_color_bb | m_Board->m_BishopBB;
        auto friendly_rooks = friendly_color_bb | m_Board->m_RookBB;
        auto friendly_queens = friendly_color_bb | m_Board->m_QueenBB;

        return MaterialScore(friendly_pawns.popcount(), friendly_knights.popcount(),
                             friendly_bishops.popcount(), friendly_rooks.popcount(),
                             friendly_queens.popcount(), friendly_pawns.value(),
                             enemy_pawns.value());
    }

  public:
    Evaluator(Ref<Board> board) : m_Board(board) {}
};