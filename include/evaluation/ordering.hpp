#pragma once

// Technically arbitrary values for biased ordering
constexpr int16_t UNBIASED = 0;
constexpr int16_t KILLER_MOVE_BIAS = 4'000;
constexpr int16_t PROMOTING_MOVE_BIAS = 6'000;
constexpr int16_t MVV_LVA_BIAS = 8'000;
constexpr int16_t HASH_MOVE_BIAS = 10'000;

constexpr std::array<std::pair<int, std::string_view>, 6> BIASES = {
    {{UNBIASED, "Unbiased"},
     {KILLER_MOVE_BIAS, "Killer Move"},
     {PROMOTING_MOVE_BIAS, "Promotion"},
     {MVV_LVA_BIAS, "MVV LVA"},
     {HASH_MOVE_BIAS, "Hash Move"}}};

struct KillerMove {
    chess::Move a;
    chess::Move b;

    inline void add(const chess::Move& move) {
        if (move != a) {
            b = a;
            a = move;
        }
    }

    friend bool operator==(const KillerMove& killer, const chess::Move& move) {
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

  private:
    int king_safety_bonus(Ref<chess::Board> board, const chess::Move& move);
    int shield_bias(Ref<chess::Board> board, const chess::Move& move);

  public:
    enum class OrderFlag : uint8_t {
        None = 0,
        HashMove = 1 << 0,
        KillerMove = 1 << 1,
        Promotion = 1 << 2,
        MVVLVA = 1 << 3,
        PST = 1 << 4
    };

    constexpr inline friend OrderFlag operator|(OrderFlag a, OrderFlag b) {
        return static_cast<OrderFlag>(static_cast<uint8_t>(a) | static_cast<uint8_t>(b));
    }

    constexpr inline bool has_flag(OrderFlag flags, OrderFlag flag) {
        return static_cast<uint8_t>(flags) & static_cast<uint8_t>(flag);
    }

    static constexpr OrderFlag FULL_ORDERING = static_cast<OrderFlag>(
        static_cast<uint8_t>(OrderFlag::HashMove) | static_cast<uint8_t>(OrderFlag::KillerMove) |
        static_cast<uint8_t>(OrderFlag::Promotion) | static_cast<uint8_t>(OrderFlag::MVVLVA) |
        static_cast<uint8_t>(OrderFlag::PST));

  public:
    MoveOrderer() = default;

    inline void clear_history() { std::memset(&m_HistoryHeuristic, 0, sizeof(m_HistoryHeuristic)); }
    inline void clear_killers() { m_KillersHeuristic.fill(KillerMove{}); }

    inline void clear() {
        clear_history();
        clear_killers();
    }

    void order_moves(Ref<chess::Board> board, const chess::Move& hash_move, chess::Movelist& moves,
                     bool in_quiescence, size_t ply, OrderFlag flags = FULL_ORDERING);

    friend class Searcher;
};
