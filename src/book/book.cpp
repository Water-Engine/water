#include <pch.hpp>

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
