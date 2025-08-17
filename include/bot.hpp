#pragma once

#include "core.hpp"
#include "game/board.hpp"

class Bot {
  private:
    Ref<Board> board;
    bool thinking;

  public:
    Bot() : board(CreateRef<Board>()), thinking(false) {}

    void new_game();
    void stop_thinking() { thinking = false; };
    void quit() { stop_thinking(); }

    Result<void, std::string> set_position(const std::string& fen);
    Result<void, std::string> make_move(const std::string& move);
    int choose_think_time(int time_remaining_white_ms, int time_remaining_black_ms,
                          int increment_white_ms, int increment_black_ms);
    Result<void, std::string> think_timed(int time_ms);

    std::string board_str() { return board->to_string(); }
};