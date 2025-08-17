#include <pch.hpp>

#include "core.hpp"
#include "launcher.hpp"

void launch()
{
    std::string line;
    Engine e;
    while (std::getline(std::cin, line))
    {
        if (e.process_line(line) != SUCCESS)
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
        process_position_cmd(words);
    }
    else if (cmd_lead == "go")
    {
        process_go_cmd(words);
    }
    else if (cmd_lead == "d")
    {
        fmt::println(bot->board_str());
    }
    else if (cmd_lead == "stop")
    {
        bot->stop_thinking();
    }
    else if (cmd_lead == "quit")
    {
        bot->quit();
        return EXIT;
    }

    return SUCCESS;
}

Result<void, std::string> Engine::process_position_cmd(std::deque<std::string> &options)
{
    bool is_uci_str = contains(options, "startpos");
    bool is_fen_str = contains(options, "fen");
    return Result<void, std::string>();
}

Result<void, std::string> Engine::process_go_cmd(std::deque<std::string> &options)
{
    return Result<void, std::string>();
}
