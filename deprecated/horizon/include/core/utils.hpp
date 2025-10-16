#pragma once

constexpr std::string_view STARTING_FEN =
    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

constexpr std::string_view FILES = "abcdefgh";
constexpr std::string_view RANKS = "12345678";

class Coord {
  private:
    int m_FileIdx;
    int m_RankIdx;

  public:
    Coord() : m_FileIdx(-1), m_RankIdx(-1) {}
    constexpr Coord(int file_idx, int rank_idx) : m_FileIdx(file_idx), m_RankIdx(rank_idx) {}
    constexpr Coord(int square)
        : m_FileIdx(file_from_square(square)), m_RankIdx(rank_from_square(square)) {}

    constexpr int file_idx() const { return m_FileIdx; }
    constexpr int rank_idx() const { return m_RankIdx; }

    int square_idx() const { return valid_square_idx() ? square_idx_unchecked() : -1; }
    constexpr int square_idx_unchecked() const { return m_RankIdx * 8 + m_FileIdx; }
    constexpr static int square_idx_unchecked(int file, int rank) { return rank * 8 + file; }

    constexpr static int file_from_square(int square_idx) { return square_idx & 0b000111; }
    constexpr static int rank_from_square(int square_idx) { return square_idx >> 3; }

    bool is_light_square() const { return (m_FileIdx + m_RankIdx) % 2 != 0; }

    inline bool valid_square_idx() const {
        return m_FileIdx >= 0 && m_FileIdx < 8 && m_RankIdx >= 0 && m_RankIdx < 8;
    }
    static bool valid_square_idx(int square_idx) {
        Coord c(square_idx);
        return c.valid_square_idx();
    }

    std::string as_str() const {
        if (!valid_square_idx()) {
            return std::string();
        }

        char file_name = FILES[m_FileIdx];
        char rank_name = RANKS[m_RankIdx];

        char combined[3] = {file_name, rank_name, '\0'};
        return std::string(combined);
    }

    static std::string as_str(int square_idx) {
        Coord c(square_idx);
        return c.as_str();
    }

    friend bool operator==(const Coord& a, const Coord& b) {
        return a.square_idx_unchecked() == b.square_idx_unchecked();
    }

    operator int() const { return square_idx(); }

    friend Coord operator+(const Coord& a, const Coord& b) {
        return Coord(a.m_FileIdx + b.m_FileIdx, a.m_RankIdx + b.m_RankIdx);
    }

    friend Coord operator-(const Coord& a, const Coord& b) {
        return Coord(a.m_FileIdx - b.m_FileIdx, a.m_RankIdx - b.m_RankIdx);
    }

    friend Coord operator*(const Coord& a, int scalar) {
        return Coord(a.m_FileIdx * scalar, a.m_RankIdx * scalar);
    }
};

namespace Squares {
// clang-format off
enum Index : int {
    A1 = 0, B1, C1, D1, E1, F1, G1, H1,
    A2, B2, C2, D2, E2, F2, G2, H2,
    A3, B3, C3, D3, E3, F3, G3, H3,
    A4, B4, C4, D4, E4, F4, G4, H4,
    A5, B5, C5, D5, E5, F5, G5, H5,
    A6, B6, C6, D6, E6, F6, G6, H6,
    A7, B7, C7, D7, E7, F7, G7, H7,
    A8, B8, C8, D8, E8, F8, G8, H8,
    NO_SQ = -1,
};
// clang-format on
} // namespace Squares

namespace PieceScores {
enum Scores : int16_t {
    Pawn = 100,
    Knight = 300,
    Bishop = 300,
    Rook = 500,
    Queen = 900,
};
}