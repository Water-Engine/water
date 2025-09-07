#include <pch.hpp>

#include "search/book.hpp"

INCBIN(GM_BOOK, "assets/gm2001.bin");

Book::Book() : m_UniformRealDist(0.0f, 1.0f), m_Rng(std::random_device{}()) {
    auto entries = str::split(str::trim(str::from_view(OPENINGS)), "pos");
    m_OtherMoves.reserve(entries.size());

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

        m_OtherMoves.insert({position_fen, moves});
    }

    auto gm_moves =
        load_polyglot(reinterpret_cast<const unsigned char*>(gGM_BOOKData), gGM_BOOKSize);
    m_PolyglotMoves.merge(normalize_polyglot(gm_moves));
}

std::unordered_map<uint64_t, std::vector<PolyglotMove>>
Book::load_polyglot(const unsigned char* data, size_t size) {
    std::unordered_map<uint64_t, std::vector<PolyglotMove>> book_map;
    size_t n = size / 14;

    for (size_t i = 0; i < n; ++i) {
        const unsigned char* ptr = data + i * 14;

        uint64_t key = 0;
        for (int j = 0; j < 8; ++j) {
            key = (key << 8) | ptr[j];
        }

        uint16_t move = (ptr[8] << 8) | ptr[9];
        uint16_t weight = (ptr[10] << 8) | ptr[11];
        uint16_t learn = (ptr[12] << 8) | ptr[13];

        book_map[key].push_back({move, weight, learn});
    }

    return book_map;
}

std::unordered_map<uint64_t, std::vector<BookMove>> Book::normalize_polyglot(
    const std::unordered_map<uint64_t, std::vector<PolyglotMove>>& polyglot_moves) {
    std::unordered_map<uint64_t, std::vector<BookMove>> converted;

    for (const auto& [k, v] : polyglot_moves) {
        converted[k].reserve(v.size());
        for (const auto& move : v) {
            converted[k].push_back({uci::moveToUci(move.Compact), move.Weight});
        }
    }

    return converted;
}

bool Book::is_book_pos(Ref<Board> board) {
    DBG(m_PolyglotMoves.contains(board->hash()));
    return m_PolyglotMoves.contains(board->hash()) || m_OtherMoves.contains(board->getFen(false));
}

Option<std::string> Book::try_get_book_move(Ref<Board> board, float weight) {
    if (!is_book_pos(board)) {
        return Option<std::string>();
    }

    auto current_fen = board->getFen(false);
    auto current_hash = board->hash();

    auto weight_power = std::clamp(weight, 0.0f, 1.0f);
    auto weighted_frequency = [&](int play_count) -> int {
        return static_cast<int>(std::ceil(std::pow(play_count, weight_power)));
    };

    // Extract relevant moves for the position
    std::vector<BookMove> moves;
    if (m_PolyglotMoves.contains(current_hash)) {
        auto relevant_moves = m_PolyglotMoves[current_hash];
        moves.insert(moves.end(), relevant_moves.begin(), relevant_moves.end());
    }

    if (m_OtherMoves.contains(current_fen)) {
        auto relevant_moves = m_OtherMoves[current_fen];
        moves.insert(moves.end(), relevant_moves.begin(), relevant_moves.end());
    }

    // This should never be true, but is done for safety incase of breaking changes
    if (moves.empty()) {
        return Option<std::string>();
    }

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
}
