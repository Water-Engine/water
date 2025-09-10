#pragma once

const int INF = 1000000000;
const int NEG_INF = -INF;

// ================ EVALUATION UTILS ================
inline int16_t score_of_piece(PieceType type) {
    switch (type.internal()) {
    case PieceType::PAWN:
        return PieceScores::Pawn;
    case PieceType::KNIGHT:
        return PieceScores::Knight;
    case PieceType::BISHOP:
        return PieceScores::Bishop;
    case PieceType::ROOK:
        return PieceScores::Rook;
    case PieceType::QUEEN:
        return PieceScores::Queen;
    default:
        return 0;
    }
}

Bitboard pawn_attacks(Ref<Board> board, Color color);
Bitboard non_pawn_attacks(Ref<Board> board, Color color);

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
    static int individual_piece_score(const Piece& piece, Bitboard piece_bb,
                                      float endgame_transition);
    int combined_piece_score(const Bitboard& friendly_bb, Color friendly_color,
                             float endgame_transition);

  public:
    Evaluator(Ref<Board> board) : m_Board(board) {}

    MaterialScore get_score(Color color) const;
    MaterialScore get_friendly_score() const { return get_score(m_Board->sideToMove()); }
    MaterialScore get_opponent_score() const { return get_score(~m_Board->sideToMove()); }

    int evaluate();
};