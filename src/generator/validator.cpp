#include <pch.hpp>

#include "game/board.hpp"
#include "game/coord.hpp"
#include "game/piece.hpp"

#include "generator/king.hpp"
#include "generator/knight.hpp"
#include "generator/pawn.hpp"
#include "generator/sliders.hpp"

bool Board::move_leaves_self_checked(Coord start_coord, Coord target_coord, Piece piece_start,
                                     Piece piece_target) {
    // Only two cases need to be considered, either the king moves, or another piece moves
    if (piece_start.is_king()) {
        // We just need the full opponent attack mask and to check its value at target_coord
        return is_square_attacked(target_coord.square_idx(), piece_start.color());
    } else {
        // Here, the piece needs to be 'moved', just clear the start_coord bit temporary, check rays
        // with current king, and reset the cleared bit
        m_AllPieceBB.toggle_bit(start_coord.square_idx());
        bool captured = false;
        if (!piece_target.is_none()) {
            m_AllPieceBB.toggle_bit(target_coord.square_idx());
            captured = true;
        }

        bool result = king_in_check(piece_start.color());

        m_AllPieceBB.toggle_bit(start_coord.square_idx());
        if (captured) {
            m_AllPieceBB.toggle_bit(target_coord.square_idx());
        }

        return result;
    }
}

bool Board::can_capture_ep(bool is_white) {
    int ep_square = m_State.get_ep_square();
    if (ep_square == -1) {
        return false;
    }

    int rank = Coord::rank_from_square(ep_square);
    int file = Coord::file_from_square(ep_square);

    if (is_white) {
        if (rank != 5) {
            return false;
        }

        // check left pawn
        if (file > 0) {
            // one down-left
            int from = ep_square - 9;
            if (m_PawnBB.contains_square(from) && piece_at(from).is_white()) {
                return true;
            }
        }
        // check right pawn
        if (file < 7) {
            // one down-right
            int from = ep_square - 7;
            if (m_PawnBB.contains_square(from) && piece_at(from).is_white()) {
                return true;
            }
        }
    } else {
        if (rank != 2) {
            return false;
        }

        // check left pawn
        if (file > 0) {
            // one up-left
            int from = ep_square + 7;
            if (m_PawnBB.contains_square(from) && piece_at(from).is_black()) {
                return true;
            }
        }
        // check right pawn
        if (file < 7) {
            // one up-right
            int from = ep_square + 9;
            if (m_PawnBB.contains_square(from) && piece_at(from).is_black()) {
                return true;
            }
        }
    }

    return false;
}

Option<ValidatedMove> Board::is_legal_move(const Move& move, bool deep_verify) {
    Coord target_coord(move.target_square());
    Coord start_coord(move.start_square());
    Piece piece_start = piece_at(start_coord.square_idx());
    Piece piece_target = piece_at(target_coord.square_idx());
    int flag = move.flag();

    if (piece_start.is_none() || start_coord == target_coord) {
        return Option<ValidatedMove>();
    } else if (!start_coord.valid_square_idx() || !target_coord.valid_square_idx()) {
        return Option<ValidatedMove>();
    } else if (piece_start.color() != (m_WhiteToMove ? PieceColor::White : PieceColor::Black)) {
        return Option<ValidatedMove>();
    }

    if (move_leaves_self_checked(start_coord, target_coord, piece_start, piece_target)) {
        return Option<ValidatedMove>();
    }

    return Option<ValidatedMove>(
        ValidatedMove{start_coord, target_coord, piece_start, piece_target, flag});
}

Bitboard Board::pawn_attack_rays(PieceColor attacker_color) const {
    bool is_piece_white = attacker_color == PieceColor::White;
    Bitboard color_bb = is_piece_white ? m_WhiteBB : m_BlackBB;
    Bitboard to_ray_cast = m_PawnBB & color_bb;

    Bitboard attacks = 0ULL;
    while (to_ray_cast) {
        int index = to_ray_cast.pop_lsb();
        if (is_piece_white) {
            attacks |= Pawn::attacked_squares<PieceColor::White>(index, m_AllPieceBB);
        } else {
            attacks |= Pawn::attacked_squares<PieceColor::Black>(index, m_AllPieceBB);
        }
    }
    return attacks;
}

template <PrecomputedValidator Validator>
Bitboard Board::non_pawn_attack_rays(PieceColor attacker_color) const {
    bool is_piece_white = attacker_color == PieceColor::White;
    Bitboard color_bb = is_piece_white ? m_WhiteBB : m_BlackBB;
    Bitboard to_ray_cast;
    switch (Validator::as_piece_type()) {
    case PieceType::Rook:
        to_ray_cast = m_AllPieceBB & m_RookBB & color_bb;
        break;
    case PieceType::Knight:
        to_ray_cast = m_AllPieceBB & m_KnightBB & color_bb;
        break;
    case PieceType::Bishop:
        to_ray_cast = m_AllPieceBB & m_BishopBB & color_bb;
        break;
    case PieceType::Queen:
        to_ray_cast = m_AllPieceBB & m_QueenBB & color_bb;
        break;
    case PieceType::King:
        to_ray_cast = m_AllPieceBB & m_KingBB & color_bb;
        break;
    case PieceType::Pawn:
        to_ray_cast = m_AllPieceBB & m_PawnBB & color_bb;
        break;
    default:
        return Bitboard(0);
    }

    Bitboard attacks = 0ULL;
    while (to_ray_cast) {
        int index = to_ray_cast.pop_lsb();
        attacks |= Validator::attacked_squares(index, m_AllPieceBB);
    }
    return attacks;
}

Bitboard Board::calculate_attack_rays(PieceColor attacker_color) const {
    Bitboard attacks = 0ULL;

    attacks |= non_pawn_attack_rays<Rook>(attacker_color);
    attacks |= non_pawn_attack_rays<Knight>(attacker_color);
    attacks |= non_pawn_attack_rays<Bishop>(attacker_color);
    attacks |= non_pawn_attack_rays<Queen>(attacker_color);
    attacks |= non_pawn_attack_rays<King>(attacker_color);
    attacks |= pawn_attack_rays(attacker_color);

    return attacks;
}

bool Board::is_square_attacked(int square_idx, PieceColor occupied_color) const {
    auto attacked = calculate_attack_rays(opposite_color(occupied_color));
    return attacked.contains_square(square_idx);
}

bool Board::king_in_check(PieceColor king_color) const {
    // There should only ever be a single king per player, so we will naievly jus pop the lsb from a
    // copy
    Bitboard friendly_king = m_KingBB & (king_color == PieceColor::White ? m_WhiteBB : m_BlackBB);
    int friendly_king_square = friendly_king.pop_lsb();
    return is_square_attacked(friendly_king_square, king_color);
}