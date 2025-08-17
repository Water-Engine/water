#include "launcher.hpp"
#include "core.hpp"

#include <iostream>
#include <string>
#include <sstream>
#include <deque>
#include <vector>
#include <algorithm>

void launch()
{
    std::string line;
    while (std::getline(std::cin, line))
    {
        if (process_line(line) == FAILURE) return;
    }
}

ParseResult process_line(const std::string &line)
{
    std::vector<std::string> input = str::split(line);
    std::deque<std::string> words(input.begin(), input.end());
    if (words.size() == 0) return SUCCESS;

    std::string cmd_lead = words[0];
    words.pop_front();

    if (cmd_lead == "uci")
    {
    }
    else if (cmd_lead == "isready")
    {
        fmt::println("readyok");
    }
    else if (cmd_lead == "ucinewgame")
    {
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
