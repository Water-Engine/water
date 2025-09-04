#include <pch.hpp>

#include "evaluation/evaluation.hpp"
#include "evaluation/pst.hpp"

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

int Evaluator::individual_piece_score(const Piece& piece, Bitboard piece_bb,
                                      float endgame_transition) {
    auto& psts = PSTManager::instance();
    int aggregate = 0;

    while (piece_bb.value() != 0) {
        int square = piece_bb.pop_lsb();
        aggregate += psts.get_value_tapered_unchecked(piece, square, endgame_transition);
    }

    return aggregate;
}

int Evaluator::combined_piece_score(const Bitboard& friendly_bb, PieceColor friendly_color,
                                    float endgame_transition) {
    int pawn_pst_score =
        individual_piece_score(Piece(PieceType::Pawn, friendly_color),
                               m_Board->m_PawnBB & friendly_bb, endgame_transition);
    int knight_pst_score =
        individual_piece_score(Piece(PieceType::Knight, friendly_color),
                               m_Board->m_KnightBB & friendly_bb, endgame_transition);
    int bishop_pst_score =
        individual_piece_score(Piece(PieceType::Bishop, friendly_color),
                               m_Board->m_BishopBB & friendly_bb, endgame_transition);
    int rook_pst_score =
        individual_piece_score(Piece(PieceType::Rook, friendly_color),
                               m_Board->m_RookBB & friendly_bb, endgame_transition);
    int queen_pst_score =
        individual_piece_score(Piece(PieceType::Queen, friendly_color),
                               m_Board->m_QueenBB & friendly_bb, endgame_transition);
    int king_pst_score =
        individual_piece_score(Piece(PieceType::King, friendly_color),
                               m_Board->m_KingBB & friendly_bb, endgame_transition);
    return pawn_pst_score + knight_pst_score + bishop_pst_score + rook_pst_score + queen_pst_score +
           king_pst_score;
}

MaterialScore Evaluator::get_score(PieceColor color) const {
    if (color == PieceColor::White) {
        return get_score<PieceColor::White>();
    } else {
        return get_score<PieceColor::Black>();
    }
}

int Evaluator::evaluate() {
    bool white_to_move = m_Board->m_WhiteToMove;

    const auto& friendly_color_bb = white_to_move ? m_Board->m_WhiteBB : m_Board->m_BlackBB;
    const auto& friendly_color = m_Board->friendly_color();
    const auto& enemy_color = m_Board->friendly_color();

    const auto& friendly_material = get_score(friendly_color);
    const auto& enemy_material = get_score(enemy_color);
    auto material_difference = friendly_material.Aggregate - enemy_material.Aggregate;

    int pst_score = combined_piece_score(friendly_color_bb, friendly_color,
                                         friendly_material.EndgameTransition);

    int multiplier = white_to_move ? 1 : -1;
    int evaluation_score = material_difference + pst_score;
    return multiplier * evaluation_score;
}