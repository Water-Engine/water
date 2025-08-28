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
        return Piece(PieceType::Rook, PieceColor::White);
    case white_knight():
        return Piece(PieceType::Knight, PieceColor::White);
    case white_bishop():
        return Piece(PieceType::Bishop, PieceColor::White);
    case white_queen():
        return Piece(PieceType::Queen, PieceColor::White);
    case white_king():
        return Piece(PieceType::King, PieceColor::White);
    case white_pawn():
        return Piece(PieceType::Pawn, PieceColor::White);

    case black_rook():
        return Piece(PieceType::Rook, PieceColor::Black);
    case black_knight():
        return Piece(PieceType::Knight, PieceColor::Black);
    case black_bishop():
        return Piece(PieceType::Bishop, PieceColor::Black);
    case black_queen():
        return Piece(PieceType::Queen, PieceColor::Black);
    case black_king():
        return Piece(PieceType::King, PieceColor::Black);
    case black_pawn():
        return Piece(PieceType::Pawn, PieceColor::Black);

    default:
        return none();
    }
}

Piece::Piece(char c) {
    Piece p = from_char(c);
    m_Color = p.m_Color;
    m_Type = p.m_Type;
}

int Piece::score() const {
    switch (type()) {
    case PieceType::Pawn:
        return PieceScores::Pawn;
    case PieceType::Knight:
        return PieceScores::Knight;
    case PieceType::Bishop:
        return PieceScores::Bishop;
    case PieceType::Rook:
        return PieceScores::Rook;
    case PieceType::Queen:
        return PieceScores::Queen;
    default:
        return 0;
    }
}

char Piece::symbol() const {
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
        raw = ' ';
        break;
    }

    return (m_Color == PieceColor::White) ? std::toupper(raw) : raw;
}