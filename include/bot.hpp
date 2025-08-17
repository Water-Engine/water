#pragma once

#include "core.hpp"
#include "game/board.hpp"

class Bot
{
  private:
    Ref<Board> board;
    bool thinking;

  public:
    Bot() : board(CreateRef<Board>()), thinking(false) {}

    void new_game();
    void stop_thinking() { thinking = false; };
    void quit() { stop_thinking(); }

    std::string board_str() { return board->to_string(); }
};