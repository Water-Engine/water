#include <pch.hpp>

#include "bot.hpp"

void Bot::new_game() {}

Result<void, std::string> Bot::set_position(const std::string& fen) {
    m_Board->load_from_fen(fen);
    return Result<void, std::string>();
}

Result<void, std::string> Bot::make_move(const std::string& move) {
    return Result<void, std::string>();
}

int Bot::choose_think_time(int time_remaining_white_ms, int time_remaining_black_ms,
                           int increment_white_ms, int increment_black_ms) {
    return 0;
}

Result<void, std::string> Bot::think_timed(int time_ms) { return Result<void, std::string>::Err("Not implemented"); }
