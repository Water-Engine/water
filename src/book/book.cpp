#include <pch.hpp>

#include "book/book.hpp"

#include "book/openings.hpp"

Book::Book() {
    auto entries = str::split(str::trim(str::from_view(OPENINGS)), "pos");
    m_OpeningMoves.reserve(entries.size());

    for (const auto& entry : entries) {
        auto entry_data = str::split(str::trim(entry), "\n");
        if (entry_data.size() < 2) {
            continue;
        }
    }
}