#pragma once

#include "search/openings.hpp"

struct PolyglotEntry {
    uint16_t move;
    uint16_t weight;
    uint16_t learn;
};

struct FallbackBookMove {
    std::string MoveString;
    uint32_t Frequency;
};

class Book {
  private:
    std::unordered_map<uint64_t, std::vector<PolyglotEntry>> m_PolyglotMoves;
    std::unordered_map<std::string, std::vector<FallbackBookMove>> m_FallbackMoves;
    std::uniform_real_distribution<float> m_UniformRealDist;
    std::mt19937 m_Rng;

  private:
    Book();

    inline float rand_float() { return m_UniformRealDist(m_Rng); };

    static std::unordered_map<uint64_t, std::vector<PolyglotEntry>> load_polyglot(const unsigned char* data, size_t size);

  public:
    Book(const Book&) = delete;
    Book& operator=(const Book&) = delete;
    Book(Book&&) = delete;
    Book& operator=(Book&&) = delete;

    static Book& instance() {
        static Book s_instance;
        return s_instance;
    }

    Option<std::string> try_get_book_move(Ref<Board> board, float weight = 0.25);
};
