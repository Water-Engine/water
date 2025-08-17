#include "launcher.hpp"

#include <iostream>
#include <string>
#include <sstream>
#include <deque>
#include <algorithm>

void launch()
{
    std::string line;
    while (std::getline(std::cin, line))
    {
        if (process_line(line) == FAILURE)
        {
            return;
        }
    }
}

ParseResult process_line(const std::string &line)
{
    std::istringstream iss(line);
    std::deque<std::string> words;
    std::string word;
    while (iss >> word)
        words.push_back(word);

    if (words.size() == 0)
    {
        return SUCCESS;
    }

    std::string cmd_lead = words[0];
    std::for_each(cmd_lead.begin(), cmd_lead.end(), [](char &c)
                  { c = std::tolower(c); });
    words.pop_front();

    if (cmd_lead == "uci")
    {
    }
    else if (cmd_lead == "isready")
    {
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
