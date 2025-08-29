#pragma once

#include "game/move.hpp"

struct BookMove {
    Move move;
    uint32_t frequency;
};

using Openings = std::unordered_map<std::string, std::vector<BookMove>>;

class Book {
  private:
    Openings m_OpeningMoves;

  private:
    Book();

  public:
    Book(const Book&) = delete;
    Book& operator=(const Book&) = delete;
    Book(Book&&) = delete;
    Book& operator=(Book&&) = delete;

    static Book& instance() {
        static Book s_instance;
        return s_instance;
    }
};
