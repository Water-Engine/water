#include <pch.hpp>

#include "book/book.hpp"
#include "book/openings.hpp"

INCBIN(GM_BOOK, "assets/gm2001.bin");

Book::Book() : m_UniformRealDist(0.0f, 1.0f), m_Rng(std::random_device{}()) {
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
        std::vector<BookMove> moves;
        moves.reserve(entry_data.size());

        for (const auto& move : entry_data) {
            auto move_data = str::split(str::trim(move));

            if (move_data.size() != 2) {
                continue;
            } else if (move_data[0] == " " || move_data[0].empty()) {
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

Option<std::string> Book::try_get_book_move(Ref<Board> board, float weight) {
    if (m_OpeningMoves.empty()) {
        return Option<std::string>();
    }

    auto current_fen = board->getFen(false);
    auto weight_power = std::clamp(weight, 0.0f, 1.0f);
    auto weighted_frequency = [&](int play_count) -> int {
        return static_cast<int>(std::ceil(std::pow(play_count, weight_power)));
    };

    if (m_OpeningMoves.contains(current_fen)) {
        auto moves = m_OpeningMoves[current_fen];
        std::vector<float> weights;
        weights.reserve(moves.size());
        float total_play_count =
            std::accumulate(moves.begin(), moves.end(), 0.0f, [&](int sum, const BookMove& move) {
                int frequency = weighted_frequency(move.Frequency);
                weights.push_back(frequency);
                return sum + frequency;
            });

        std::vector<float> prefix(weights.size());
        prefix[0] = weights[0] / total_play_count;
        for (size_t i = 1; i < weights.size(); ++i) {
            prefix[i] = prefix[i - 1] + weights[i] / total_play_count;
        }

        auto it = std::lower_bound(prefix.begin(), prefix.end(), rand_float());
        size_t idx = static_cast<int>(std::distance(prefix.begin(), it));

        return Option<std::string>(moves[idx].MoveString);
    } else {
        return Option<std::string>();
    }
}

void Book::read() {}
