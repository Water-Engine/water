#pragma once

#include "core.hpp"

class Bot
{
  private:
    Bot() {}
    bool thinking = false;

  public:
    static Scope<Bot> create();

    void new_game();
    void stop_thinking() { thinking = false; };
};