#pragma once

#include <string>

#include "bot.hpp"
#include "core.hpp"

enum ParseResult
{
    SUCCESS = 0,
    FAILURE = 1,
};

class Engine
{
  private:
    Scope<Bot> bot;

  public:
    Engine() : bot(Bot::create()) {}
    ParseResult process_line(const std::string &line);
    void process_position_cmd(std::vector<std::string> &options);
    void process_go_cmd(std::vector<std::string> &options);
};

void launch();