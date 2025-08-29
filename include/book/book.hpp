#pragma once

struct BookMove {
    std::string MoveString;
    uint32_t Frequency;
};

using Openings = std::unordered_map<std::string, std::vector<BookMove>>;

class Book {
  private:
    Openings m_OpeningMoves;
    std::mt19937 m_Rng;

  private:
    Book();

    float rand_float();

  public:
    Book(const Book&) = delete;
    Book& operator=(const Book&) = delete;
    Book(Book&&) = delete;
    Book& operator=(Book&&) = delete;

    static Book& instance() {
        static Book s_instance;
        return s_instance;
    }

    Option<std::string> try_get_book_move(Ref<Board> board);
};
