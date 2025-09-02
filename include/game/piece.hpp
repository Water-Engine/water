#pragma once

enum class PieceType : uint8_t {
    None = 0,
    Rook = 1,
    Knight = 2,
    Bishop = 3,
    Queen = 4,
    King = 5,
    Pawn = 6,
};

enum class PieceColor : uint8_t {
    White = 0,
    Black = 8,
};

constexpr inline PieceColor opposite_color(PieceColor color) {
    return (color == PieceColor::White) ? PieceColor::Black : PieceColor::White;
}

constexpr inline int color_as_idx(PieceColor color) { return (color == PieceColor::White) ? 0 : 1; }

class Piece {
  private:
    PieceType m_Type;
    PieceColor m_Color;

  private:
    static inline Piece from_char(char c);
    static inline Piece from_int(int value);

  public:
    Piece() = default;
    Piece(PieceType piece_type, PieceColor piece_color)
        : m_Type(piece_type), m_Color(piece_color) {}
    Piece(int value);
    Piece(char c);

    constexpr static inline int none() { return static_cast<int>(PieceType::None); }

    constexpr static inline int white_rook() {
        return static_cast<int>(PieceColor::White) | static_cast<int>(PieceType::Rook);
    }
    constexpr static inline int white_knight() {
        return static_cast<int>(PieceColor::White) | static_cast<int>(PieceType::Knight);
    }
    constexpr static inline int white_bishop() {
        return static_cast<int>(PieceColor::White) | static_cast<int>(PieceType::Bishop);
    }
    constexpr static inline int white_queen() {
        return static_cast<int>(PieceColor::White) | static_cast<int>(PieceType::Queen);
    }
    constexpr static inline int white_king() {
        return static_cast<int>(PieceColor::White) | static_cast<int>(PieceType::King);
    }
    constexpr static inline int white_pawn() {
        return static_cast<int>(PieceColor::White) | static_cast<int>(PieceType::Pawn);
    }

    constexpr static inline int black_rook() {
        return static_cast<int>(PieceColor::Black) | static_cast<int>(PieceType::Rook);
    }
    constexpr static inline int black_knight() {
        return static_cast<int>(PieceColor::Black) | static_cast<int>(PieceType::Knight);
    }
    constexpr static inline int black_bishop() {
        return static_cast<int>(PieceColor::Black) | static_cast<int>(PieceType::Bishop);
    }
    constexpr static inline int black_queen() {
        return static_cast<int>(PieceColor::Black) | static_cast<int>(PieceType::Queen);
    }
    constexpr static inline int black_king() {
        return static_cast<int>(PieceColor::Black) | static_cast<int>(PieceType::King);
    }
    constexpr static inline int black_pawn() {
        return static_cast<int>(PieceColor::Black) | static_cast<int>(PieceType::Pawn);
    }

    inline void clear() {
        m_Type = PieceType::None;
        m_Color = PieceColor::White;
    }

    inline int value() const { return static_cast<int>(*this); }
    int score() const;
    inline PieceType type() const { return m_Type; };
    inline PieceColor color() const { return m_Color; };
    char symbol() const;

    inline bool is_white() const { return m_Color == PieceColor::White; }
    inline bool is_black() const { return m_Color == PieceColor::Black; }
    inline bool is_rook() const { return m_Type == PieceType::Rook; }
    inline bool is_knight() const { return m_Type == PieceType::Knight; }
    inline bool is_bishop() const { return m_Type == PieceType::Bishop; }
    inline bool is_queen() const { return m_Type == PieceType::Queen; }
    inline bool is_king() const { return m_Type == PieceType::King; }
    inline bool is_pawn() const { return m_Type == PieceType::Pawn; }
    inline bool is_none() const { return value() == 0; }

    /// Note: Valid (non-null) pieces are guanteed to be bounded [0, 11]
    inline int index() const {
        if (is_none()) {
            return -1;
        }

        int type_idx = static_cast<int>(type()) - 1;
        if (is_white()) {
            return type_idx;
        } else {
            return type_idx + 6;
        }
    }

    friend bool operator==(const Piece& a, const Piece& b) {
        bool types_match = a.m_Type == b.m_Type;
        bool colors_match = a.m_Color == b.m_Color;
        return types_match && colors_match;
    }

    operator char() const { return symbol(); }

    operator int() const { return static_cast<int>(m_Type) | static_cast<int>(m_Color); }
};

namespace PieceScores {
enum Scores {
    Pawn = 100,
    Knight = 300,
    Bishop = 300,
    Rook = 500,
    Queen = 900,
};
}