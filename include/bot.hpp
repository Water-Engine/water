#pragma once

#include "search/searcher.hpp"

constexpr bool USE_MAX_THINKING_TIME = false;
constexpr int MAX_THINK_TIME_MS = 2500;

class Bot {
  private:
    Ref<Board> m_Board;
    Move m_LastMove;
    Searcher m_Searcher;

    float m_BookWeight;

  private:
    uint64_t perft_recursive(Board& board, int depth);

  public:
    Bot() : m_Board(CreateRef<Board>()), m_LastMove(0), m_Searcher(m_Board), m_BookWeight(0.50f) {}

    void new_game();
    inline void stop_thinking() { m_Searcher.stop_search(); };
    void quit() { stop_thinking(); }
    void resize_tt(size_t new_tt_size_mb) { m_Searcher.resize_tt(new_tt_size_mb); }

    inline void set_weight(float weight) { m_BookWeight = weight; }

    Result<void, std::string> set_position(const std::string& fen);
    Result<void, std::string> make_move(const std::string& move_uci);
    int choose_think_time(int time_remaining_white_ms, int time_remaining_black_ms,
                          int increment_white_ms, int increment_black_ms);

    Result<void, std::string> think_timed(int time_ms);

    uint64_t perft(int depth);

    std::string board_diagram();
};