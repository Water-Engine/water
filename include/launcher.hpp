#pragma once

#include <deque>
#include <string>

#include "bot.hpp"
#include "core.hpp"

enum ParseResult
{
    SUCCESS = 0,
    EXIT = 1,
    FAILURE = 2,
};

class Engine
{
  private:
    Scope<Bot> bot;

  public:
    Engine() : bot(Bot::create()) {}
    ParseResult process_line(const std::string &line);
    void process_position_cmd(std::deque<std::string> &options);
    void process_go_cmd(std::deque<std::string> &options);
};

void launch();