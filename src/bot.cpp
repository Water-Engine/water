#include <pch.hpp>

#include "bot.hpp"

#include "game/move.hpp"

#include "generator/generator.hpp"

uint64_t Bot::perft_recursive(Board& board, int depth, bool divide) {
    if (depth == 0) {
        return 1;
    }

    uint64_t total_nodes = 0;
    auto moves = Generator::generate(board);
    for (auto& move : moves) {
        board.make_move(move);
        auto nodes = perft_recursive(board, depth - 1);
        board.unmake_last_move();

        if (divide) {
            fmt::println("{}: {}", move.to_uci(), nodes);
        }
        total_nodes += nodes;
    }

    return total_nodes;
}

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
    MoveList moves;

    return Result<void, std::string>::Err(
        fmt::interpolate("I want to think for {} ms, but I can't yet :(", time_ms));
}

uint64_t Bot::perft(int depth, bool divide) { return perft_recursive(*m_Board, depth, divide); }

uint64_t Bot::perft_parallel(int depth) {
    // Small depths, just use normal single-threaded perft
    if (depth <= 4) {
        return perft(depth);
    }

    auto moves = Generator::generate(*m_Board);
    size_t n = moves.size();
    if (n == 0) {
        return 0;
    }

    size_t mid = n / 2;

    std::vector<Move> left_moves(moves.begin(), moves.begin() + mid);
    std::vector<Move> right_moves(moves.begin() + mid, moves.end());

    std::atomic<uint64_t> left_count{0};
    std::atomic<uint64_t> right_count{0};

    auto worker = [&](std::vector<Move>& move_subset, std::atomic<uint64_t>& counter) {
        Board board_copy = *m_Board;
        uint64_t nodes = 0;
        for (auto& move : move_subset) {
            board_copy.make_move(move);
            nodes += perft_recursive(board_copy, depth - 1);
            board_copy.unmake_last_move();
        }
        counter = nodes;
    };

    std::thread t1(worker, std::ref(left_moves), std::ref(left_count));
    std::thread t2(worker, std::ref(right_moves), std::ref(right_count));

    t1.join();
    t2.join();

    return left_count + right_count;
}