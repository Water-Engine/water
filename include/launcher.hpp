#pragma once

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
    Engine() : bot(CreateScope<Bot>()) {};

    ParseResult process_line(const std::string &line);
    Result<void, std::string> process_position_cmd(std::deque<std::string> &options);
    Result<void, std::string> process_go_cmd(std::deque<std::string> &options);
};

void launch();