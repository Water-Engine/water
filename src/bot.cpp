#include <pch.hpp>

#include "bot.hpp"

#include "game/move.hpp"

#include "generator/generator.hpp"

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
    int my_time = m_Board->is_white_to_move() ? time_remaining_white_ms : time_remaining_black_ms;
    int my_increment = m_Board->is_white_to_move() ? increment_white_ms : increment_black_ms;

    float think_time_ms = (float)my_time / 40.0;
    if (USE_MAX_THINKING_TIME) {
        think_time_ms = std::min((float)MAX_THINK_TIME_MS, think_time_ms);
    }

    if (my_time > my_increment * 2) {
        think_time_ms += (float)my_increment * 0.8;
    }

    float min_think_time = std::min(50.0, (float)my_time * 0.25);
    return std::ceil(std::max(min_think_time, think_time_ms));
}

Result<void, std::string> Bot::think_timed(int time_ms) {
    std::vector<Move> moves;
    if (m_Board->is_white_to_move()) {
        moves = Generator::generate<PieceColor::White>(*m_Board);
    } else {
        moves = Generator::generate<PieceColor::Black>(*m_Board);
    }

    DBG(moves.size());
    return Result<void, std::string>::Err(
        fmt::interpolate("I want to think for {} ms, but I can't yet :(", time_ms));
}
