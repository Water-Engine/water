#include <pch.hpp>

struct Material {
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

    Material(int num_pawns, int num_knights, int num_bishops, int num_rooks, int num_queens,
             uint64_t friendly_pawns, uint64_t enemy_pawns)
        : NumPawns(num_pawns), NumKnights(num_knights), NumBishops(num_bishops),
          NumRooks(num_rooks), NumQueens(num_queens), NumMajors(num_rooks + num_queens),
          NumMinors(num_bishops + num_knights), FriendlyPawns(friendly_pawns),
          EnemyPawns(enemy_pawns) {
        Aggregate = 0;
        Aggregate += NumPawns * PieceScores::Pawn;
        Aggregate += NumKnights * PieceScores::Knight;
        Aggregate += NumBishops * PieceScores::Bishop;
        Aggregate += NumRooks * PieceScores::Rook;
        Aggregate += NumQueens * PieceScores::Queen;

        float endgame_weight_sum =
            NumKnights * KNIGHT_ENDGAME_WEIGHT + NumBishops * BISHOP_ENDGAME_WEIGHT +
            NumRooks * ROOK_ENDGAME_WEIGHT + NumQueens * QUEEN_ENDGAME_WEIGHT;
        EndgameTransition = 1.0f - std::min(1.0f, endgame_weight_sum / (float)ENDGAME_START_WEIGHT);
    }

    inline int non_pawn_score() const { return Aggregate - pawn_score(); }
    inline int pawn_score() const { return PieceScores::Pawn * NumPawns; }
};