#include <pch.hpp>

#include "evaluation/eval_bits.hpp"
#include "evaluation/evaluation.hpp"
#include "evaluation/pst.hpp"

using namespace chess;

int Evaluator::individual_pst_score(const Piece& piece, Bitboard piece_bb,
                                    float endgame_transition) {
    auto& psts = PSTManager::instance();
    int aggregate = 0;

    while (piece_bb != 0) {
        int square = piece_bb.pop();
        aggregate += psts.get_value_tapered_unchecked(piece, square, endgame_transition);
    }

    return aggregate;
}

int Evaluator::combined_pst_score(const Bitboard& friendly_bb, Color friendly_color,
                                  float endgame_transition) {
    int pawn_pst_score =
        individual_pst_score(Piece(PieceType::PAWN, friendly_color),
                             m_Board->pieces(PieceType::PAWN) & friendly_bb, endgame_transition);
    int knight_pst_score =
        individual_pst_score(Piece(PieceType::KNIGHT, friendly_color),
                             m_Board->pieces(PieceType::KNIGHT) & friendly_bb, endgame_transition);
    int bishop_pst_score =
        individual_pst_score(Piece(PieceType::BISHOP, friendly_color),
                             m_Board->pieces(PieceType::BISHOP) & friendly_bb, endgame_transition);
    int rook_pst_score =
        individual_pst_score(Piece(PieceType::ROOK, friendly_color),
                             m_Board->pieces(PieceType::ROOK) & friendly_bb, endgame_transition);
    int queen_pst_score =
        individual_pst_score(Piece(PieceType::QUEEN, friendly_color),
                             m_Board->pieces(PieceType::QUEEN) & friendly_bb, endgame_transition);
    int king_pst_score =
        individual_pst_score(Piece(PieceType::KING, friendly_color),
                             m_Board->pieces(PieceType::KING) & friendly_bb, endgame_transition);
    return pawn_pst_score + knight_pst_score + bishop_pst_score + rook_pst_score + queen_pst_score +
           king_pst_score;
}

int Evaluator::pawn_score(Color color) {
    auto pawns = m_Board->pieces(PieceType::PAWN);
    bool is_white = color == Color::WHITE;

    Bitboard friendly_pawns = m_Board->us(color) & pawns;
    Bitboard opponent_pawns = m_Board->them(color) & pawns;

    int bonus = 0, num_isolated = 0;

    auto& pawn_bits = PawnMasks::instance();
    auto& file_bits = FileMasks::instance();

    while (pawns != 0) {
        int index = pawns.pop();
        auto passed_mask = pawn_bits.get_passed_unchecked(color, index);

        if ((opponent_pawns & passed_mask) == 0) {
            int rank = Coord::rank_from_square(index);
            int num_from_promotion = is_white ? 7 - rank : rank;
            bonus += PP_BONUS[num_from_promotion];
        }

        int file = Coord::file_from_square(index);
        if ((friendly_pawns & file_bits.get_adj_file_unchecked(file)) == 0) {
            num_isolated += 1;
        }
    }

    return bonus + ISO_PAWN[num_isolated];
}

int Evaluator::king_score(Color color, Material opponent_material, int opponent_pst_score) {
    if (opponent_material.EndgameTransition >= 1) {
        return 0;
    }

    // The not castled penalty takes effect iff the king is not in a castling file
    int penalty = 0, not_castled_penalty = 0, exposed_king_penalty = 0;

    auto friendly_king_sq = m_Board->kingSq(color);
    int friendly_king_file = friendly_king_sq.file();

    auto& pawn_bits = PawnMasks::instance();
    auto& file_bits = FileMasks::instance();

    // Apply different castling penalties
    if (friendly_king_file <= 2 || friendly_king_file >= 5) {
        auto pawn_shield = pawn_bits.get_shield_unchecked(color, friendly_king_sq.index());
        auto friendly_pawns = m_Board->us(color) & m_Board->pieces(PieceType::PAWN);
        auto missing = pawn_shield & ~friendly_pawns;

        while (missing != 0) {
            auto square = missing.pop();

            if (square < KING_SHIELD.size()) {
                penalty += KING_SHIELD[square];
            }
        }

        penalty *= penalty;
    } else {
        const float normalizer = 130.0f;
        float opponent_development =
            std::clamp(static_cast<float>(opponent_pst_score + 10) / normalizer, 0.0f, 1.0f);
        not_castled_penalty = 50 * opponent_development;
    }

    // Apply king safety penalties
    if (opponent_material.NumRooks > 1 ||
        (opponent_material.NumRooks > 0 && opponent_material.NumQueens > 0)) {
        int clamped_king = std::clamp(friendly_king_file, 1, 6);
        Bitboard friendly_pawns(opponent_material.EnemyPawns);
        Bitboard opponent_pawns(opponent_material.FriendlyPawns);

        for (int attack_file = clamped_king; attack_file < clamped_king + 2; ++attack_file) {
            auto file_mask = file_bits.get_file(attack_file);
            bool is_king_file = attack_file == friendly_king_file;

            if ((opponent_pawns & file_mask) == 0) {
                exposed_king_penalty += is_king_file ? 25 : 15;
                if ((friendly_pawns & file_mask) == 0) {
                    exposed_king_penalty += is_king_file ? 15 : 10;
                }
            }
        }
    }

    // Weighting for pawn shield, reduced if queens are not present
    float shield_weight = 1 - opponent_material.EndgameTransition;
    if (opponent_material.NumQueens == 0) {
        shield_weight *= 0.6f;
    }

    float aggregate_penalty =
        -shield_weight * (penalty + not_castled_penalty + exposed_king_penalty);
    return static_cast<int>(aggregate_penalty);
}

