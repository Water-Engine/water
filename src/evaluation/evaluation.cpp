#include <pch.hpp>

#include "evaluation/evaluation.hpp"

#include "generator/generator.hpp"

#include "game/move.hpp"

MaterialScore::MaterialScore(int num_pawns, int num_knights, int num_bishops, int num_rooks,
                             int num_queens, uint64_t friendly_pawns, uint64_t enemy_pawns)
    : NumPawns(num_pawns), NumKnights(num_knights), NumBishops(num_bishops), NumRooks(num_rooks),
      NumQueens(num_queens), NumMajors(num_rooks + num_queens),
      NumMinors(num_bishops + num_knights), FriendlyPawns(friendly_pawns), EnemyPawns(enemy_pawns) {
    Aggregate = 0;
    Aggregate += NumPawns * PieceScores::Pawn;
    Aggregate += NumKnights * PieceScores::Knight;
    Aggregate += NumBishops * PieceScores::Bishop;
    Aggregate += NumRooks * PieceScores::Rook;
    Aggregate += NumQueens * PieceScores::Queen;

    float endgame_weight_sum = NumKnights * KNIGHT_ENDGAME_WEIGHT +
                               NumBishops * BISHOP_ENDGAME_WEIGHT + NumRooks * ROOK_ENDGAME_WEIGHT +
                               NumQueens * QUEEN_ENDGAME_WEIGHT;
    EndgameTransition = 1.0f - std::min(1.0f, endgame_weight_sum / (float)ENDGAME_START_WEIGHT);
}

MaterialScore Evaluator::get_score(PieceColor color) const {
    if (color == PieceColor::White) {
        return get_score<PieceColor::White>();
    } else {
        return get_score<PieceColor::Black>();
    }
}

int Evaluator::negamax(int depth) {
    if (depth == 0) {
        return evaluate();
    }

    int max = -INF;
    auto all_moves = Generator::generate(*m_Board);

    for (auto& move : all_moves) {
        m_Board->make_move(move, false);
        int score = -negamax(depth - 1);
        m_Board->unmake_last_move(false);

        if (score > max) {
            max = score;
        }
    }

    return max;
}

std::pair<Move, int> Evaluator::root_negamax(int depth) {
    Move best_move(0);
    int max = -INF;
    auto all_moves = Generator::generate(*m_Board);

    for (auto& move : all_moves) {
        m_Board->make_move(move, false);
        int score = -negamax(depth - 1);
        m_Board->unmake_last_move(false);

        if (score > max) {
            max = score;
            best_move = move;
        }
    }

    return {best_move, max};
}

int Evaluator::evaluate() { return get_score(m_Board->color_to_move()).Aggregate; }

int Evaluator::evaluate(int depth) {
    auto eval = root_negamax(depth);
    fmt::println("bestmove {}", eval.first.to_uci());
    return eval.second;
}