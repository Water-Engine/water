#pragma once

#include "game/utils.hpp"

/* Precomputed pawn evaluation data containing:
 * - Pawn Shields - protective squares for pawns around a king
 * - Passed Pawn Masks - all squares that should be checked for a potential pp
 * - Pawn Support Masks - squares where friendly pawns can be to support another pawn (horizontally
 * adjacent and diagonally downwards relative to the side to move)
 */
class PawnMasks {
  private:
    std::array<chess::Bitboard, 64> m_WhiteShields;
    std::array<chess::Bitboard, 64> m_BlackShields;

    std::array<chess::Bitboard, 64> m_WhitePassedMasks;
    std::array<chess::Bitboard, 64> m_BlackPassedMasks;

    std::array<chess::Bitboard, 64> m_WhiteSupportMasks;
    std::array<chess::Bitboard, 64> m_BlackSupportMasks;

  private:
    PawnMasks();

    // Generators assume squares are valid
    void create_shields(int square);
    void create_passed(int square);
    void create_supports(int square);

  public:
    PawnMasks(const PawnMasks&) = delete;
    PawnMasks& operator=(const PawnMasks&) = delete;
    PawnMasks(PawnMasks&&) = delete;
    PawnMasks& operator=(PawnMasks&&) = delete;

    static PawnMasks& instance() {
        static PawnMasks s_instance;
        return s_instance;
    }

    inline chess::Bitboard get_shield_unchecked(chess::Color C, int king_square) const {
        if (C.internal() == chess::Color::WHITE) {
            return m_WhiteShields[king_square];
        } else {
            return m_BlackShields[king_square];
        }
    }

    inline chess::Bitboard get_shield(chess::Color C, int king_square) const {
        if (!Coord::valid_square_idx(king_square)) {
            return chess::Bitboard(0);
        }

        return get_shield_unchecked(C, king_square);
    }

    inline chess::Bitboard get_passed_unchecked(chess::Color C, int square) const {
        if (C.internal() == chess::Color::WHITE) {
            return m_WhitePassedMasks[square];
        } else {
            return m_BlackPassedMasks[square];
        }
    }

    inline chess::Bitboard get_passed(chess::Color C, int square) const {
        if (!Coord::valid_square_idx(square)) {
            return chess::Bitboard(0);
        }

        return get_passed_unchecked(C, square);
    }

    inline chess::Bitboard get_support_unchecked(chess::Color C, int square) const {
        if (C.internal() == chess::Color::WHITE) {
            return m_WhiteSupportMasks[square];
        } else {
            return m_BlackSupportMasks[square];
        }
    }

    inline chess::Bitboard get_support(chess::Color C, int square) const {
        if (!Coord::valid_square_idx(square)) {
            return chess::Bitboard(0);
        }

        return get_support_unchecked(C, square);
    }
};

/* File masks represented as Bitboards, containing:
 * - Masks for each file
 * - Masks for adjacent files for each file
 * - Triple file masks which are centered at the given file. Edge files are technically "double file
 * masks"
 */
class FileMasks {
  private:
    std::array<chess::Bitboard, 8> m_FileMasks;
    std::array<chess::Bitboard, 8> m_AdjacentFileMasks;
    std::array<chess::Bitboard, 8> m_TripleFileMasks;

  private:
    FileMasks();

  public:
    FileMasks(const FileMasks&) = delete;
    FileMasks& operator=(const FileMasks&) = delete;
    FileMasks(FileMasks&&) = delete;
    FileMasks& operator=(FileMasks&&) = delete;

    static FileMasks& instance() {
        static FileMasks s_instance;
        return s_instance;
    }

    inline chess::Bitboard get_file_unchecked(int file) const { return m_FileMasks[file]; }

    inline chess::Bitboard get_file(int file) const {
        if (!Coord::valid_square_idx(file))
            return chess::Bitboard(0);

        return get_file_unchecked(file);
    }

    inline chess::Bitboard get_adj_file_unchecked(int file) const {
        return m_AdjacentFileMasks[file];
    }

    inline chess::Bitboard get_adj_file(int file) const {
        if (!Coord::valid_square_idx(file))
            return chess::Bitboard(0);

        return get_adj_file_unchecked(file);
    }

    inline chess::Bitboard get_triple_file_unchecked(int file) const {
        return m_TripleFileMasks[file];
    }

    inline chess::Bitboard get_triple_file(int file) const {
        if (!Coord::valid_square_idx(file))
            return chess::Bitboard(0);

        return get_triple_file_unchecked(file);
    }
};

/* Various distances used in evaluation, containing:
 * - The manhattan distance between two squares (rook distance)
 * - the chebyshev distance between two squares (king distance)
 * - The center manhattan distance (king distance starting at {d4, d5, e4, e5})
 */
class Distance {
  private:
    std::array<std::array<int, 64>, 64> m_ManhattanDistance;
    std::array<std::array<int, 64>, 64> m_ChebyshevDistance;
    std::array<int, 64> m_CenterManhattanDistance;

  private:
    Distance();

  public:
    Distance(const Distance&) = delete;
    Distance& operator=(const Distance&) = delete;
    Distance(Distance&&) = delete;
    Distance& operator=(Distance&&) = delete;

    static Distance& instance() {
        static Distance s_instance;
        return s_instance;
    }

    inline int get_manhattan_unchecked(int sq1, int sq2) const {
        return m_ManhattanDistance[sq1][sq2];
    }

    inline int get_manhattan(int sq1, int sq2) const {
        if (!Coord::valid_square_idx(sq1) || !Coord::valid_square_idx(sq2))
            return 0;
        return get_manhattan_unchecked(sq1, sq2);
    }

    inline int get_king_unchecked(int sq1, int sq2) const { return m_ChebyshevDistance[sq1][sq2]; }

    inline int get_king(int sq1, int sq2) const {
        if (!Coord::valid_square_idx(sq1) || !Coord::valid_square_idx(sq2))
            return 0;
        return get_king_unchecked(sq1, sq2);
    }

    inline int get_center_manhattan_unchecked(int sq) const {
        return m_CenterManhattanDistance[sq];
    }

    inline int get_center_manhattan(int sq) const {
        if (!Coord::valid_square_idx(sq))
            return 0;
        return get_center_manhattan_unchecked(sq);
    }
};