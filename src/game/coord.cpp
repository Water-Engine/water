#include <pch.hpp>

#include "game/board.hpp"
#include "game/coord.hpp"

Coord::Coord(const std::string& square_string) {
    if (square_string.length() != 2) {
        m_FileIdx = -1;
        m_RankIdx = -1;
    }

    std::string lowered = str::to_lower(square_string);
    m_FileIdx = str::char_idx(str::from_view(FILES), lowered[0]);
    m_RankIdx = str::char_idx(str::from_view(RANKS), lowered[1]);
}

bool Coord::valid_square_idx() const {
    return m_FileIdx >= 0 && m_FileIdx < 8 && m_RankIdx >= 0 && m_RankIdx < 8;
}

bool Coord::valid_square_idx(int square_idx) {
    Coord c(square_idx);
    return c.valid_square_idx();
}

std::string Coord::as_str() const {
    if (!valid_square_idx()) {
        return std::string();
    }

    char file_name = FILES[m_FileIdx];
    char rank_name = RANKS[m_RankIdx];

    char combined[3] = {file_name, rank_name, '\0'};
    return std::string(combined);
}

std::string Coord::as_str(int square_idx) {
    Coord c(square_idx);
    return c.as_str();
}