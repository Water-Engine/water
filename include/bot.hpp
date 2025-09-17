#pragma once

#include "search/searcher.hpp"

constexpr bool USE_MAX_THINKING_TIME = false;
constexpr int MAX_THINK_TIME_MS = 2500;

class Bot {
  private:
    Ref<chess::Board> m_Board;
    chess::Move m_LastMove;
    Searcher m_Searcher;

    float m_BookWeight;

  private:
    uint64_t perft_recursive(chess::Board& board, int depth);

  public:
    Bot()
        : m_Board(CreateRef<chess::Board>()), m_LastMove(0), m_Searcher(m_Board),
          m_BookWeight(0.50f) {}

    void new_game();
    inline void stop_thinking() { m_Searcher.stop_search(); };
    void quit() { stop_thinking(); }

    inline void resize_tt(size_t new_tt_size_mb) { m_Searcher.resize_tt(new_tt_size_mb); }
    inline void set_weight(float weight) { m_BookWeight = weight; }
    inline void set_nnue(bool nnue) { m_Searcher.set_nnue_opt(nnue); }
    inline void set_search_info(bool show) { m_Searcher.set_search_info(show); }
    int evaluate_current();
    Result<void, std::string> load_tb_files(const std::string& folder);
    inline void free_tb_files() { m_Searcher.free_tb_files(); }
    inline void print_tb_status() { fmt::println(m_Searcher.tb_status()); }

    Result<void, std::string> set_position(const std::string& fen);
    Result<void, std::string> make_move(const std::string& move_uci);
    int choose_think_time(int time_remaining_white_ms, int time_remaining_black_ms,
                          int increment_white_ms, int increment_black_ms);

    Result<void, std::string> think_timed(int time_ms);

    uint64_t perft(int depth);

    std::string board_diagram();
};