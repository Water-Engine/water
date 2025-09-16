#pragma once

#include "evaluation/evaluation.hpp"
#include "evaluation/ordering.hpp"
#include "evaluation/tt.hpp"

#include "search/syzygy.hpp"

constexpr int MAX_SEARCH_DEPTH = 256;
constexpr int INFINITE_DEPTH_CAP = 10 * MAX_SEARCH_DEPTH;
constexpr size_t DEFAULT_TT_MB = 10;

constexpr int ENDGAME_MATERIAL_CUTOFF = 1400;

const int INF = 1'000'000'000;
const int NEG_INF = -INF;

constexpr int MATE_SCORE = 32'000'000;
constexpr int MATE_THRESHOLD = 30'000'000;

struct BestMove {
    Move BestMove;
    int BestMoveEval;
};

class Searcher {
  private:
    Ref<Board> m_Board;
    Evaluator m_Evaluator;
    mutable std::mutex m_BestMoveMutex;
    Option<BestMove> m_BestMoveSoFar{};

    TranspositionTable m_TT;
    MoveOrderer m_Orderer;
    SyzygyManager m_Syzygy;

    std::atomic<bool> m_StopFlag{false};
    std::thread m_SearchThread;

    std::atomic<uint64_t> m_NodesVisited{0};
    std::atomic<uint64_t> m_QNodesVisited{0};
    std::atomic<bool> m_SearchInfo{true};

    std::chrono::steady_clock::time_point m_StartTime;
    int m_TimeLimitMs = 0;
    bool m_IsInfiniteSearch{true};

  private:
    std::pair<Move, int> alpha_beta(int depth, int alpha, int beta, int ply, std::vector<Move>& pv);
    int quiescence(int alpha, int beta, int ply);

    void run_iterative_deepening();
    inline bool should_stop() const;
    void halt() {
        stop_search();
        if (m_SearchThread.joinable()) {
            m_SearchThread.join();
        }
    }

    inline int adjust_mate_score(int score, int ply) {
        if (score > MATE_THRESHOLD) {
            return MATE_SCORE - ply;
        } else if (score < -MATE_THRESHOLD) {
            return -MATE_SCORE + ply;
        } else {
            return score;
        }
    }

    inline bool is_endgame() const {
        auto friendly_material = m_Evaluator.get_friendly_material();
        auto opponent_material = m_Evaluator.get_opponent_material();

        // Considered
        return friendly_material.non_pawn_score() + opponent_material.non_pawn_score() <=
               ENDGAME_MATERIAL_CUTOFF;
    }

  public:
    Searcher(Ref<Board> board, size_t tt_size_mb = DEFAULT_TT_MB)
        : m_Board(board), m_Evaluator(board), m_TT(board, tt_size_mb), m_Syzygy(board) {}

    ~Searcher() { halt(); }

    inline void resize_tt(size_t new_tt_size_mb) { m_TT.resize(new_tt_size_mb); }
    inline void set_nnue_opt(bool nnue) { m_Evaluator.m_UseNNUE = nnue; }
    inline void set_search_info(bool show) { m_SearchInfo = show; }

    inline void reset() {
        halt();
        m_TT.clear();
        m_Orderer.clear();
    }

    void find_bestmove(int time_limit_ms);
    void stop_search() { m_StopFlag = true; }

    inline void set_bestmove(const Move& best_move, int best_evaluation) {
        std::lock_guard<std::mutex> lock(m_BestMoveMutex);
        m_BestMoveSoFar = Option<BestMove>({best_move, best_evaluation});
    };

    inline std::string retrieve_bestmove() const {
        std::lock_guard<std::mutex> lock(m_BestMoveMutex);
        auto bm = m_BestMoveSoFar.unwrap_or(BestMove{});
        return fmt::interpolate("bestmove {}", uci::moveToUci(bm.BestMove));
    }

    inline void print_bestmove() const { fmt::println(retrieve_bestmove()); }
};
