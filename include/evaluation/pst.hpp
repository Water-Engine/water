#pragma once

#include "game/utils.hpp"

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

struct PST {
    std::array<int, 64> EarlyGame;
    std::array<int, 64> LateGame;

    PST() = default;
    constexpr PST(const std::array<int, 64>& unified) : EarlyGame(unified), LateGame(unified) {}
    constexpr PST(const std::array<int, 64>& early, const std::array<int, 64>& late)
        : EarlyGame(early), LateGame(late) {}

    constexpr PST flip() const { return PST{flip_table(EarlyGame), flip_table(LateGame)}; }

    inline const std::array<int, 64>& phase(Phase p) const {
        if (p == Phase::Early) {
            return EarlyGame;
        } else {
            return LateGame;
        }
    }

    inline std::string to_string(Phase p) const {
        const std::array<int, 64>& table = (p == Phase::Early) ? EarlyGame : LateGame;
        int max_width = 0;
        for (int square : table) {
            max_width = std::max(max_width, static_cast<int>(std::to_string(square).size()));
        }

        std::ostringstream oss;
        for (int rank = 0; rank < 8; ++rank) {
            for (int file = 0; file < 8; ++file) {
                oss << std::setw(max_width + 1) << table[rank * 8 + file];
            }

            if (rank < 7) {
                oss << '\n';
            }
        }

        return oss.str();
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

constexpr PST WhitePawnTable{PawnEarly, PawnLate};
constexpr PST BlackPawnTable = WhitePawnTable.flip();

// ================ ROOK PST ================

constexpr std::array<int, 64> RookUnified = {
    0, 0,  0,  0,  0,  0, 0, 0, 5, 10, 10, 10, 10, 10, 10, 5, -5, 0,  0,  0, 0, 0,
    0, -5, -5, 0,  0,  0, 0, 0, 0, -5, -5, 0,  0,  0,  0,  0, 0,  -5, -5, 0, 0, 0,
    0, 0,  0,  -5, -5, 0, 0, 0, 0, 0,  0,  -5, 0,  0,  0,  5, 5,  0,  0,  0};

constexpr PST WhiteRookTable{RookUnified, RookUnified};
constexpr PST BlackRookTable = WhiteRookTable.flip();

// ================ KNIGHT PST ================

constexpr std::array<int, 64> KnightUnified = {
    -50, -40, -30, -30, -30, -30, -40, -50, -40, -20, 0,   0,   0,   0,   -20, -40,
    -30, 0,   10,  15,  15,  10,  0,   -30, -30, 5,   15,  20,  20,  15,  5,   -30,
    -30, 0,   15,  20,  20,  15,  0,   -30, -30, 5,   10,  15,  15,  10,  5,   -30,
    -40, -20, 0,   5,   5,   0,   -20, -40, -50, -40, -30, -30, -30, -30, -40, -50,
};

constexpr PST WhiteKnightTable{KnightUnified, KnightUnified};
constexpr PST BlackKnightTable = WhiteKnightTable.flip();

// ================ BISHOP PST ================

constexpr std::array<int, 64> BishopUnified = {
    -20, -10, -10, -10, -10, -10, -10, -20, -10, 0,   0,   0,   0,   0,   0,   -10,
    -10, 0,   5,   10,  10,  5,   0,   -10, -10, 5,   5,   10,  10,  5,   5,   -10,
    -10, 0,   10,  10,  10,  10,  0,   -10, -10, 10,  10,  10,  10,  10,  10,  -10,
    -10, 5,   0,   0,   0,   0,   5,   -10, -20, -10, -10, -10, -10, -10, -10, -20,
};

constexpr PST WhiteBishopTable{BishopUnified, BishopUnified};
constexpr PST BlackBishopTable = WhiteBishopTable.flip();

// ================ QUEEN PST ================

constexpr std::array<int, 64> QueenUnified = {
    -20, -10, -10, -5, -5, -10, -10, -20, -10, 0,   0,   0,  0,  0,   0,   -10,
    -10, 0,   5,   5,  5,  5,   0,   -10, -5,  0,   5,   5,  5,  5,   0,   -5,
    0,   0,   5,   5,  5,  5,   0,   -5,  -10, 5,   5,   5,  5,  5,   0,   -10,
    -10, 0,   5,   0,  0,  0,   0,   -10, -20, -10, -10, -5, -5, -10, -10, -20};

constexpr PST WhiteQueenTable{QueenUnified, QueenUnified};
constexpr PST BlackQueenTable = WhiteQueenTable.flip();

// ================ KING PSTs ================

constexpr std::array<int, 64> KingEarly = {
    -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20, -10, -20, -20, -30, -30, -20, -20, -10,
    20,  20,  -10, -20, -20, -10, 20,  20,  20,  30,  10,  0,   0,   10,  30,  20};

constexpr std::array<int, 64> KingLate = {
    -20, -10, -10, -10, -10, -10, -10, -20, -5,  0,   5,   5,   5,   5,   0,   -5,
    -10, -5,  20,  30,  30,  20,  -5,  -10, -15, -10, 35,  45,  45,  35,  -10, -15,
    -20, -15, 30,  40,  40,  30,  -15, -20, -25, -20, 20,  25,  25,  20,  -20, -25,
    -30, -25, 0,   0,   0,   0,   -25, -30, -50, -30, -30, -30, -30, -30, -30, -50};

constexpr PST WhiteKingTable{KingEarly, KingLate};
constexpr PST BlackKingTable = WhiteKingTable.flip();

// ================ PST MANAGER GENERATED ONCE AT RUNTIME ================

/// Piece-square-table manager - returns 0 for invalid checked square indices
class PSTManager {
  private:
    std::array<PST, 12> m_Tables;

  private:
    PSTManager();

  public:
    PSTManager(const PSTManager&) = delete;
    PSTManager& operator=(const PSTManager&) = delete;
    PSTManager(PSTManager&&) = delete;
    PSTManager& operator=(PSTManager&&) = delete;

    static PSTManager& instance() {
        static PSTManager s_instance;
        return s_instance;
    }

    int static get_value_unchecked(const PST& table, Color piece_color, int square,
                                   Phase phase = Phase::Unified);
    int static get_value(const PST& table, Color piece_color, int square,
                         Phase phase = Phase::Unified);

    inline int get_value_unchecked(const Piece& piece, int square,
                                   Phase phase = Phase::Unified) const {
        return m_Tables[piece].phase(phase)[square];
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

    inline static std::string to_string(const PST& table, Phase phase = Phase::Unified) {
        return table.to_string(phase);
    }

    inline std::string to_string(const Piece& piece, Phase phase = Phase::Unified) const {
        return m_Tables[piece].to_string(phase);
    }
};