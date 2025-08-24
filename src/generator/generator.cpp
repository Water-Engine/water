#include <pch.hpp>

#include "generator/generator.hpp"
#include "generator/king.hpp"
#include "generator/knight.hpp"
#include "generator/sliders.hpp"

#include "game/board.hpp"

void Generator::generate_knight_moves(Bitboard& relevant_knight_bb, std::vector<Move>& out) {
    while (relevant_knight_bb != 0) {
        int knight_idx = relevant_knight_bb.pop_lsb();
        Bitboard attacked = Knight::attacked_squares(knight_idx);
        append_attacked(knight_idx, attacked, out);
    }
}

void Generator::generate_bishop_moves(Bitboard& relevant_bishop_bb, const Bitboard& occupancy, std::vector<Move>& out) {
    while (relevant_bishop_bb != 0) {
        int bishop_idx = relevant_bishop_bb.pop_lsb();
        Bitboard attacked = Bishop::attacked_squares(bishop_idx, occupancy);
        append_attacked(bishop_idx, attacked, out);
    }
}

void Generator::generate_rook_moves(Bitboard& relevant_rook_bb, const Bitboard& occupancy, std::vector<Move>& out) {
    while (relevant_rook_bb != 0) {
        int rook_idx = relevant_rook_bb.pop_lsb();
        Bitboard attacked = Rook::attacked_squares(rook_idx, occupancy);
        append_attacked(rook_idx, attacked, out);
    }
}

void Generator::generate_queen_moves(Bitboard& relevant_queen_bb, const Bitboard& occupancy, std::vector<Move>& out) {
    while (relevant_queen_bb != 0) {
        int queen_idx = relevant_queen_bb.pop_lsb();
        Bitboard attacked = Queen::attacked_squares(queen_idx, occupancy);
        append_attacked(queen_idx, attacked, out);
    }
}

void Generator::generate_king_moves(Bitboard& relevant_king_bb, std::vector<Move>& out) {
    while (relevant_king_bb != 0) {
        int king_idx = relevant_king_bb.pop_lsb();
        Bitboard attacked = King::attacked_squares(king_idx);
        append_attacked(king_idx, attacked, out);
    }
}
