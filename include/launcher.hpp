#pragma once

#include "bot.hpp"

enum class ParseResult {
    SUCCESS = 0,
    EXIT = 1,
    FAILURE = 2,
};

class Engine {
  private:
    Scope<Bot> m_Bot;

  public:
    Engine() : m_Bot(CreateScope<Bot>()) {};

    ParseResult process_line(const std::string& line);
    Result<void, std::string> process_position_cmd(const std::string& options);
    Result<void, std::string> process_go_cmd(const std::string& options);
};

void launch();

Option<int> try_get_labeled_int(const std::string& text, const std::string& label,
                                std::span<const std::string_view> all_labels);

Option<std::string> try_get_labeled_string(const std::string& text, const std::string& label,
                                           std::span<const std::string_view> all_labels);