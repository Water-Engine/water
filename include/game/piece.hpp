#pragma once

class Piece {
  private:
    enum class Type : uint8_t {
        None = 0,
        Rook = 1,
        Knight = 2,
        Bishop = 3,
        Queen = 4,
        King = 5,
        Pawn = 6,
    };

    enum class Color : uint8_t {
        White = 0,
        Black = 8,
    };

  private:
    Type m_Type;
    Color m_Color;

  private:
    static inline Piece from_char(char c);
    static inline Piece from_int(int value);

  public:
    Piece(Type piece_type, Color piece_color) : m_Type(piece_type), m_Color(piece_color) {}
    Piece(int value);
    Piece(char c);

    constexpr static inline int none() { return static_cast<int>(Type::None); }

    constexpr static inline int white_rook() {
        return static_cast<int>(Color::White) | static_cast<int>(Type::Rook);
    }
    constexpr static inline int white_knight() {
        return static_cast<int>(Color::White) | static_cast<int>(Type::Knight);
    }
    constexpr static inline int white_bishop() {
        return static_cast<int>(Color::White) | static_cast<int>(Type::Bishop);
    }
    constexpr static inline int white_queen() {
        return static_cast<int>(Color::White) | static_cast<int>(Type::Queen);
    }
    constexpr static inline int white_king() {
        return static_cast<int>(Color::White) | static_cast<int>(Type::King);
    }
    constexpr static inline int white_pawn() {
        return static_cast<int>(Color::White) | static_cast<int>(Type::Pawn);
    }

    constexpr static inline int black_rook() {
        return static_cast<int>(Color::Black) | static_cast<int>(Type::Rook);
    }
    constexpr static inline int black_knight() {
        return static_cast<int>(Color::Black) | static_cast<int>(Type::Knight);
    }
    constexpr static inline int black_bishop() {
        return static_cast<int>(Color::Black) | static_cast<int>(Type::Bishop);
    }
    constexpr static inline int black_queen() {
        return static_cast<int>(Color::Black) | static_cast<int>(Type::Queen);
    }
    constexpr static inline int black_king() {
        return static_cast<int>(Color::Black) | static_cast<int>(Type::King);
    }
    constexpr static inline int black_pawn() {
        return static_cast<int>(Color::Black) | static_cast<int>(Type::Pawn);
    }

    inline int value() { return static_cast<int>(*this); };

    operator char() {
        char raw;
        switch (m_Type) {
        case Type::Rook:
            raw = 'r';
            break;
        case Type::Knight:
            raw = 'n';
            break;
        case Type::Bishop:
            raw = 'b';
            break;
        case Type::Queen:
            raw = 'q';
            break;
        case Type::King:
            raw = 'k';
            break;
        case Type::Pawn:
            raw = 'p';
            break;
        default:
            raw = (char)0;
            break;
        }

        return (m_Color == Color::White) ? std::toupper(raw) : raw;
    }

    operator int() { return static_cast<int>(m_Type) | static_cast<int>(m_Color); }
};
