#pragma once

#include "evaluation/evaluation.hpp"
#include "evaluation/ordering.hpp"
#include "evaluation/tt.hpp"

constexpr int MAX_SEARCH_DEPTH = 1000;
constexpr size_t DEFAULT_TT_MB = 10;

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

    std::atomic<bool> m_StopFlag{false};
    std::thread m_SearchThread;

    std::atomic<uint64_t> m_NodesVisited{0};
    std::atomic<bool> m_SearchInfo{false}; // TODO: Fix this once searching is correctly implemented

    std::chrono::steady_clock::time_point m_StartTime;
    int m_TimeLimitMs = 0;
    bool m_IsInfiniteSearch{true};

  private:
    std::pair<Move, int> alpha_beta(int depth, int alpha, int beta, std::vector<Move>& pv);

    void run_iterative_deepening();
    inline bool should_stop() const;

    int quiescence(int alpha, int beta);

  public:
    Searcher(Ref<Board> board, size_t tt_size_mb = DEFAULT_TT_MB)
        : m_Board(board), m_Evaluator(board), m_TT(board, tt_size_mb) {}

    ~Searcher() {
        stop_search();
        if (m_SearchThread.joinable()) {
            m_SearchThread.join();
        }
    }

    inline void resize_tt(size_t new_tt_size_mb) { m_TT.resize(new_tt_size_mb); }
    inline void set_nnue_opt(bool nnue) { m_Evaluator.m_UseNNUE = nnue; }
    inline void set_search_info(bool show) { m_SearchInfo = show; }

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