int Evaluator::mop_score(Color color, Material friendly_material, Material opponent_material) {
    if (friendly_material.Aggregate >
            opponent_material.Aggregate + score_of_piece(PieceType::PAWN) * 2 &&
        opponent_material.EndgameTransition > 0) {
        int mop_up = 0;
        int friendly_king = m_Board->kingSq(color).index();
        int opponent_king = m_Board->kingSq(~color).index();

        auto& distance = Distance::instance();
        mop_up += 4 * (14 - distance.get_manhattan_unchecked(friendly_king, opponent_king));
        mop_up += 10 * distance.get_center_manhattan_unchecked(opponent_king);

        return static_cast<int>(mop_up * opponent_material.EndgameTransition);
    }

    return 0;
}

int Evaluator::simple_eval() {
    auto side_to_move = m_Board->sideToMove();
    bool white_to_move = side_to_move == Color::WHITE;
    int perspective = white_to_move ? 1 : -1;

    SimpleEvalData friendly_eval;
    SimpleEvalData opponent_eval;

    auto friendly_material = get_friendly_material();
    auto opponent_material = get_opponent_material();

    friendly_eval.MaterialScore = friendly_material.Aggregate;
    opponent_eval.MaterialScore = opponent_material.Aggregate;

    friendly_eval.PSTScore = combined_pst_score(m_Board->us(side_to_move), side_to_move,
                                                friendly_material.EndgameTransition);
    opponent_eval.PSTScore = combined_pst_score(m_Board->them(side_to_move), ~side_to_move,
                                                opponent_material.EndgameTransition);

    // TODO: See if this is something we want to implement
    friendly_eval.MopUpScore = mop_score(side_to_move, friendly_material, opponent_material);
    opponent_eval.MopUpScore = mop_score(~side_to_move, opponent_material, friendly_material);

    friendly_eval.PawnScore = pawn_score(side_to_move);
    opponent_eval.PawnScore = pawn_score(~side_to_move);

    friendly_eval.PawnShieldScore =
        king_score(side_to_move, opponent_material, opponent_eval.PSTScore);
    opponent_eval.PawnShieldScore =
        king_score(~side_to_move, friendly_material, friendly_eval.PSTScore);

    return perspective * (friendly_eval.sum() - opponent_eval.sum());
}

int Evaluator::nnue_eval() { return 0; }

Material Evaluator::get_material(Color color) const {
    auto friendly_color_bb = m_Board->us(color);
    auto enemy_color_bb = m_Board->them(color);

    auto friendly_pawns = friendly_color_bb & m_Board->pieces(PieceType::PAWN);
    auto enemy_pawns = enemy_color_bb & m_Board->pieces(PieceType::PAWN);
    auto friendly_knights = friendly_color_bb & m_Board->pieces(PieceType::KNIGHT);
    auto friendly_bishops = friendly_color_bb & m_Board->pieces(PieceType::BISHOP);
    auto friendly_rooks = friendly_color_bb & m_Board->pieces(PieceType::ROOK);
    auto friendly_queens = friendly_color_bb & m_Board->pieces(PieceType::QUEEN);

    return Material(friendly_pawns.count(), friendly_knights.count(), friendly_bishops.count(),
                    friendly_rooks.count(), friendly_queens.count(), friendly_pawns.getBits(),
                    enemy_pawns.getBits());
}

int Evaluator::evaluate() {
    if (m_UseNNUE) {
        return nnue_eval();
    } else {
        return simple_eval();
    }
}

int Evaluator::see(const Move& move) {
    Square target = move.to().index();
    Color side = m_Board->sideToMove();
    auto our_attacks = attacks::attackers(*m_Board, side, target);

    Piece victim = m_Board->at(target);
    int gain[32];
    int depth = 0;

    gain[depth] = score_of_piece(victim.type());

    while (true) {
        auto lva = least_valuable_attacker(our_attacks);
        Piece attacker_piece = lva.first;
        int attacker_index = lva.second.index();

        if (attacker_piece.type() == PieceType::NONE) {
            break;
        }

        // Update gain for this step
        gain[depth + 1] = score_of_piece(attacker_piece.type()) - gain[depth];
        depth++;

        // Remove attacker from attack set
        our_attacks &= ~(1ULL << attacker_index);

        // Switch sides
        side = ~side;
    }

    // Negamax backward evaluation
    for (int i = depth - 1; i >= 0; --i) {
        gain[i] = std::min(-gain[i + 1], gain[i]);
    }

    return gain[0];
}

std::pair<Evaluator::VictimValue, Evaluator::AttackerValue> Evaluator::mvv_lva(const Move& move) {
    Piece attacker = m_Board->at(move.from().index());
    Piece victim = m_Board->at(move.to().index());

    int attacker_value = score_of_piece(attacker.type());
    int victim_value = score_of_piece(victim.type());

    return {victim_value, attacker_value};
}

std::pair<Piece, Square> Evaluator::least_valuable_attacker(Bitboard attackers) {
    Square best_sq = -1;
    if (attackers == 0) {
        return {Piece::NONE, best_sq};
    }

    int best_value = INT_MAX;
    while (attackers != 0) {
        int square_index = attackers.pop();
        Piece piece = m_Board->at(square_index);

        int val = score_of_piece(piece.type());
        if (val < best_value) {
            best_value = val;
            best_sq = square_index;
        }
    }

    if (best_sq == -1) {
        return {Piece::NONE, best_sq};
    } else {
        return {m_Board->at(best_sq), best_sq};
    }
}
