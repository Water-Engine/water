#include <pch.hpp>

#include "evaluation/pst.hpp"

PSTManager::PSTManager() {
    m_Tables[Piece(Piece::white_rook()).index()] = WhiteRookTable;
    m_Tables[Piece(Piece::white_knight()).index()] = WhiteKnightTable;
    m_Tables[Piece(Piece::white_bishop()).index()] = WhiteBishopTable;
    m_Tables[Piece(Piece::white_queen()).index()] = WhiteQueenTable;
    m_Tables[Piece(Piece::white_king()).index()] = WhiteKingTable;
    m_Tables[Piece(Piece::white_pawn()).index()] = WhitePawnTable;

    m_Tables[Piece(Piece::black_rook()).index()] = BlackRookTable;
    m_Tables[Piece(Piece::black_knight()).index()] = BlackKnightTable;
    m_Tables[Piece(Piece::black_bishop()).index()] = BlackBishopTable;
    m_Tables[Piece(Piece::black_queen()).index()] = BlackQueenTable;
    m_Tables[Piece(Piece::black_king()).index()] = BlackKingTable;
    m_Tables[Piece(Piece::black_pawn()).index()] = BlackPawnTable;
}

int PSTManager::get_value_unchecked(const PST& table, PieceColor piece_color, int square,
                                    Phase phase) {
    int square_idx = square;
    if (piece_color == PieceColor::White) {
        int file = Coord::file_from_square(square_idx);
        int rank = 7 - Coord::rank_from_square(square_idx);
        square_idx = Coord::square_idx_unchecked(file, rank);
    }

    return table.phase(phase)[square_idx];
}

int PSTManager::get_value(const PST& table, PieceColor piece_color, int square, Phase phase) {
    if (!Coord::valid_square_idx(square)) {
        return 0;
    }

    return get_value_unchecked(table, piece_color, square, phase);
}

int PSTManager::get_value_tapered_unchecked(const Piece& piece, int square,
                                            float endgame_transition) const {
    const auto& tbl = m_Tables[piece.index()];
    int early = tbl.EarlyGame[square];
    int late = tbl.LateGame[square];
    return static_cast<int>(early * (1.0f - endgame_transition) + late * endgame_transition);
}
