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
        auto nodes = perft_recursive(board, depth - 1, divide);
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

uint64_t Bot::perft_parallel(int depth, size_t max_threads) {
    if (depth <= 4 || max_threads == 0) {
        return perft(depth, false);
    }

    auto moves = Generator::generate(*m_Board);
    size_t n = moves.size();
    if (n == 0) {
        return 0;
    }

    size_t num_threads = std::min(max_threads, n);
    std::vector<std::vector<Move>> chunks(num_threads);
    for (size_t i = 0; i < n; i++) {
        chunks[i % num_threads].push_back(moves[i]);
    }

    std::vector<std::thread> threads;
    std::vector<uint64_t> results(num_threads, 0);

    auto worker = [&](size_t idx) {
        Board board_copy = *m_Board;
        uint64_t nodes = 0;
        for (auto& move : chunks[idx]) {
            board_copy.make_move(move);
            nodes += perft_recursive(board_copy, depth - 1, false);
            board_copy.unmake_last_move();
        }
        results[idx] = nodes;
    };

    for (size_t i = 0; i < num_threads; i++) {
        threads.emplace_back(worker, i);
    }

    for (auto& t : threads) {
        t.join();
    }

    uint64_t total = 0;
    for (auto r : results) {
        total += r;
    }

    return total;
}