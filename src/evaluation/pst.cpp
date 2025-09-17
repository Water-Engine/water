#include <pch.hpp>

#include "evaluation/pst.hpp"

using namespace chess;

PSTManager::PSTManager() {
    m_Tables[static_cast<int>(Piece::underlying::WHITEROOK)] = WhiteRookTable;
    m_Tables[static_cast<int>(Piece::underlying::WHITEKNIGHT)] = WhiteKnightTable;
    m_Tables[static_cast<int>(Piece::underlying::WHITEBISHOP)] = WhiteBishopTable;
    m_Tables[static_cast<int>(Piece::underlying::WHITEQUEEN)] = WhiteQueenTable;
    m_Tables[static_cast<int>(Piece::underlying::WHITEKING)] = WhiteKingTable;
    m_Tables[static_cast<int>(Piece::underlying::WHITEPAWN)] = WhitePawnTable;

    m_Tables[static_cast<int>(Piece::underlying::BLACKROOK)] = BlackRookTable;
    m_Tables[static_cast<int>(Piece::underlying::BLACKKNIGHT)] = BlackKnightTable;
    m_Tables[static_cast<int>(Piece::underlying::BLACKBISHOP)] = BlackBishopTable;
    m_Tables[static_cast<int>(Piece::underlying::BLACKQUEEN)] = BlackQueenTable;
    m_Tables[static_cast<int>(Piece::underlying::BLACKKING)] = BlackKingTable;
    m_Tables[static_cast<int>(Piece::underlying::BLACKPAWN)] = BlackPawnTable;
}

int PSTManager::get_value_unchecked(const PST& table, Color piece_color, int square, Phase phase) {
    int square_idx = square;
    if (piece_color == Color::WHITE) {
        int file = Coord::file_from_square(square_idx);
        int rank = 7 - Coord::rank_from_square(square_idx);
        square_idx = Coord::square_idx_unchecked(file, rank);
    }

    return table.phase(phase)[square_idx];
}

int PSTManager::get_value(const PST& table, Color piece_color, int square, Phase phase) {
    if (!Coord::valid_square_idx(square)) {
        return 0;
    }

    return get_value_unchecked(table, piece_color, square, phase);
}

int PSTManager::get_value_tapered_unchecked(const Piece& piece, int square,
                                            float endgame_transition) const {
    const auto& tbl = m_Tables[piece];
    int early = tbl.EarlyGame[square];
    int late = tbl.LateGame[square];
    return static_cast<int>(early * (1.0f - endgame_transition) + late * endgame_transition);
}
