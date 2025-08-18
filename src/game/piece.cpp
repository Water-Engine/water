#include <pch.hpp>

#include "game/piece.hpp"

Piece::Piece(int value) {
    Piece p = from_int(value);
    m_Type = p.m_Type;
    m_Color = p.m_Color;
}

inline Piece Piece::from_char(char c) {
    switch (c) {
    case 'R':
        return white_rook();
    case 'N':
        return white_knight();
    case 'B':
        return white_bishop();
    case 'Q':
        return white_queen();
    case 'K':
        return white_king();
    case 'P':
        return white_pawn();

    case 'r':
        return black_rook();
    case 'n':
        return black_knight();
    case 'b':
        return black_bishop();
    case 'q':
        return black_queen();
    case 'k':
        return black_king();
    case 'p':
        return black_pawn();

    default:
        return none();
    }
}

inline Piece Piece::from_int(int value) {
    switch (value) {
    case white_rook():
        return Piece(Type::Rook, Color::White);
    case white_knight():
        return Piece(Type::Knight, Color::White);
    case white_bishop():
        return Piece(Type::Bishop, Color::White);
    case white_queen():
        return Piece(Type::Queen, Color::White);
    case white_king():
        return Piece(Type::King, Color::White);
    case white_pawn():
        return Piece(Type::Pawn, Color::White);

    case black_rook():
        return Piece(Type::Rook, Color::Black);
    case black_knight():
        return Piece(Type::Knight, Color::Black);
    case black_bishop():
        return Piece(Type::Bishop, Color::Black);
    case black_queen():
        return Piece(Type::Queen, Color::Black);
    case black_king():
        return Piece(Type::King, Color::Black);
    case black_pawn():
        return Piece(Type::Pawn, Color::Black);

    default:
        return none();
    }
}

Piece::Piece(char c) {
    Piece p = from_char(c);
    m_Color = p.m_Color;
    m_Type = p.m_Type; 
}