#pragma once

#include "bitboard/bitboard.hpp"

#include "game/board.hpp"
#include "game/move.hpp"
#include "game/piece.hpp"

#include "generator/pawn.hpp"

constexpr size_t MAX_MOVES = 218;

class Generator {
  private:
    template <PieceColor Color>
    static void generate_pawn_moves(Bitboard& relevant_pawn_bb, std::vector<Move>& out) {
        while (relevant_pawn_bb != 0) {
            int pawn_idx = relevant_pawn_bb.pop_lsb();
            Bitboard attacked = Pawn::all_available_squares<Color>(pawn_idx);
            append_attacked(pawn_idx, attacked, out);
        }
    }

    static void generate_knight_moves(Bitboard& relevant_knight_bb, std::vector<Move>& out);
    static void generate_bishop_moves(Bitboard& relevant_bishop_bb, const Bitboard& occupancy,
                                      std::vector<Move>& out);
    static void generate_rook_moves(Bitboard& relevant_rook_bb, const Bitboard& occupancy,
                                    std::vector<Move>& out);
    static void generate_queen_moves(Bitboard& relevant_queen_bb, const Bitboard& occupancy,
                                     std::vector<Move>& out);
    static void generate_king_moves(Bitboard& relevant_king_bb, std::vector<Move>& out);

    inline static void append_attacked(int start_idx, Bitboard& attacked, std::vector<Move>& out) {
        while (attacked != 0) {
            int attacked_idx = attacked.pop_lsb();
            Move attacking_move(start_idx, attacked_idx);
            out.push_back(attacking_move);
        }
    }

  public:
    Generator() = delete;
    Generator(const Generator&) = delete;

    template <PieceColor Color> static std::vector<Move> generate(Board& board) {
        bool is_white = Color == PieceColor::White;
        auto& color_bb = is_white ? board.m_WhiteBB : board.m_BlackBB;
        auto relevant_pawns = board.m_PawnBB & color_bb;
        auto relevant_knights = board.m_KnightBB & color_bb;
        auto relevant_bishops = board.m_BishopBB & color_bb;
        auto relevant_rooks = board.m_RookBB & color_bb;
        auto relevant_queens = board.m_QueenBB & color_bb;
        auto relevant_kings = board.m_KingBB & color_bb;

        std::vector<Move> all_moves;
        all_moves.reserve(MAX_MOVES);

        generate_pawn_moves<Color>(relevant_pawns, all_moves);
        generate_knight_moves(relevant_knights, all_moves);
        generate_bishop_moves(relevant_bishops, board.m_AllPieceBB, all_moves);
        generate_rook_moves(relevant_rooks, board.m_AllPieceBB, all_moves);
        generate_queen_moves(relevant_queens, board.m_AllPieceBB, all_moves);
        generate_king_moves(relevant_kings, all_moves);

        if (all_moves.size() == 0) {
            return all_moves;
        }

        all_moves.erase(std::remove_if(all_moves.begin(), all_moves.end(),
                                       [&](const Move& move) {
                                           return board.is_legal_move(move, true).is_some();
                                       }),
                        all_moves.end());

        return all_moves;
    }
};
