#include <pch.hpp>

#include "bot.hpp"

#include "evaluation/evaluation.hpp"
#include "evaluation/ordering.hpp"

#include "book/book.hpp"

void Bot::new_game() {}

Result<void, std::string> Bot::set_position(const std::string& fen) {
    if (m_Board->setFen(fen)) {
        return Result<void, std::string>();
    } else {
        return Result<void, std::string>::Err("Failed to load/parse fen");
    }
}

Result<void, std::string> Bot::make_move(const std::string& move_uci) {
    Move move = uci::uciToMove(*m_Board, move_uci);
    m_Board->makeMove(move);
    return Result<void, std::string>();
}

int Bot::choose_think_time(int time_remaining_white_ms, int time_remaining_black_ms,
                           int increment_white_ms, int increment_black_ms) {
    int my_time =
        (m_Board->sideToMove() == Color::WHITE) ? time_remaining_white_ms : time_remaining_black_ms;
    int my_increment =
        (m_Board->sideToMove() == Color::WHITE) ? increment_white_ms : increment_black_ms;

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

Result<void, std::string> Bot::think_timed([[maybe_unused]] int time_ms) {
    auto bm = Book::instance().try_get_book_move(m_Board);
    if (bm.is_some()) {
        fmt::println("bestmove {}", bm.unwrap());
        return Result<void, std::string>();
    }

    m_Searcher.find_bestmove();
    fmt::println(m_Searcher.retrieve_bestmove());

    return Result<void, std::string>();
}

std::string Bot::board_str() {
    // TODO: board diagram
    return m_Board->getFen();
}