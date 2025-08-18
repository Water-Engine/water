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

class Piece {
  private:
    PieceType m_Type;
    PieceColor m_Color;

  private:
    static inline Piece from_char(char c);
    static inline Piece from_int(int value);

  public:
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

    inline int value() { return static_cast<int>(*this); };
    inline const PieceType type() const { return m_Type; };
    inline const PieceColor color() const { return m_Color; };

    operator char() {
        char raw;
        switch (m_Type) {
        case PieceType::Rook:
            raw = 'r';
            break;
        case PieceType::Knight:
            raw = 'n';
            break;
        case PieceType::Bishop:
            raw = 'b';
            break;
        case PieceType::Queen:
            raw = 'q';
            break;
        case PieceType::King:
            raw = 'k';
            break;
        case PieceType::Pawn:
            raw = 'p';
            break;
        default:
            raw = (char)0;
            break;
        }

        return (m_Color == PieceColor::White) ? std::toupper(raw) : raw;
    }

    operator int() { return static_cast<int>(m_Type) | static_cast<int>(m_Color); }
};
