#include <pch.hpp>

#include "generator/validator.hpp"

#include "game/board.hpp"

Validator::Validator(Ref<Board> board) : m_Board(board) {
    Bitboard all_pieces = board->m_AllPieceBB;
    if (board->is_white_to_move()) {
        m_FriendlyPieces = board->m_WhiteBB & all_pieces;
        m_EnemyPieces = board->m_BlackBB & all_pieces;
    } else {
        m_FriendlyPieces = board->m_BlackBB & all_pieces;
        m_EnemyPieces = board->m_WhiteBB & all_pieces;
    }
}