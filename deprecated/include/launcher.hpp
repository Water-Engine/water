#pragma once

#include "bot.hpp"

constexpr std::array<std::string_view, 3> POSITION_LABELS = {"position", "fen", "moves"};
constexpr std::array<std::string_view, 9> GO_LABELS = {
    "go", "movetime", "wtime", "btime", "winc", "binc", "movestogo", "perft", "parallel"};
constexpr std::array<std::string_view, 10> OPT_LABELS = {
    "book", "book-add", "book-reset", "weight", "depth",
    "hash", "usennue",  "searchinfo", "tb",     "tbfree"};

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

Option<std::string> try_get_labeled_string(const std::string& text, const std::string& label,
                                           std::span<const std::string_view> all_labels);

Option<bool> try_get_labeled_bool(const std::string& text, const std::string& label,
                                  std::span<const std::string_view> all_labels);

template <typename T>
Option<T> try_get_labeled_numeric(const std::string& text, const std::string& label,
                                  std::span<const std::string_view> all_labels) {
    Option<std::string> maybe_string = try_get_labeled_string(text, label, all_labels);
    if (!maybe_string.is_some()) {
        return Option<T>();
    }

    std::string first_token = str::split(maybe_string.unwrap())[0];

    try {
        if constexpr (std::is_same_v<T, int>) {
            return Option<T>(std::stoi(first_token));
        } else if constexpr (std::is_same_v<T, long>) {
            return Option<T>(std::stol(first_token));
        } else if constexpr (std::is_same_v<T, long long>) {
            return Option<T>(std::stoll(first_token));
        } else if constexpr (std::is_same_v<T, unsigned long>) {
            return Option<T>(std::stoul(first_token));
        } else if constexpr (std::is_same_v<T, unsigned long long>) {
            return Option<T>(std::stoull(first_token));
        } else if constexpr (std::is_same_v<T, float>) {
            return Option<T>(std::stof(first_token));
        } else if constexpr (std::is_same_v<T, double>) {
            return Option<T>(std::stod(first_token));
        } else if constexpr (std::is_same_v<T, long double>) {
            return Option<T>(std::stold(first_token));
        } else {
            static_assert(always_false<T>, "Unsupported type for try_get_labeled_numeric");
        }
    } catch (...) {
        return Option<T>();
    }
}
