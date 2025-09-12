#include <pch.hpp>

#include "evaluation/evaluation.hpp"
#include "evaluation/ordering.hpp"
#include "evaluation/pawn_shields.hpp"
#include "evaluation/pst.hpp"

int MoveOrderer::king_safety_bonus(Ref<Board> board, const Move& move) {
    Color c = board->sideToMove();
    int king_sq_after = move.to().index();
    Bitboard shield = PawnShields::instance().get(c, king_sq_after);

    // Count how many friendly pawns are protecting the squares
    int pawns_covering = 0;
    while (shield != 0) {
        int square = shield.pop();
        if (board->at(square).type() == PieceType::PAWN && board->at(square).color() == c) {
            pawns_covering += 10;
        }
    }

    return pawns_covering;
}

int MoveOrderer::shield_bias(Ref<Board> board, const Move& move) {
    Color c = board->sideToMove();

    // Skip if king hasn't moved yet (or not relevant)
    if (board->at(move.from().index()).type() == PieceType::KING)
        return 0;

    int from_sq = move.from().index();
    int to_sq = move.to().index();

    // Get shield for king's square
    int king_sq = board->kingSq(c).index();
    Bitboard shield = PawnShields::instance().get(c, king_sq);

    bool from_in_shield = shield.check(from_sq);
    bool to_in_shield = shield.check(to_sq);

    if (from_in_shield && !to_in_shield) {
        return -5;
    } else if (!from_in_shield && to_in_shield) {
        return +5;
    }
    return 0;
}

void MoveOrderer::order_moves(Ref<Board> board, const Move& hash_move, Movelist& moves,
                              bool in_quiescence, size_t ply) {
    PROFILE_FUNCTION();
    for (auto i = 0; i < moves.size(); ++i) {
        auto move = moves[i];

        // Highest priority to previously evaluated moves
        if (move == hash_move) {
            moves[i].setScore(HASH_MOVE_BIAS);
            continue;
        }

        // Move data extraction and score prep
        int16_t score = UNBIASED;
        int start_square = move.from().index();
        int target_square = move.to().index();

        Piece piece_to_move = board->at(start_square);
        Piece piece_to_capture = is_capture(move, board).unwrap_or(Piece::NONE);
        bool is_capture = piece_to_capture.type() != PieceType::NONE;

        Bitboard opponent_non_pawn_attacks = non_pawn_attacks(board, ~board->sideToMove());
        Bitboard opponent_pawn_attacks = pawn_attacks(board, ~board->sideToMove());
        Bitboard all_opponent_attacks = opponent_non_pawn_attacks | opponent_pawn_attacks;

        Evaluator evaluator(board);
        float endgame_transition = evaluator.get_friendly_score().EndgameTransition;
        auto& pst = PSTManager::instance();

        // Capture handling
        if (is_capture) {
            // TODO: Switch to static exchange evaluation
            int16_t capture_delta =
                score_of_piece(piece_to_capture.type()) - score_of_piece(piece_to_move.type());
            bool opponent_can_recapture = all_opponent_attacks.check(target_square);

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
            score += m_HistoryHeuristic[static_cast<int>(board->sideToMove())][start_square]
                                       [target_square];
        }

        // Evaluations with PSTs
        if (piece_to_move.type() == PieceType::PAWN || piece_to_move.type() == PieceType::KING) {
            int score_from =
                pst.get_value_tapered_unchecked(piece_to_move, start_square, endgame_transition);
            int score_to =
                pst.get_value_tapered_unchecked(piece_to_move, target_square, endgame_transition);
            score += score_to - score_from;

            score += shield_bias(board, move) * king_safety_bonus(board, move);
        } else {
            // Phase does not matter here as Pawns & Kings are only non-unified pieces
            int score_from = pst.get_value_unchecked(piece_to_move, start_square);
            int score_to = pst.get_value_unchecked(piece_to_move, target_square);
            score += score_to - score_from;
        }

        if (piece_to_move.type() == PieceType::PAWN) {
            // Contend with non-capture promotions, only award bias for knights and queens
            if (!is_capture && move.typeOf() == Move::PROMOTION) {
                if (move.promotionType() == PieceType::QUEEN) {
                    score += PROMOTING_MOVE_BIAS;
                } else if (move.promotionType() == PieceType::KNIGHT) {
                    score += PROMOTING_MOVE_BIAS / 2;
                }
            }
        } else if (piece_to_move.type() == PieceType::KING && move.typeOf() == Move::CASTLING) {
            // Castling should be preferred, and kingside should be slightly better usually
            if (target_square % 8 == 6) {
                score += 25;
            } else if (target_square % 8 == 2) {
                score += 20;
            }
        } else {
            // Allowing a pawn to take our piece is worse than something of higher value
            if (opponent_pawn_attacks.check(target_square)) {
                score -= 50;
            } else if (opponent_non_pawn_attacks.check(target_square)) {
                score -= 25;
            }
        }

        moves[i].setScore(score);
    }

    std::sort(moves.begin(), moves.end(),
              [](const Move& a, const Move& b) { return a.score() > b.score(); });
}
