#pragma once

#include "game/coord.hpp"
#include "game/piece.hpp"

// ================ TABLE GROUP ================

constexpr std::array<int, 64> flip_table(const std::array<int, 64>& table) {
    std::array<int, 64> flipped{};

    for (size_t i = 0; i < flipped.size(); ++i) {
        Coord coord(i);
        Coord flipped_coord(coord.file_idx(), 7 - coord.rank_idx());
        flipped[flipped_coord.square_idx_unchecked()] = table[i];
    }

    return flipped;
}

enum class Phase { Unified, Early, Late };
constexpr int PHASE_SENTINEL = 3; // WATCH ME - MUST BE NUM PHASE ENUM VALS

struct Table {
    std::array<int, 64> EarlyGame;
    std::array<int, 64> LateGame;

    Table() = default;
    constexpr Table(const std::array<int, 64>& unified) : EarlyGame(unified), LateGame(unified) {}
    constexpr Table(const std::array<int, 64>& early, const std::array<int, 64>& late)
        : EarlyGame(early), LateGame(late) {}

    constexpr Table flip() const { return Table{flip_table(EarlyGame), flip_table(LateGame)}; }

    inline const std::array<int, 64>& phase(Phase p) const {
        if (p == Phase::Early) {
            return EarlyGame;
        } else {
            return LateGame;
        }
    }
};

// ================ PAWN PST ================

constexpr std::array<int, 64> PawnEarly = {
    0,  0,   0,  0, 0,  0,  0,  0,   50,  50, 50, 50, 50, 50, 50, 50, 10, 10, 20, 30, 30,  20,
    10, 10,  5,  5, 10, 25, 25, 10,  5,   5,  0,  0,  0,  20, 20, 0,  0,  0,  5,  -5, -10, 0,
    0,  -10, -5, 5, 5,  10, 10, -20, -20, 10, 10, 5,  0,  0,  0,  0,  0,  0,  0,  0};

constexpr std::array<int, 64> PawnLate = {
    0,  0,  0,  0,  0,  0,  0,  0,  80, 80, 80, 80, 80, 80, 80, 80, 50, 50, 50, 50, 50, 50,
    50, 50, 30, 30, 30, 30, 30, 30, 30, 30, 20, 20, 20, 20, 20, 20, 20, 20, 10, 10, 10, 10,
    10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 0,  0,  0,  0,  0,  0,  0,  0};

constexpr Table WhitePawnTable{PawnEarly, PawnLate};
constexpr Table BlackPawnTable = WhitePawnTable.flip();

// ================ ROOK PST ================

constexpr std::array<int, 64> RookUnified = {
    0, 0,  0,  0,  0,  0, 0, 0, 5, 10, 10, 10, 10, 10, 10, 5, -5, 0,  0,  0, 0, 0,
    0, -5, -5, 0,  0,  0, 0, 0, 0, -5, -5, 0,  0,  0,  0,  0, 0,  -5, -5, 0, 0, 0,
    0, 0,  0,  -5, -5, 0, 0, 0, 0, 0,  0,  -5, 0,  0,  0,  5, 5,  0,  0,  0};

constexpr Table WhiteRookTable{RookUnified, RookUnified};
constexpr Table BlackRookTable = WhiteRookTable.flip();

// ================ KNIGHT PST ================

constexpr std::array<int, 64> KnightUnified = {
    -50, -40, -30, -30, -30, -30, -40, -50, -40, -20, 0,   0,   0,   0,   -20, -40,
    -30, 0,   10,  15,  15,  10,  0,   -30, -30, 5,   15,  20,  20,  15,  5,   -30,
    -30, 0,   15,  20,  20,  15,  0,   -30, -30, 5,   10,  15,  15,  10,  5,   -30,
    -40, -20, 0,   5,   5,   0,   -20, -40, -50, -40, -30, -30, -30, -30, -40, -50,
};

constexpr Table WhiteKnightTable{KnightUnified, KnightUnified};
constexpr Table BlackKnightTable = WhiteKnightTable.flip();

// ================ BISHOP PST ================

