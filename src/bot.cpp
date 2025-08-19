#include <pch.hpp>

#include "bot.hpp"

#include "game/move.hpp"

#include "generator/validator.hpp"

void Bot::new_game() {}

Result<void, std::string> Bot::set_position(const std::string& fen) {
    m_Board->load_from_fen(fen);
    return Result<void, std::string>();
}

Result<void, std::string> Bot::make_move(const std::string& move_uci) {
    Move move(m_Board, move_uci);
    m_Board->make_move(move);
    return Result<void, std::string>();
}

int Bot::choose_think_time(int time_remaining_white_ms, int time_remaining_black_ms,
                           int increment_white_ms, int increment_black_ms) {
    return 0;
}

Result<void, std::string> Bot::think_timed(int time_ms) {
    Validator move_validator(m_Board);
    return Result<void, std::string>();
}
