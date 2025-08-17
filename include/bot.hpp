#pragma once

#include "core.hpp"
#include "game/board.hpp"

class Bot
{
  private:
    Bot() : board(CreateRef<Board>()) {}
    Ref<Board> board;
    bool thinking = false;

  public:
    static Scope<Bot> create();

    void new_game();
    void stop_thinking() { thinking = false; };
    std::string board_str() { return board->to_string(); }
};