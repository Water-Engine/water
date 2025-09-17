#pragma once

#include "evaluation/material.hpp"

/// Simple evaluation takes after Sebastian Lague's engine. This will not be the default.

class Evaluator {
  private:
    using VictimValue = int;
    using AttackerValue = int;

    static constexpr std::array<int, 7> PP_BONUS{0, 120, 80, 50, 30, 15, 15};
    static constexpr std::array<int, 9> ISO_PAWN{0, -10, -25, -50, -75, -75, -75, -75, -75};
    static constexpr std::array<int, 6> KING_SHIELD{4, 7, 4, 3, 6, 3};

    Ref<chess::Board> m_Board;

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

    static int individual_pst_score(const chess::Piece& piece, chess::Bitboard piece_bb,
                                    float endgame_transition);
    int combined_pst_score(const chess::Bitboard& friendly_bb, chess::Color friendly_color,
                           float endgame_transition);

    int pawn_score(chess::Color color);
    int king_score(chess::Color color, Material opponent_material, int opponent_pst_score);

    /// Awards evaluation for distances like center manhattan and chebyshev
    int mop_score(chess::Color color, Material friendly_material, Material opponent_material);

    int simple_eval();

    // ================ NNUE Evaluation ================
    int nnue_eval();

  public:
    Evaluator(Ref<chess::Board> board) : m_Board(board) {}

    Material get_material(chess::Color color) const;
    Material get_friendly_material() const { return get_material(m_Board->sideToMove()); }
    Material get_opponent_material() const { return get_material(~m_Board->sideToMove()); }

    int evaluate();

    int see(const chess::Move& move);
    std::pair<VictimValue, AttackerValue> mvv_lva(const chess::Move& move);
    std::pair<chess::Piece, chess::Square> least_valuable_attacker(chess::Bitboard attackers);

    friend class Searcher;
};