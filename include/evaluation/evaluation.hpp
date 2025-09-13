#pragma once

#include "evaluation/material.hpp"

/// Simple evaluation takes after Sebastian Lague's engine. This will not be the default.

class Evaluator {
  private:
    static constexpr std::array<int, 7> PP_BONUS{0, 120, 80, 50, 30, 15, 15};
    static constexpr std::array<int, 9> ISO_PAWN{0, -10, -25, -50, -75, -75, -75, -75, -75};
    static constexpr std::array<int, 6> KING_SHIELD{4, 7, 4, 3, 6, 3};

    Ref<Board> m_Board;

    // TODO: Set to true when NNUE suite is functional
    bool m_UseNNUE{false};

  private:
    // ================ Simple Evaluation ================
    struct SimpleEvalData {
        int MaterialScore;
        int MopUpScore;
        int PSTScore;
        int PawnScore;
        int PawnShieldScore;

        int sum() { return MaterialScore + MopUpScore + PSTScore + PawnScore + PawnShieldScore; }
    };

    static int individual_pst_score(const Piece& piece, Bitboard piece_bb,
                                    float endgame_transition);
    int combined_pst_score(const Bitboard& friendly_bb, Color friendly_color,
                           float endgame_transition);

    int pawn_score(Color color);
    int king_score(Color color, Material opponent_material, int opponent_pst_score);

    /// Awards evaluation for distances like center manhattan and chebyshev
    int mop_score(Color color, Material friendly_material, Material opponent_material);

    int simple_eval();

    // ================ NNUE Evaluation ================
    int nnue_eval();

  public:
    Evaluator(Ref<Board> board) : m_Board(board) {}

    Material get_material_score(Color color) const;
    Material get_friendly_score() const { return get_material_score(m_Board->sideToMove()); }
    Material get_opponent_score() const { return get_material_score(~m_Board->sideToMove()); }

    int evaluate();

    friend class Searcher;
};