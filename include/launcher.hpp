#pragma once

#include "bot.hpp"

constexpr std::array<std::string_view, 3> POSITION_LABELS = {"position", "fen", "moves"};
constexpr std::array<std::string_view, 9> GO_LABELS = {
    "go", "movetime", "wtime", "btime", "winc", "binc", "movestogo", "perft", "parallel"};
constexpr std::array<std::string_view, 4> OPT_LABELS = {"book", "book-add", "book-reset"};

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

    void prime() { m_Bot->set_position(str::from_view(STARTING_FEN)); }

    ParseResult process_line(const std::string& line);
    Result<void, std::string> process_position_cmd(const std::string& message);
    Result<void, std::string> process_go_cmd(const std::string& message);
    Result<void, std::string> process_opt_cmd(const std::string& message);
};

void launch();

Option<int> try_get_labeled_int(const std::string& text, const std::string& label,
                                std::span<const std::string_view> all_labels);

Option<std::string> try_get_labeled_string(const std::string& text, const std::string& label,
                                           std::span<const std::string_view> all_labels);