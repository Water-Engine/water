#include "launcher.hpp"

#include <algorithm>
#include <deque>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include "core.hpp"

void launch()
{
    std::string line;
    Engine e;
    while (std::getline(std::cin, line))
    {
        if (e.process_line(line) == FAILURE)
            return;
    }
}

ParseResult Engine::process_line(const std::string &line)
{
    std::vector<std::string> input = str::split(line);
    std::deque<std::string> words(input.begin(), input.end());
    if (words.size() == 0)
        return SUCCESS;

    std::string cmd_lead = words[0];
    words.pop_front();

    if (cmd_lead == "uci")
    {
        fmt::println("id name Water 0.0.1");
        fmt::println("id author Trevor Swan");
        fmt::println("uciok");
    }
    else if (cmd_lead == "isready")
    {
        fmt::println("readyok");
    }
    else if (cmd_lead == "ucinewgame")
    {
        bot->new_game();
    }
    else if (cmd_lead == "position")
    {
    }
    else if (cmd_lead == "go")
    {
    }
    else if (cmd_lead == "d")
    {
    }
    else if (cmd_lead == "stop")
    {
    }
    else if (cmd_lead == "quit")
    {
        return FAILURE;
    }

    return SUCCESS;
}
