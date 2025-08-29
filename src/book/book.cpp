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

Option<std::string> Book::try_get_book_move(Ref<Board> board) {
    if (m_OpeningMoves.empty()) {
        return Option<std::string>();
    }

    auto current_fen = board->current_fen(false);

    if (m_OpeningMoves.contains(current_fen)) {
        auto moves = m_OpeningMoves[current_fen];
        std::vector<float> weights(moves.size());
        int total_play_count =
            std::accumulate(moves.begin(), moves.end(), 0, [&](int sum, const BookMove& move) {
                weights.push_back(move.Frequency);
                return sum + move.Frequency;
            });

        std::vector<float> prefix(weights.size());
        prefix[0] = weights[0];
        for (size_t i = 1; i < weights.size(); i++) {
            prefix[i] = prefix[i - 1] + weights[i];
        }
        float total = prefix.back();

        auto it = std::lower_bound(prefix.begin(), prefix.end(), rand_float());
        size_t idx = static_cast<int>(std::distance(prefix.begin(), it));

        return Option<std::string>(moves[idx].MoveString);
    } else {
        return Option<std::string>();
    }
}
