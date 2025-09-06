#pragma once

struct BookMove {
    std::string MoveString;
    uint32_t Frequency;
};

class Book {
  private:
    std::unordered_map<std::string, std::vector<BookMove>> m_OpeningMoves;
    std::uniform_real_distribution<float> m_UniformRealDist;
    std::mt19937 m_Rng;

  private:
    Book();

    inline float rand_float() { return m_UniformRealDist(m_Rng); };

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

    static void read();
};
