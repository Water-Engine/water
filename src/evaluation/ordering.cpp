#include <pch.hpp>

#include "fathom/tbprobe.h"

#include "evaluation/eval_bits.hpp"
#include "evaluation/evaluation.hpp"
#include "evaluation/ordering.hpp"
#include "evaluation/pst.hpp"

using namespace chess;

int MoveOrderer::king_safety_bonus(Ref<Board> board, const Move& move) {
    Color c = board->sideToMove();
    int king_sq_after = move.to().index();
    Bitboard shield = PawnMasks::instance().get_shield(c, king_sq_after);

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
    Bitboard shield = PawnMasks::instance().get_shield(c, king_sq);

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
                              bool in_quiescence, size_t ply, const SyzygyManager& tb_manager,
                              OrderFlag flags) {
    PROFILE_FUNCTION();

    std::unordered_map<Move, int> tb_move_map;
    if (tb_manager.is_loaded()) {
        auto maybe_root_moves = tb_manager.probe_dtz();
        if (maybe_root_moves.is_some()) {
            TbRootMoves root_moves = maybe_root_moves.unwrap();
            tb_move_map.reserve(root_moves.size);
            for (size_t i = 0; i < root_moves.size; ++i) {
                tb_move_map.insert({Move(root_moves.moves[i].move), root_moves.moves[i].tbScore});
            }
        }
    }

    for (auto i = 0; i < moves.size(); ++i) {
        auto move = moves[i];
        if (!tb_move_map.empty() && tb_move_map.contains(move)) {
            int tb_score = tb_move_map[move];
            int wdl = TB_GET_WDL(tb_score);
            int bias = 0;
            switch (wdl) {
            case TB_WIN:
                bias = +1;
                break;
            case TB_DRAW:
                bias = 0;
                break;
            case TB_LOSS:
                bias = -1;
                break;
            }
            moves[i].setScore(bias * TB_MOVE_BIAS);
            continue;
        }

        int16_t score = UNBIASED;
        int start_square = move.from().index();
        int target_square = move.to().index();

        Piece piece_to_move = board->at(start_square);
        Piece piece_to_capture = probe_capture(move, board).unwrap_or(Piece::NONE);
        bool is_capture = piece_to_capture.type() != PieceType::NONE;

        Evaluator evaluator(board);
        float endgame_transition = evaluator.get_friendly_material().EndgameTransition;
        auto& pst = PSTManager::instance();

        // HASH MOVE - gets top priority if enabled and true
        if (has_flag(flags, OrderFlag::HashMove) && move == hash_move) {
            moves[i].setScore(HASH_MOVE_BIAS);
            continue;
        }

        // CAPTURE / MVV-LVA
        if (is_capture) {
            if (has_flag(flags, OrderFlag::MVVLVA)) {
                auto [victim_value, attacker_value] = evaluator.mvv_lva(move);
                int mvv_lva_score = victim_value * 10 - attacker_value;
                int see_score = evaluator.see(move);
                score = MVV_LVA_BIAS + mvv_lva_score + see_score;
            } else {
                score = UNBIASED;
            }
        } else {
            // KILLER MOVE
            if (has_flag(flags, OrderFlag::KillerMove)) {
                bool is_killer =
                    !in_quiescence && ply < MAX_KILLER_MOVE_PLY && m_KillersHeuristic[ply] == move;
                score += is_killer ? KILLER_MOVE_BIAS : UNBIASED;
            }

            // HISTORY HEURISTIC always applied for quiet moves
            score += m_HistoryHeuristic[static_cast<int>(board->sideToMove())][start_square]
                                       [target_square];
        }

        // PST / positional bonuses
        if (has_flag(flags, OrderFlag::PST)) {
            if (piece_to_move.type() == PieceType::PAWN ||
                piece_to_move.type() == PieceType::KING) {
                int score_from = pst.get_value_tapered_unchecked(piece_to_move, start_square,
                                                                 endgame_transition);
                int score_to = pst.get_value_tapered_unchecked(piece_to_move, target_square,
                                                               endgame_transition);
                score += score_to - score_from;

                score += shield_bias(board, move) + king_safety_bonus(board, move);
            } else {
                int score_from = pst.get_value_unchecked(piece_to_move, start_square);
                int score_to = pst.get_value_unchecked(piece_to_move, target_square);
                score += score_to - score_from;
            }
        }

        // Promotion bonuses
        if (has_flag(flags, OrderFlag::Promotion) && piece_to_move.type() == PieceType::PAWN &&
            !is_capture && move.typeOf() == Move::PROMOTION) {
            if (move.promotionType() == PieceType::QUEEN) {
                score += PROMOTING_MOVE_BIAS;
            } else if (move.promotionType() == PieceType::KNIGHT) {
                score += PROMOTING_MOVE_BIAS / 2;
            }
        }

        // Castling / attack penalties always applied
        if (piece_to_move.type() == PieceType::KING && move.typeOf() == Move::CASTLING) {
            if (target_square % 8 == 6)
                score += 25;
            else if (target_square % 8 == 2)
                score += 20;
        } else {
            Bitboard opponent_non_pawn_attacks = non_pawn_attacks(board, ~board->sideToMove());
            Bitboard opponent_pawn_attacks = pawn_attacks(board, ~board->sideToMove());
            if (opponent_pawn_attacks.check(target_square))
                score -= 50;
            else if (opponent_non_pawn_attacks.check(target_square))
                score -= 25;
        }

        moves[i].setScore(score);
    }

    // Final sort
    std::sort(moves.begin(), moves.end(),
              [](const Move& a, const Move& b) { return a.score() > b.score(); });
}
