#include <pch.hpp>

#include "game/board.hpp"

#include "book/book.hpp"
#include "book/openings.hpp"

Book::Book() : m_Rng(std::random_device{}()) {
    auto entries = str::split(str::trim(str::from_view(OPENINGS)), "pos");
    m_OpeningMoves.reserve(entries.size());

    for (const auto& entry : entries) {
        auto entry_data = into_deque(str::split(str::trim(entry), "\n"));
        if (entry_data.size() < 2) {
            continue;
        }

        auto position_fen = entry_data[0];
        str::trim(position_fen);
        entry_data.pop_front();
        std::vector<BookMove> moves(entry_data.size());

        for (const auto& move : entry_data) {
            auto move_data = str::split(move);
            if (move_data.size() != 2) {
                continue;
            }

            try {
                BookMove bm(move_data[0], std::stoi(move_data[1]));
                moves.emplace_back(bm);
            } catch (...) {
                continue;
            }
        }

        m_OpeningMoves.insert({position_fen, moves});
    }
}

float Book::rand_float() {
    std::uniform_real_distribution<float> dist(0, 1);
    return dist(m_Rng);
}

Option<std::string> Book::try_get_book_move(Ref<Board> board, float weight) {
    if (m_OpeningMoves.empty()) {
        return Option<std::string>();
    }

    auto current_fen = board->current_fen(false);
    float weight_power = std::clamp(weight, 0.0f, 1.0f);

    auto weighted_play_count = [&](int play_count) -> int {
        return static_cast<int>(std::ceil(std::pow(play_count, weight_power)));
    };

    if (m_OpeningMoves.contains(current_fen)) {
        auto moves = m_OpeningMoves[current_fen];
        int total_play_count =
            std::accumulate(moves.begin(), moves.end(), 0, [&](int sum, const BookMove& move) {
                return sum + weighted_play_count(move.Frequency);
            });

        double weights[moves.size()];
    } else {
        return Option<std::string>();
    }
}
