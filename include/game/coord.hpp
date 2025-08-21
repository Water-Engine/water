#pragma once

class Coord {
  private:
    int m_FileIdx;
    int m_RankIdx;

  private:
    int square_idx_unchecked() const { return m_RankIdx * 8 + m_FileIdx; }

  public:
    Coord() : m_FileIdx(-1), m_RankIdx(-1) {}
    Coord(int file_idx, int rank_idx) : m_FileIdx(file_idx), m_RankIdx(rank_idx) {}

    Coord(const std::string& square_string);
    Coord(int square) : m_FileIdx(file_from_square(square)), m_RankIdx(rank_from_square(square)) {}

    int file_idx() const { return m_FileIdx; }
    int rank_idx() const { return m_RankIdx; }
    int square_idx() const { return valid_square_idx() ? square_idx_unchecked() : -1; }

    static int file_from_square(int square_idx) { return square_idx & 0b000111; }
    static int rank_from_square(int square_idx) { return square_idx >> 3; }

    bool is_light_square() const { return (m_FileIdx + m_RankIdx) % 2 != 0; }

    bool valid_square_idx() const;
    static bool valid_square_idx(int square_idx);

    std::string as_str() const;
    static std::string as_str(int square_idx);

    friend bool operator==(const Coord& a, const Coord& b) {
        return a.square_idx_unchecked() == b.square_idx_unchecked();
    }

    operator int() const { return square_idx(); }
};