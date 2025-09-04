#include <pch.hpp>

#include "bot.hpp"

#include "game/board.hpp"
#include "game/move.hpp"

#include "generator/generator.hpp"

uint64_t Bot::perft_recursive(Board& board, int depth) {
    if (depth == 0) {
        return 1;
    }

    uint64_t total_nodes = 0;
    auto moves = board.legal_moves();
    for (auto& move : moves) {
        board.make_move(move);
        total_nodes += perft_recursive(board, depth - 1);
        board.unmake_move(move);
    }

    return total_nodes;
}

uint64_t Bot::perft(int depth) { return perft_recursive(*m_Board, depth); }

uint64_t Bot::perft_parallel(int depth, size_t max_threads) {
    if (depth <= 4 || max_threads == 0) {
        return perft(depth);
    }

    auto moves = m_Board->legal_moves();
    size_t n = moves.size();
    if (n == 0) {
        return 0;
    }

    size_t num_threads = std::min(max_threads, n);
    std::vector<std::vector<Move>> chunks(num_threads);
    for (size_t i = 0; i < n; ++i) {
        chunks[i % num_threads].push_back(moves[i]);
    }

    std::vector<std::thread> threads;
    std::vector<uint64_t> results(num_threads, 0);

    auto worker = [&](size_t idx) {
        Board board_copy = *m_Board;
        uint64_t nodes = 0;
        for (auto& move : chunks[idx]) {
            board_copy.make_move(move);
            nodes += perft_recursive(board_copy, depth - 1);
            board_copy.unmake_move(move);
        }
        results[idx] = nodes;
    };

    for (size_t i = 0; i < num_threads; ++i) {
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