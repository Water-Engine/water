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

inline Option<Piece> is_capture(const Move& move, Ref<Board> board) {
    auto target_piece = board->at(move.to().index());

    if (target_piece.type() != PieceType::NONE && target_piece.color() != board->sideToMove()) {
        return Option<Piece>(target_piece);
    }

    if (move.typeOf() == Move::ENPASSANT) {
        int offset = (board->sideToMove() == Color::WHITE) ? -8 : 8;
        auto ep_piece = board->at(move.to().index() + offset);
        return Option<Piece>(ep_piece);
    }

    return Option<Piece>();
}

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

inline int16_t score_of_piece(PieceType type) {
    switch (type.internal()) {
    case PieceType::PAWN:
        return PieceScores::Pawn;
    case PieceType::KNIGHT:
        return PieceScores::Knight;
    case PieceType::BISHOP:
        return PieceScores::Bishop;
    case PieceType::ROOK:
        return PieceScores::Rook;
    case PieceType::QUEEN:
        return PieceScores::Queen;
    default:
        return 0;
    }
}

inline Bitboard pawn_attacks(Ref<Board> board, Color color) {
    auto to_ray_cast = board->us(color) & board->pieces(PieceType::PAWN);
    Bitboard attacks(0);

    while (to_ray_cast) {
        int index = to_ray_cast.pop();
        attacks |= attacks::pawn(color, index);
    }
    return attacks;
}

inline Bitboard non_pawn_attacks(Ref<Board> board, Color color) {
    auto occupied = board->us(color) | board->us(~color);
    auto make_attacks = [&](PieceType type) -> Bitboard {
        auto to_ray_cast = board->us(color) & board->pieces(type);
        Bitboard attacks(0);

        if (type == PieceType::KING || type == PieceType::KNIGHT) {
            auto attack_maker = (type == PieceType::KING) ? attacks::king
                                : (type == PieceType::KNIGHT)
                                    ? attacks::knight
                                    : []([[maybe_unused]] Square sq) { return Bitboard(0); };
            while (to_ray_cast) {
                int index = to_ray_cast.pop();
                attacks |= attack_maker(index);
            }
            return attacks;
        }

        auto attack_maker = (type == PieceType::BISHOP) ? attacks::bishop
                            : (type == PieceType::ROOK) ? attacks::rook
                            : (type == PieceType::QUEEN)
                                ? attacks::queen
                                : []([[maybe_unused]] Square sq,
                                     [[maybe_unused]] Bitboard occupied) { return Bitboard(0); };
        while (to_ray_cast) {
            int index = to_ray_cast.pop();
            attacks |= attack_maker(index, occupied);
        }
        return attacks;
    };

    Bitboard attacks(0);
    attacks |= make_attacks(PieceType::KNIGHT);
    attacks |= make_attacks(PieceType::BISHOP);
    attacks |= make_attacks(PieceType::ROOK);
    attacks |= make_attacks(PieceType::QUEEN);
    attacks |= make_attacks(PieceType::KING);
    return attacks;
}

namespace std {
template <> struct hash<Move> {
    std::size_t operator()(const Move& m) const {
        return std::hash<int>()(m.from().index()) ^ (std::hash<int>()(m.to().index()) << 1);
    }
};
} // namespace std

/// Generates a movelist containing captures, checks, and promotions
inline Movelist tactical_moves(Ref<Board> board) {
    // TODO: More efficient generation
    PROFILE_FUNCTION();
    // Generate all captures
    Movelist capture_moves;
    movegen::legalmoves<movegen::MoveGenType::CAPTURE>(capture_moves, *board);

    // Generate all promotions
    Movelist pawn_moves;
    movegen::legalmoves(pawn_moves, *board, PieceGenType::PAWN);
    Movelist promotion_moves;
    for (auto& move : pawn_moves) {
        if (move.typeOf() == Move::PROMOTION) {
            promotion_moves.add(move);
        }
    }

    // Generate all checks
    Movelist all_moves;
    movegen::legalmoves(all_moves, *board);
    Movelist check_moves;
    for (auto& move : all_moves) {
        if (board->givesCheck(move) != CheckType::NO_CHECK) {
            check_moves.add(move);
        }
    }

    // Combine all moves
    std::unordered_set<Move> seen_moves;
    seen_moves.reserve(all_moves.size());
    Movelist tactical;

    auto try_add_tacticals = [&](const Movelist& movelist) {
        for (auto& move : movelist) {
            if (seen_moves.emplace(move).second) {
                tactical.add(move);
            }
        }
    };

    try_add_tacticals(capture_moves);
    try_add_tacticals(promotion_moves);
    try_add_tacticals(check_moves);

    return tactical;
}

inline bool is_move_legal(Ref<Board> board, const Move& move) {
    Movelist legals;
    movegen::legalmoves(legals, *board);

    for (auto& legal : legals) {
        if (legal == move) {
            return true;
        }
    }

    return false;
}