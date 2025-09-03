#include <pch.hpp>

#include "evaluation/pst.hpp"

PSTManager::PSTManager() {
    m_Tables[Pieces::WHITE_ROOK_IDX] = WhiteRookTable;
    m_Tables[Pieces::WHITE_KNIGHT_IDX] = WhiteKnightTable;
    m_Tables[Pieces::WHITE_BISHOP_IDX] = WhiteBishopTable;
    m_Tables[Pieces::WHITE_QUEEN_IDX] = WhiteQueenTable;
    m_Tables[Pieces::WHITE_KING_IDX] = WhiteKingTable;
    m_Tables[Pieces::WHITE_PAWN_IDX] = WhitePawnTable;

    m_Tables[Pieces::BLACK_ROOK_IDX] = BlackRookTable;
    m_Tables[Pieces::BLACK_KNIGHT_IDX] = BlackKnightTable;
    m_Tables[Pieces::BLACK_BISHOP_IDX] = BlackBishopTable;
    m_Tables[Pieces::BLACK_QUEEN_IDX] = BlackQueenTable;
    m_Tables[Pieces::BLACK_KING_IDX] = BlackKingTable;
    m_Tables[Pieces::BLACK_PAWN_IDX] = BlackPawnTable;
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
