#pragma once

#include "game/board.hpp"

constexpr bool USE_MAX_THINKING_TIME = false;
constexpr int MAX_THINK_TIME_MS = 2500;

class Bot {
  private:
    Ref<Board> m_Board;
    bool m_Thinking;

  private:
    uint64_t perft_recursive(Board& board, int depth);

  public:
    Bot() : m_Board(CreateRef<Board>()), m_Thinking(false) {}

    void new_game();
    void stop_thinking() { m_Thinking = false; };
    void quit() { stop_thinking(); }

    Result<void, std::string> set_position(const std::string& fen);
    Result<void, std::string> make_move(const std::string& move_uci);
    int choose_think_time(int time_remaining_white_ms, int time_remaining_black_ms,
                          int increment_white_ms, int increment_black_ms);
    Result<void, std::string> think_timed(int time_ms);

    uint64_t perft(int depth);
    uint64_t perft_parallel(int depth, size_t max_threads = 2);

    std::string board_str() { return m_Board->to_string(); }
};