constexpr std::array<int, 64> BishopUnified = {
    -20, -10, -10, -10, -10, -10, -10, -20, -10, 0,   0,   0,   0,   0,   0,   -10,
    -10, 0,   5,   10,  10,  5,   0,   -10, -10, 5,   5,   10,  10,  5,   5,   -10,
    -10, 0,   10,  10,  10,  10,  0,   -10, -10, 10,  10,  10,  10,  10,  10,  -10,
    -10, 5,   0,   0,   0,   0,   5,   -10, -20, -10, -10, -10, -10, -10, -10, -20,
};

constexpr Table WhiteBishopTable{BishopUnified, BishopUnified};
constexpr Table BlackBishopTable = WhiteBishopTable.flip();

// ================ QUEEN PST ================

constexpr std::array<int, 64> QueenUnified = {
    -20, -10, -10, -5, -5, -10, -10, -20, -10, 0,   0,   0,  0,  0,   0,   -10,
    -10, 0,   5,   5,  5,  5,   0,   -10, -5,  0,   5,   5,  5,  5,   0,   -5,
    0,   0,   5,   5,  5,  5,   0,   -5,  -10, 5,   5,   5,  5,  5,   0,   -10,
    -10, 0,   5,   0,  0,  0,   0,   -10, -20, -10, -10, -5, -5, -10, -10, -20};

constexpr Table WhiteQueenTable{QueenUnified, QueenUnified};
constexpr Table BlackQueenTable = WhiteQueenTable.flip();

// ================ KING PSTs ================

constexpr std::array<int, 64> KingEarly = {
    -80, -70, -70, -70, -70, -70, -70, -80, -60, -60, -60, -60, -60, -60, -60, -60,
    -40, -50, -50, -60, -60, -50, -50, -40, -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20, -10, -20, -20, -20, -20, -20, -20, -10,
    20,  20,  -5,  -5,  -5,  -5,  20,  20,  20,  30,  10,  0,   0,   10,  30,  20};

constexpr std::array<int, 64> KingLate = {
    -20, -10, -10, -10, -10, -10, -10, -20, -5,  0,   5,   5,   5,   5,   0,   -5,
    -10, -5,  20,  30,  30,  20,  -5,  -10, -15, -10, 35,  45,  45,  35,  -10, -15,
    -20, -15, 30,  40,  40,  30,  -15, -20, -25, -20, 20,  25,  25,  20,  -20, -25,
    -30, -25, 0,   0,   0,   0,   -25, -30, -50, -30, -30, -30, -30, -30, -30, -50};

constexpr Table WhiteKingTable{KingEarly, KingLate};
constexpr Table BlackKingTable = WhiteKingTable.flip();

// ================ PST MANAGER GENERATED ONCE AT RUNTIME ================

/// Piece-square-table manager - returns 0 for invalid checked square indices
class PST {
  private:
    std::array<Table, 12> m_Tables;

  private:
    PST();

  public:
    PST(const PST&) = delete;
    PST& operator=(const PST&) = delete;
    PST(PST&&) = delete;
    PST& operator=(PST&&) = delete;

    static PST& instance() {
        static PST s_instance;
        return s_instance;
    }

    int static get_value_unchecked(const Table& table, PieceColor piece_color, int square,
                                   Phase phase = Phase::Unified);
    int static get_value(const Table& table, PieceColor piece_color, int square,
                         Phase phase = Phase::Unified);

    inline int get_value_unchecked(const Piece& piece, int square,
                                   Phase phase = Phase::Unified) const {
// The compiler really hates the use of piece.index() for any indexing
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Warray-bounds"
        return m_Tables[piece.index()].phase(phase)[square];
#pragma GCC diagnostic pop
    }

    inline int get_value(const Piece& piece, int square, Phase phase = Phase::Unified) const {
        if (!Coord::valid_square_idx(square)) {
            return 0;
        }

        return get_value_unchecked(piece, square, phase);
    };

    int get_value_tapered_unchecked(const Piece& piece, int square, float endgame_transition) const;

    inline int get_value_tapered(const Piece& piece, int square, float endgame_transition) const {
        if (!Coord::valid_square_idx(square)) {
            return 0;
        }

        return get_value_tapered_unchecked(piece, square, endgame_transition);
    }
};