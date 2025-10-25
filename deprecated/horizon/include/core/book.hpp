#pragma once

#ifdef EXAMPLE

struct PolyglotMove {
    uint16_t Compact;
    uint16_t Weight;
    uint16_t Learn;
};

struct BookMove {
    std::string MoveString;
    uint32_t Frequency;
};

class Book {
  private:
    std::unordered_map<uint64_t, std::vector<BookMove>> m_PolyglotMoves;

    std::uniform_real_distribution<float> m_UniformRealDist;
    std::mt19937 m_Rng;

  private:
    Book();

    inline float rand_float() { return m_UniformRealDist(m_Rng); };

    static std::unordered_map<uint64_t, std::vector<PolyglotMove>>
    load_polyglot(const unsigned char* data, size_t size);

    static std::unordered_map<uint64_t, std::vector<BookMove>> normalize_polyglot(
        const std::unordered_map<uint64_t, std::vector<PolyglotMove>>& polyglot_moves);

  public:
    Book(const Book&) = delete;
    Book& operator=(const Book&) = delete;
    Book(Book&&) = delete;
    Book& operator=(Book&&) = delete;

    static Book& instance() {
        static Book s_instance;
        return s_instance;
    }

    bool is_book_pos(Ref<Board> board);
    Option<std::string> try_get_book_move(Ref<Board> board, float weight = 0.25);
};

#endif