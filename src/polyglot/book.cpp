#include <pch.hpp>

#include "polyglot/book.hpp"
#include "polyglot/horizon.hpp"

INCBIN(BOOK, "assets/8moves_v3.bin");

Book::Book() : m_UniformRealDist(0.0f, 1.0f), m_Rng(std::random_device{}()) {
    auto moves = read_polyglot(reinterpret_cast<const unsigned char*>(gBOOKData), gBOOKSize);
    m_PolyglotMoves.merge(normalize_polyglot(moves));
}

std::unordered_map<uint64_t, std::vector<PolyglotMove>>
Book::read_polyglot(const unsigned char* data, size_t size) {
    std::unordered_map<uint64_t, std::vector<PolyglotMove>> book_map;
    size_t n = size / 14;

    for (size_t i = 0; i < n; ++i) {
        const unsigned char* ptr = data + i * 14;

        uint64_t key = 0;
        for (int j = 0; j < 8; ++j) {
            key = (key << 8) | ptr[j];
        }

        // Big-endian decoding to match encoder's endian 
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

bool Book::is_book_pos(Ref<Board> board) { return m_PolyglotMoves.contains(board->hash()); }

Option<std::string> Book::try_get_book_move(Ref<Board> board, float weight) {
    if (!is_book_pos(board)) {
        return Option<std::string>();
    }

    auto current_hash = board->hash();

    if (!m_PolyglotMoves.contains(current_hash)) {
        return Option<std::string>();
    }

    auto& relevant_moves = m_PolyglotMoves[current_hash];

    // === Special case: always pick most played at max weight ===
    if (weight >= 1.0f) {
        auto best_it = std::max_element(
            relevant_moves.begin(), relevant_moves.end(),
            [](const BookMove& a, const BookMove& b) { return a.Frequency < b.Frequency; });
        if (best_it != relevant_moves.end()) {
            return Option<std::string>(best_it->MoveString);
        }
        return Option<std::string>();
    }

    // === Otherwise, do weighted random selection ===
    auto weight_power = std::clamp(weight, 0.0f, 1.0f);
    auto weighted_frequency = [&](int play_count) -> int {
        return static_cast<int>(std::ceil(std::pow(play_count, weight_power)));
    };

    std::vector<float> weights;
    weights.reserve(relevant_moves.size());
    float total_play_count = std::accumulate(relevant_moves.begin(), relevant_moves.end(), 0.0f,
                                             [&](float sum, const BookMove& move) {
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
    size_t idx = static_cast<size_t>(std::distance(prefix.begin(), it));

    return Option<std::string>(relevant_moves[idx].MoveString);
}

void Book::load_external_book(const std::filesystem::path& book_path, bool preserve_existing,
                              int depth) {
    if (!std::filesystem::exists(book_path)) {
        return;
    }

    std::unordered_map<uint64_t, std::vector<PolyglotMove>> moves;
    if (book_path.extension() == ".bin") {
        std::ifstream file_stream(book_path, std::ios::binary | std::ios::ate);
        if (!file_stream) {
            return;
        }

        std::streamsize size = file_stream.tellg();
        file_stream.seekg(0, std::ios::beg);

        std::vector<unsigned char> buffer(size);
        if (!file_stream.read(reinterpret_cast<char*>(buffer.data()), size)) {
            return;
        }

        const unsigned char* data = buffer.data();
        moves = read_polyglot(reinterpret_cast<const unsigned char*>(data), buffer.size());
    } else {
        auto contents = make_polyglot_book(depth, book_path);
        moves =
            read_polyglot(reinterpret_cast<const unsigned char*>(contents.data()), contents.size());
    }

    if (!preserve_existing) {
        for (auto& [_, v] : m_PolyglotMoves) {
            v.clear();
        }
        m_PolyglotMoves.clear();
    }
    m_PolyglotMoves.merge(normalize_polyglot(moves));
}
