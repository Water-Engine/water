#include <pch.hpp>

#include "evaluation/evaluation.hpp"
#include "evaluation/ordering.hpp"
#include "evaluation/pst.hpp"

void MoveOrderer::order_moves(Ref<Board> board, const Move& hash_move, MoveList& moves,
                              bool in_quiescence, size_t ply) {
    PROFILE_FUNCTION();
    for (size_t i = 0; i < moves.size(); ++i) {
        auto move = moves[i];

        // Highest priority to previously evaluated moves
        if (move == hash_move) {
            moves.set_score(i, HASH_MOVE_BIAS);
            continue;
        }

        // Move data extraction and score prep
        int score = UNBIASED;
        int start_square = move.start_square();
        int target_square = move.target_square();

        Piece piece_to_move = board->piece_at(start_square);
        Piece piece_to_capture = board->piece_at(target_square);
        bool is_capture = !piece_to_capture.is_none();

        Bitboard opponent_non_pawn_attacks = board->non_pawn_attack_rays(board->opponent_color());
        Bitboard opponent_pawn_attacks = board->pawn_attack_rays(board->opponent_color());
        Bitboard all_opponent_attacks = opponent_non_pawn_attacks | opponent_pawn_attacks;

        Evaluator evaluator(board);
        float endgame_transition = evaluator.get_friendly_score().EndgameTransition;
        auto& pst = PSTManager::instance();

        // Capture handling
        if (is_capture) {
            // TODO: Switch to static exchange evaluation
            int capture_delta = piece_to_capture.score() - piece_to_move.score();
            bool opponent_can_recapture = all_opponent_attacks.contains_square(target_square);

            if (opponent_can_recapture) {
                score += capture_delta >= 0 ? WINNING_CAPTURE_BIAS : LOSING_CAPTURE_BIAS;
            } else {
                score += WINNING_CAPTURE_BIAS;
            }
            score += capture_delta;
        } else {
            // There is no concept of killer moves in quiescence search
            bool is_killer =
                !in_quiescence && ply < MAX_KILLER_MOVE_PLY && m_KillersHeuristic[ply] == move;
            score += is_killer ? KILLER_MOVE_BIAS : UNBIASED;
            score += m_HistoryHeuristic[color_as_idx(board->friendly_color())][start_square]
                                       [target_square];
        }

        // Evaluations with PSTs
        if (piece_to_move.is_pawn() || piece_to_move.is_king()) {
            int score_from =
                pst.get_value_tapered_unchecked(piece_to_move, start_square, endgame_transition);
            int score_to =
                pst.get_value_tapered_unchecked(piece_to_move, target_square, endgame_transition);
            score += score_to - score_from;
        } else {
            // Phase does not matter here as Pawns & Kings are only non-unified pieces
            int score_from = pst.get_value_unchecked(piece_to_move, start_square);
            int score_to = pst.get_value_unchecked(piece_to_move, target_square);
            score += score_to - score_from;
        }

        if (piece_to_move.is_pawn()) {
            // Contend with non-capture promotions, only award bias for knights and queens
            if (!is_capture) {
                if (move.is_queen_promotion()) {
                    score += PROMOTING_MOVE_BIAS;
                } else if (move.is_knight_promotion()) {
                    score += PROMOTING_MOVE_BIAS / 2;
                }
            }
        } else if (piece_to_move.is_king()) {
            // Castling should be preferred, and kingside should be slightly better usually
            if (move.is_kingside_castle()) {
                score += 25;
            } else {
                score += 20;
            }
            // TODO: Castling may not always be necessary, may need to contend with in future
        } else {
            // Allowing a pawn to take our piece is worse than something of higher value
            if (opponent_pawn_attacks.contains_square(target_square)) {
                score -= 50;
            } else if (opponent_non_pawn_attacks.contains_square(target_square)) {
                score -= 25;
            }
        }

        moves.set_score(i, score);
    }

    moves.sort_by_scores();
}

inline std::string MoveOrderer::label_of_index(const MoveList& moves, size_t idx) const {
    auto idx_score = moves.score_at(idx);
    std::string name = "";

    int best_delta = INT_MAX;
    for (const auto& bias : BIASES) {
        int delta = std::abs(idx_score - bias.first);
        if (delta < best_delta) {
            best_delta = delta;
            name = bias.second;
        }
    }

    return fmt::interpolate("{} ({})", idx_score, name);
}