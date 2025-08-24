#include <pch.hpp>

#include "game/board.hpp"
#include "game/coord.hpp"
#include "game/piece.hpp"

#include "generator/king.hpp"
#include "generator/knight.hpp"
#include "generator/pawn.hpp"
#include "generator/sliders.hpp"

bool Board::move_leaves_self_checked(Coord start_coord, Coord target_coord, int move_flag,
                                     Piece piece_start, Piece piece_target) {
    // Only two cases need to be considered, either the king moves, or another piece moves
    if (piece_start.is_king()) {
        // We just need the full opponent attack mask and to check its value at target_coord
        return is_square_attacked(target_coord.square_idx(), piece_start.color());
    } else if (move_flag == PAWN_CAPTURE_FLAG &&
               target_coord.square_idx() == m_State.get_ep_square()) {
        int captured_square = m_State.get_ep_square() + (piece_start.is_white() ? -8 : 8);
        m_AllPieceBB.toggle_bit(captured_square);
        bool result = king_in_check(piece_start.color());
        m_AllPieceBB.toggle_bit(captured_square);
        return result;
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

bool Board::can_capture_ep(bool is_white) const {
    int ep_square = m_State.get_ep_square();
    if (ep_square == -1) {
        return false;
    }

    int rank = Coord::rank_from_square(ep_square);
    int file = Coord::file_from_square(ep_square);

    int from_left = -1, from_right = -1;

    if (is_white) {
        if (rank != 5) {
            return false;
        }
        if (file > 0) {
            from_left = ep_square - 9;
        }
        if (file < 7) {
            from_right = ep_square - 7;
        }
    } else {
        if (rank != 2) {
            return false;
        }
        if (file > 0) {
            from_left = ep_square + 7;
        }
        if (file < 7) {
            from_right = ep_square + 9;
        }
    }

    Bitboard all_piece_bb = m_AllPieceBB;

    auto test_ep = [&](int from) -> bool {
        if (from == -1) {
            return false;
        }
        Piece p = piece_at(from);
        if ((is_white && !p.is_white()) || (!is_white && !p.is_black())) {
            return false;
        }

        // Temporarily remove both the moving pawn and the captured pawn
        int captured_square = ep_square + (is_white ? -8 : 8);
        all_piece_bb.toggle_bit(from);
        all_piece_bb.toggle_bit(captured_square);

        bool leaves_king_checked = king_in_check(p.color());

        // Restore the bits
        all_piece_bb.toggle_bit(from);
        all_piece_bb.toggle_bit(captured_square);

        return !leaves_king_checked;
    };

    return test_ep(from_left) || test_ep(from_right);
}

Option<ValidatedMove> Board::is_legal_move(const Move& move, bool deep_verify) {
    Coord target_coord(move.target_square());
    Coord start_coord(move.start_square());
    Piece piece_start = piece_at(start_coord.square_idx());
    Piece piece_target = piece_at(target_coord.square_idx());
    int move_flag = move.flag();

    if (piece_start.is_none() || start_coord == target_coord) {
        return Option<ValidatedMove>();
    } else if (!start_coord.valid_square_idx() || !target_coord.valid_square_idx()) {
        return Option<ValidatedMove>();
    } else if (piece_start.color() != (m_WhiteToMove ? PieceColor::White : PieceColor::Black)) {
        return Option<ValidatedMove>();
    }

    if (move_leaves_self_checked(start_coord, target_coord, move_flag, piece_start, piece_target)) {
        return Option<ValidatedMove>();
    }

    // Verify as in move maker, but do not actually apply the moves to the board or update state.
    // This section and its dispatched method calls are copied from their make_*_move counterparts
    if (deep_verify) {
        bool valid;
        switch (piece_start.type()) {
        case PieceType::Rook:
            valid = validate_basic_precomputed_move<Rook>(start_coord, target_coord, piece_start,
                                                          piece_target);
            break;
        case PieceType::Knight:
            valid = validate_basic_precomputed_move<Knight>(start_coord, target_coord, piece_start,
                                                            piece_target);
            break;
        case PieceType::Bishop:
            valid = validate_basic_precomputed_move<Bishop>(start_coord, target_coord, piece_start,
                                                            piece_target);
            break;
        case PieceType::Queen:
            valid = validate_basic_precomputed_move<Queen>(start_coord, target_coord, piece_start,
                                                           piece_target);
            break;
        case PieceType::King:
            valid =
                validate_king_move(start_coord, target_coord, move_flag, piece_start, piece_target);
            break;
        case PieceType::Pawn:
            valid =
                validate_pawn_move(start_coord, target_coord, move_flag, piece_start, piece_target);
            break;
        default:
            return Option<ValidatedMove>();
        }

        if (!valid) {
            return Option<ValidatedMove>();
        }
    }

    return Option<ValidatedMove>(
        ValidatedMove{start_coord, target_coord, piece_start, piece_target, move_flag});
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
    // There should only ever be a single king per player, so we will naively jus pop the lsb from a
    // copy
    Bitboard friendly_king = m_KingBB & (king_color == PieceColor::White ? m_WhiteBB : m_BlackBB);
    int friendly_king_square = friendly_king.pop_lsb();
    assert(friendly_king == 0);
    return is_square_attacked(friendly_king_square, king_color);
}

// ================ VALIDATORS FOR LEGALITY CHECKS ================
// Note: These are copied from board.cpp, with the actual movements being removed

bool Board::validate_king_move(Coord start_coord, Coord target_coord, int move_flag,
                               Piece piece_from, Piece piece_to) const {
    PROFILE_FUNCTION();
    if (move_flag != NO_FLAG && move_flag != CASTLE_FLAG) {
        return false;
    }

    Bitboard opponent_rays = opponent_attack_rays();
    if (move_flag == NO_FLAG) {
        if (!King::can_move_to(start_coord.square_idx(), target_coord.square_idx())) {
            return false;
        }

        if (piece_from.color() == piece_to.color() &&
            m_AllPieceBB.contains_square(target_coord.square_idx())) {
            return false;
        }

    } else if (move_flag == CASTLE_FLAG) {
        const int king_from = start_coord.square_idx();
        const int king_to = target_coord.square_idx();
        const bool king_side = (king_to > king_from);

        // 1. Castling rights must be valid
        if (piece_from.is_white()) {
            if (king_side) {
                if (!m_State.can_white_kingside()) {
                    return false;
                }
            } else {
                if (!m_State.can_white_queenside()) {
                    return false;
                }
            }
        } else {
            if (king_side) {
                if (!m_State.can_black_kingside()) {
                    return false;
                }
            } else {
                if (!m_State.can_black_queenside()) {
                    return false;
                }
            }
        }

        // 2. King cannot castle out of a check
        if (king_in_check(piece_from.color())) {
            return false;
        }

        // 3. A castling move cannot pass through attacked squares
        int king_path[2];
        king_path[0] = king_from + (king_side ? 1 : -1);
        king_path[1] = king_from + (king_side ? 2 : -2);
        for (int i = 0; i < 2; i++) {
            if (opponent_rays.contains_square(king_path[i])) {
                return false;
            }
        }

        // 4. All squares between rook and king must be empty
        int rook_clear_len = king_side ? 2 : 3;
        int rook_clear[3];
        if (king_side) {
            rook_clear[0] = king_from + 1;
            rook_clear[1] = king_from + 2;
        } else {
            rook_clear[0] = king_from - 1;
            rook_clear[1] = king_from - 2;
            rook_clear[2] = king_from - 3;
        }
        for (int i = 0; i < rook_clear_len; i++) {
            if (m_AllPieceBB.contains_square(rook_clear[i])) {
                return false;
            }
        }

        // Extra validation is needed since there is a second piece type moving
        int rook_from;
        if (piece_from.is_white()) {
            if (king_side) {
                rook_from = Square::H1;
            } else {
                rook_from = Square::A1;
            }
        } else {
            if (king_side) {
                rook_from = Square::H8;
            } else {
                rook_from = Square::A8;
            }
        }

        Piece rook_piece = m_StoredPieces[rook_from];
        if (!rook_piece.is_rook() || rook_piece.color() != piece_from.color()) {
            return false;
        }
    }

    return true;
}

bool Board::validate_pawn_move(Coord start_coord, Coord target_coord, int move_flag,
                               Piece piece_from, Piece piece_to) const {
    PROFILE_FUNCTION();
    if (piece_from.is_white() && !Pawn::can_move_to<PieceColor::White>(start_coord.square_idx(),
                                                                       target_coord.square_idx())) {
        return false;
    } else if (piece_from.is_black() && !Pawn::can_move_to<PieceColor::Black>(
                                            start_coord.square_idx(), target_coord.square_idx())) {
        return false;
    }

    // Pawns must promote if reaching last rank
    int target_rank = target_coord.rank_idx();
    if ((piece_from.is_white() && target_rank == 7 && !Move::is_promotion(move_flag)) ||
        (piece_from.is_black() && target_rank == 0 && !Move::is_promotion(move_flag))) {
        return false;
    }

    if (move_flag == NO_FLAG) {
        if (piece_from.color() == piece_to.color() &&
            m_AllPieceBB.contains_square(target_coord.square_idx())) {
            return false;
        }
    } else if (move_flag == PAWN_TWO_UP_FLAG) {
        if (piece_from.color() == piece_to.color() &&
            m_AllPieceBB.contains_square(target_coord.square_idx())) {
            return false;
        }

        int ep_square = start_coord.square_idx() + (piece_from.is_white() ? 8 : -8);
        if (m_AllPieceBB.contains_square(ep_square)) {
            return false;
        }

    } else if (move_flag == PAWN_CAPTURE_FLAG) {
        int old_ep_square = m_State.get_ep_square();

        // Handle ep side of moves
        if (old_ep_square == target_coord.square_idx()) {
            if (!can_capture_ep(piece_from.color() == PieceColor::White)) {
                return false;
            }
        } else {
            // Fallback to basic captures, diagonal moves must attack an enemy piece, but we know it
            // is a valid attack square due to passing can_move_to checks
            if (piece_from.color() == piece_to.color()) {
                return false;
            } else if ((int)piece_at(target_coord.square_idx()) == Piece::none()) {
                return false;
            }
        }
    } else if (Move::is_promotion(move_flag)) {
        // 1. Ensure the target square is a promotion rank
        int target_idx = target_coord.square_idx();
        bool valid_promotion_rank =
            (piece_from.is_white() && target_idx >= 56 && target_idx <= 63) ||
            (piece_from.is_black() && target_idx >= 0 && target_idx <= 7);
        if (!valid_promotion_rank) {
            return false;
        }

        // 2. Ensure capture rules are respected if it's a capture promotion
        if (piece_from.color() == piece_to.color() && m_AllPieceBB.contains_square(target_idx)) {
            return false;
        }

        // 3. Determine promotion piece
        Piece promotion_piece = Move::promotion_piece(move_flag, piece_from.color());
        if (promotion_piece.type() == PieceType::Pawn ||
            promotion_piece.type() == PieceType::King ||
            promotion_piece.type() == PieceType::None) {
            return false;
        }
    } else {
        return false;
    }

    return true;
}

template <PrecomputedValidator Validator>
bool Board::validate_basic_precomputed_move(Coord start_coord, Coord target_coord, Piece piece_from,
                                            Piece piece_to) const {
    PROFILE_FUNCTION();
    int piece_idx = start_coord.square_idx();
    int target_idx = target_coord.square_idx();

    // Validate move request
    if (!Validator::can_move_to(piece_idx, target_idx, m_AllPieceBB)) {
        return false;
    }

    // We cannot capture a friendly piece
    if (piece_from.color() == piece_to.color() && m_AllPieceBB.bit_value_at(target_idx) == 1) {
        return false;
    }

    return true;
}