#include <pch.hpp>

#include "search/book.hpp"

INCBIN(GM_BOOK, "assets/gm2001.bin");
INCBIN(KOMODO_BOOK, "assets/komodo.bin");
INCBIN(RODENT_BOOK, "assets/rodent.bin");

Book::Book() : m_UniformRealDist(0.0f, 1.0f), m_Rng(std::random_device{}()) {
    auto entries = str::split(str::trim(str::from_view(OPENINGS)), "pos");
    m_FallbackMoves.reserve(entries.size());

    for (const auto& entry : entries) {
        auto entry_data = into_deque(str::split(str::trim(entry), "\n"));
        if (entry_data.size() < 2) {
            continue;
        }

        auto position_fen = entry_data[0];
        str::trim(position_fen);
        entry_data.pop_front();
        std::vector<FallbackBookMove> moves;
        moves.reserve(entry_data.size());

        for (const auto& move : entry_data) {
            auto move_data = str::split(str::trim(move));

            if (move_data.size() != 2) {
                continue;
            } else if (move_data[0] == " " || move_data[0].empty()) {
                continue;
            }

            try {
                FallbackBookMove bm(move_data[0], std::stoi(move_data[1]));
                moves.emplace_back(bm);
            } catch (...) {
                continue;
            }
        }

        m_FallbackMoves.insert({position_fen, moves});
    }

    m_PolyglotMoves.merge(load_polyglot(reinterpret_cast<const unsigned char*>(gGM_BOOKData), gGM_BOOKSize));
    m_PolyglotMoves.merge(load_polyglot(reinterpret_cast<const unsigned char*>(gKOMODO_BOOKData), gKOMODO_BOOKSize));
    m_PolyglotMoves.merge(load_polyglot(reinterpret_cast<const unsigned char*>(gRODENT_BOOKData), gRODENT_BOOKSize));
}

std::unordered_map<uint64_t, std::vector<PolyglotEntry>> Book::load_polyglot(const unsigned char* data, size_t size) {
    std::unordered_map<uint64_t, std::vector<PolyglotEntry>> bookMap;
    size_t n = size / 14;

    for (size_t i = 0; i < n; ++i) {
        const unsigned char* ptr = data + i*14;

        uint64_t key = 0;
        for (int j = 0; j < 8; ++j) key = (key << 8) | ptr[j];

        uint16_t move   = (ptr[8] << 8) | ptr[9];
        uint16_t weight = (ptr[10] << 8) | ptr[11];
        uint16_t learn  = (ptr[12] << 8) | ptr[13];

        bookMap[key].push_back({move, weight, learn});
    }

    return bookMap;
}

Option<std::string> Book::try_get_book_move(Ref<Board> board, float weight) {
    DBG(m_PolyglotMoves.contains(board->hash()));
    if (m_FallbackMoves.empty()) {
        return Option<std::string>();
    }

    auto current_fen = board->getFen(false);
    auto weight_power = std::clamp(weight, 0.0f, 1.0f);
    auto weighted_frequency = [&](int play_count) -> int {
        return static_cast<int>(std::ceil(std::pow(play_count, weight_power)));
    };

    if (m_FallbackMoves.contains(current_fen)) {
        auto moves = m_FallbackMoves[current_fen];
        std::vector<float> weights;
        weights.reserve(moves.size());
        float total_play_count = std::accumulate(
            moves.begin(), moves.end(), 0.0f, [&](int sum, const FallbackBookMove& move) {
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
