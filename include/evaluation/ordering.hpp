#pragma once

#include "bitboard/bitboard.hpp"

#include "game/board.hpp"
#include "game/move.hpp"

#include "generator/generator.hpp"

// Technically arbitrary values for biased ordering
constexpr int UNBIASED = 0;
constexpr int LOSING_CAPTURE_BIAS = 2'000'000;
constexpr int KILLER_MOVE_BIAS = 4'000'000;
constexpr int PROMOTING_MOVE_BIAS = 6'000'000;
constexpr int WINNING_CAPTURE_BIAS = 8'000'000;
constexpr int HASH_MOVE_BIAS = 100'000'000;

constexpr std::array<std::pair<int, std::string_view>, 6> BIASES = {
    {{UNBIASED, "Unbiased"},
     {LOSING_CAPTURE_BIAS, "Losing Capture"},
     {KILLER_MOVE_BIAS, "Killer Move"},
     {PROMOTING_MOVE_BIAS, "Promotion"},
     {WINNING_CAPTURE_BIAS, "Winning Capture"},
     {HASH_MOVE_BIAS, "Hash Move"}}};

struct KillerMove {
    Move a;
    Move b;

    inline void add(const Move& move) {
        if (move != a) {
            b = a;
            a = move;
        }
    }

    friend bool operator==(const KillerMove& killer, const Move& move) {
        return move == killer.a || move == killer.b;
    }
};

class MoveOrderer {
  private:
    static constexpr size_t MAX_MOVE_COUNT = 218;
    static constexpr size_t MAX_KILLER_MOVE_PLY = 32;

    // Quiet moves which triggers a beta cutoff
    std::array<KillerMove, MAX_KILLER_MOVE_PLY> m_KillersHeuristic;

    /// Indexed as [color][from][to]
    std::array<std::array<std::array<int, 64>, 64>, 2> m_HistoryHeuristic;

  public:
    MoveOrderer() = default;

    inline void clear_history() { std::memset(&m_HistoryHeuristic, 0, sizeof(m_HistoryHeuristic)); }
    inline void clear_killers() { m_KillersHeuristic.fill(KillerMove{}); }

    inline void clear() {
        clear_history();
        clear_killers();
    }

    /// Order moves heuristically. Assumes a fully validated MoveList, meaning all moves are legal
    void order_moves(Ref<Board> board, const Move& hash_move, MoveList& moves, bool in_quiescence,
                     size_t ply);

    inline std::string label_of_index(const MoveList& moves, size_t idx) const;
};
