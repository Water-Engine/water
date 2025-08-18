#include <pch.hpp>

#include "core.hpp"
#include "game/board.hpp"
#include "launcher.hpp"

constexpr std::array<std::string_view, 3> POSITION_LABELS = {"position", "fen", "moves"};

constexpr std::array<std::string_view, 7> GO_LABELS = {"go",   "movetime", "wtime",    "btime",
                                                       "winc", "binc",     "movestogo"};

void launch() {
    std::string line;
    Engine e;
    while (std::getline(std::cin, line)) {
        if (e.process_line(line) != ParseResult::SUCCESS) {
            return;
        }
    }
}

ParseResult Engine::process_line(const std::string& line) {
    std::vector<std::string> input = str::split(line);
    std::deque<std::string> words(input.begin(), input.end());
    if (words.size() == 0) {
        return ParseResult::SUCCESS;
    }

    std::string cmd_lead = words[0];
    words.pop_front();
    std::string command = deque_join(words);

    if (cmd_lead == "uci") {
        fmt::println("id name Water 0.0.1");
        fmt::println("id author Trevor Swan");
        fmt::println("uciok");
    } else if (cmd_lead == "isready") {
        fmt::println("readyok");
    } else if (cmd_lead == "ucinewgame") {
        m_Bot->new_game();
    } else if (cmd_lead == "position") {
        Result<void, std::string> result = process_position_cmd(command);
        if (result.is_err())
            fmt::println(result.unwrap_err());
    } else if (cmd_lead == "go") {
        process_go_cmd(command);
    } else if (cmd_lead == "d") {
        fmt::println(m_Bot->board_str());
    } else if (cmd_lead == "stop") {
        m_Bot->stop_thinking();
    } else if (cmd_lead == "quit") {
        m_Bot->quit();
        return ParseResult::EXIT;
    }

    return ParseResult::SUCCESS;
}

Result<void, std::string> Engine::process_position_cmd(const std::string& message) {
    bool is_uci_str = str::contains(message, "startpos");
    bool is_fen_str = str::contains(message, "fen");
    if (is_uci_str && is_fen_str) {
        return Result<void, std::string>::Err(
            "Invalid position command: expected either 'startpos' or 'fen', received both");
    }

    if (is_uci_str) {
        m_Bot->set_position(str::from_view(STARTING_FEN));
    } else if (is_fen_str) {
        const auto maybe_custom_fen = try_get_labeled_string(message, "fen", POSITION_LABELS);
        if (maybe_custom_fen.is_some()) {
            std::string custom_fen = str::trim(maybe_custom_fen.unwrap());
            m_Bot->set_position(custom_fen);
        }
    } else {
        return Result<void, std::string>::Err(
            "Invalid position command: expected either 'startpos' or 'fen'");
    }

    const auto maybe_moves = try_get_labeled_string(message, "moves", POSITION_LABELS);
    if (maybe_moves.is_some()) {
        std::string all_moves = maybe_moves.unwrap();
        auto move_list = str::split(all_moves);

        for (const auto& move : move_list) {
            m_Bot->make_move(move);
        }
    }

    return Result<void, std::string>();
}

Result<void, std::string> Engine::process_go_cmd(const std::string& message) {
    int think_time_ms;
    if (str::contains(message, "movetime")) {
        think_time_ms = try_get_labeled_int(message, "movetime", GO_LABELS).unwrap_or(0);
    } else {
        int time_remaining_white_ms = try_get_labeled_int(message, "wtime", GO_LABELS).unwrap_or(0);
        int time_remaining_black_ms = try_get_labeled_int(message, "wtime", GO_LABELS).unwrap_or(0);
        int increment_white_ms = try_get_labeled_int(message, "winc", GO_LABELS).unwrap_or(0);
        int increment_black_ms = try_get_labeled_int(message, "binc", GO_LABELS).unwrap_or(0);

        int suggested = m_Bot->choose_think_time(time_remaining_white_ms, time_remaining_black_ms,
                                               increment_white_ms, increment_black_ms);
        think_time_ms = (suggested == 0) ? INT32_MAX : suggested;
    }

    return m_Bot->think_timed(think_time_ms);
}

Option<int> try_get_labeled_int(const std::string& text, const std::string& label,
                                std::span<const std::string_view> all_labels) {
    Option<std::string> maybe_string = try_get_labeled_string(text, label, all_labels);
    if (maybe_string.is_some()) {
        try {
            int labeled_value = std::stoi(str::split(maybe_string.unwrap())[0]);
            return Option<int>(labeled_value);
        } catch (...) {
            return Option<int>();
        }
    }

    return Option<int>();
}

Option<std::string> try_get_labeled_string(const std::string& text, const std::string& label,
                                           std::span<const std::string_view> all_labels) {
    std::string trimmed = str::trim(text);
    int maybe_value_start = str::str_idx(trimmed, label);
    if (maybe_value_start == -1) {
        return Option<std::string>();
    }

    int value_start = maybe_value_start + label.length() + 1;
    int value_end = trimmed.length();

    for (const auto& other_label : all_labels) {
        if (other_label != label) {
            int other_id_start_idx = str::str_idx(trimmed, other_label);
            if (other_id_start_idx != -1 &&
                (other_id_start_idx > value_start && other_id_start_idx < value_end)) {
                value_end = other_id_start_idx;
            }
        }
    }

    if (value_start >= value_end) {
        return Option<std::string>();
    }

    std::string substring(trimmed.begin() + value_start, trimmed.begin() + value_end);
    str::trim(substring);
    return Option<std::string>(substring);
}