#include <pch.hpp>

#include "evaluation/evaluation.hpp"
#include "evaluation/pst.hpp"

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

    while (piece_bb != 0) {
        int square = piece_bb.pop();
        aggregate += psts.get_value_tapered_unchecked(piece, square, endgame_transition);
    }

    return aggregate;
}

int Evaluator::combined_piece_score(const Bitboard& friendly_bb, Color friendly_color,
                                    float endgame_transition) {
    int pawn_pst_score =
        individual_piece_score(Piece(PieceType::PAWN, friendly_color),
                               m_Board->pieces(PieceType::PAWN) & friendly_bb, endgame_transition);
    int knight_pst_score = individual_piece_score(Piece(PieceType::KNIGHT, friendly_color),
                                                  m_Board->pieces(PieceType::KNIGHT) & friendly_bb,
                                                  endgame_transition);
    int bishop_pst_score = individual_piece_score(Piece(PieceType::BISHOP, friendly_color),
                                                  m_Board->pieces(PieceType::BISHOP) & friendly_bb,
                                                  endgame_transition);
    int rook_pst_score =
        individual_piece_score(Piece(PieceType::ROOK, friendly_color),
                               m_Board->pieces(PieceType::ROOK) & friendly_bb, endgame_transition);
    int queen_pst_score =
        individual_piece_score(Piece(PieceType::QUEEN, friendly_color),
                               m_Board->pieces(PieceType::QUEEN) & friendly_bb, endgame_transition);
    int king_pst_score =
        individual_piece_score(Piece(PieceType::KING, friendly_color),
                               m_Board->pieces(PieceType::KING) & friendly_bb, endgame_transition);
    return pawn_pst_score + knight_pst_score + bishop_pst_score + rook_pst_score + queen_pst_score +
           king_pst_score;
}

MaterialScore Evaluator::get_score(Color color) const {
    auto friendly_color_bb = m_Board->us(color);
    auto enemy_color_bb = m_Board->them(color);

    auto friendly_pawns = friendly_color_bb | m_Board->pieces(PieceType::PAWN);
    auto enemy_pawns = enemy_color_bb | m_Board->pieces(PieceType::PAWN);
    auto friendly_knights = friendly_color_bb | m_Board->pieces(PieceType::KNIGHT);
    auto friendly_bishops = friendly_color_bb | m_Board->pieces(PieceType::BISHOP);
    auto friendly_rooks = friendly_color_bb | m_Board->pieces(PieceType::ROOK);
    auto friendly_queens = friendly_color_bb | m_Board->pieces(PieceType::QUEEN);

    return MaterialScore(friendly_pawns.count(), friendly_knights.count(), friendly_bishops.count(),
                         friendly_rooks.count(), friendly_queens.count(), friendly_pawns.getBits(),
                         enemy_pawns.getBits());
}

int Evaluator::evaluate() {
    bool white_to_move = m_Board->sideToMove() == Color::WHITE;

    const auto& friendly_color = m_Board->sideToMove();
    auto friendly_color_bb = m_Board->us(friendly_color);
    const auto& enemy_color = ~friendly_color;

    const auto& friendly_material = get_score(friendly_color);
    const auto& enemy_material = get_score(enemy_color);
    auto material_difference = friendly_material.Aggregate - enemy_material.Aggregate;

    int pst_score = combined_piece_score(friendly_color_bb, friendly_color,
                                         friendly_material.EndgameTransition);

    int multiplier = white_to_move ? 1 : -1;
    int evaluation_score = material_difference + pst_score;
    return multiplier * evaluation_score;
}

Bitboard pawn_attacks(Ref<Board> board, Color color) {
    auto to_ray_cast = board->us(color) & board->pieces(PieceType::PAWN);
    Bitboard attacks(0);

    while (to_ray_cast) {
        int index = to_ray_cast.pop();
        attacks |= attacks::pawn(color, index);
    }
    return attacks;
}

Bitboard non_pawn_attacks(Ref<Board> board, Color color) {
    auto occupied = board->us(color) | board->us(~color);
    auto make_attacks = [&](PieceType type) -> Bitboard {
        auto to_ray_cast = board->us(color) & board->pieces(type);
        Bitboard attacks(0);

        if (type == PieceType::KING || type == PieceType::KNIGHT) {
            auto attack_maker = (type == PieceType::KING) ? attacks::king
                                : (type == PieceType::KNIGHT)
                                    ? attacks::knight
                                    : []([[maybe_unused]] Square sq) { return Bitboard(0); };
            while (to_ray_cast) {
                int index = to_ray_cast.pop();
                attacks |= attack_maker(index);
            }
            return attacks;
        }

        auto attack_maker = (type == PieceType::BISHOP) ? attacks::bishop
                            : (type == PieceType::ROOK) ? attacks::rook
                            : (type == PieceType::QUEEN)
                                ? attacks::queen
                                : []([[maybe_unused]] Square sq,
                                     [[maybe_unused]] Bitboard occupied) { return Bitboard(0); };
        while (to_ray_cast) {
            int index = to_ray_cast.pop();
            attacks |= attack_maker(index, occupied);
        }
        return attacks;
    };

    Bitboard attacks(0);
    attacks |= make_attacks(PieceType::KNIGHT);
    attacks |= make_attacks(PieceType::BISHOP);
    attacks |= make_attacks(PieceType::ROOK);
    attacks |= make_attacks(PieceType::QUEEN);
    attacks |= make_attacks(PieceType::KING);
    return attacks;
}
