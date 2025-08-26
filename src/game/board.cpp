#include <pch.hpp>

#include "bitboard/bitboard.hpp"

#include "game/board.hpp"

#include "generator/king.hpp"
#include "generator/knight.hpp"
#include "generator/pawn.hpp"
#include "generator/sliders.hpp"

// ================ POSITION INFO ================

Result<PositionInfo, std::string> PositionInfo::from_fen(const std::string& fen) {
    PROFILE_FUNCTION();
    auto sections = str::split(fen);
    if (sections.size() < 4) {
        return Result<PositionInfo, std::string>::Err(
            "FEN notation requires at least 4 distinct fields");
    }

    std::string& position = sections[0];
    std::string& to_move = sections[1];
    std::string& castling_rights = sections[2];
    std::string& ep_square = sections[3];

    // Initialization
    std::array<Piece, 64> squares;
    squares.fill(Piece());
    bool white_to_move = true;

    bool wck = false;
    bool wcq = false;
    bool bck = false;
    bool bcq = false;

    int ep_square_idx = -1;
    int halfmove_clock = 0;
    int move_clock = 0;

    // Decode the position string into a board of pieces
    int file = 0;
    int rank = 7;
    for (const char c : position) {
        if (c == '/') {
            file = 0;
            rank -= 1;
        } else {
            if (std::isdigit(c)) {
                file += c - '0';
            } else {
                Piece p(c);
                squares[rank * 8 + file] = p;
                file += 1;
            }
        }
    }

    // Who's move is it
    if (to_move[0] == 'b') {
        white_to_move = false;
    }

    // Castling rights
    if (str::contains(castling_rights, 'K')) {
        wck = true;
    }
    if (str::contains(castling_rights, 'Q')) {
        wcq = true;
    }
    if (str::contains(castling_rights, 'k')) {
        bck = true;
    }
    if (str::contains(castling_rights, 'q')) {
        bcq = true;
    }

    if (ep_square != "-") {
        ep_square_idx = Coord(ep_square).square_idx();
    }

    if (sections.size() >= 5) {
        try {
            halfmove_clock = std::stoi(sections[4]);
        } catch (...) {
        }
    }

    if (sections.size() >= 6) {
        try {
            move_clock = std::stoi(sections[5]);
        } catch (...) {
        }
    }

    PositionInfo p(fen, squares, white_to_move, wck, wcq, bck, bcq, ep_square_idx, halfmove_clock,
                   move_clock);
    return Result<PositionInfo, std::string>(p);
}

// ================ BOARD ================

void Board::load_from_position(const PositionInfo& pos) {
    PROFILE_FUNCTION();
    reset();

    m_AllMoves.reserve(pos.m_MoveClock);
    m_StartPos = pos;
    m_State =
        GameState(pos.m_WhiteCastleKingside, pos.m_WhiteCastleQueenside, pos.m_BlackCastleKingside,
                  pos.m_BlackCastleQueenside, pos.m_EpSquare, pos.m_HalfmoveClock);

    m_StoredPieces = pos.m_Squares;
    m_WhiteToMove = pos.m_WhiteToMove;

    for (size_t i = 0; i < pos.m_Squares.size(); i++) {
        Piece piece = pos.m_Squares[i];
        if (piece.is_none()) {
            continue;
        }

        if (piece.is_white()) {
            m_WhiteBB.set_bit(i);
        } else if (piece.is_black()) {
            m_BlackBB.set_bit(i);
        }

        if (piece.is_rook()) {
            m_RookBB.set_bit(i);
        } else if (piece.is_knight()) {
            m_KnightBB.set_bit(i);
        } else if (piece.is_bishop()) {
            m_BishopBB.set_bit(i);
        } else if (piece.is_queen()) {
            m_QueenBB.set_bit(i);
        } else if (piece.is_king()) {
            m_KingBB.set_bit(i);
        } else if (piece.is_pawn()) {
            m_PawnBB.set_bit(i);
        }
    }

    m_AllPieceBB = m_WhiteBB | m_BlackBB;

    cache_self();
    m_StateHistory.emplace_back(m_State);
}

void Board::reset() {
    PROFILE_FUNCTION();
    m_StartPos = PositionInfo{};

    m_StoredPieces.fill(Piece());

    m_WhiteBB.clear();
    m_BlackBB.clear();
    m_PawnBB.clear();
    m_KnightBB.clear();
    m_BishopBB.clear();
    m_RookBB.clear();
    m_QueenBB.clear();
    m_KingBB.clear();

    m_AllPieceBB.clear();

    m_State = GameState{};
    m_WhiteToMove = true;

    m_StateHistory.clear();
    m_AllMoves.clear();
}

std::string Board::diagram(bool black_at_top, bool include_fen, bool include_hash) const {
    PROFILE_FUNCTION();
    std::ostringstream oss;
    int last_move_square = -1;
    if (m_AllMoves.size() > 0) {
        last_move_square = m_AllMoves[m_AllMoves.size() - 1].target_square();
    }

    for (int y = 0; y < 8; y++) {
        int rank_idx = black_at_top ? 7 - y : y;
        oss << "+---+---+---+---+---+---+---+---+\n";
        for (int x = 0; x < 8; x++) {
            int file_idx = black_at_top ? x : 7 - x;
            Coord square_coord(file_idx, rank_idx);
            if (!square_coord.valid_square_idx()) {
                continue;
            }

            int square_idx = square_coord.square_idx();
            bool highlight = square_idx == last_move_square;
            const Piece& piece = m_StoredPieces[square_idx];

            if (highlight) {
                oss << fmt::interpolate("|({})", (char)piece);
            } else {
                oss << fmt::interpolate("| {} ", (char)piece);
            }
        }

        oss << fmt::interpolate("| {}\n", rank_idx + 1);
    }

    oss << "+---+---+---+---+---+---+---+---+\n";
    if (black_at_top) {
        oss << "  a   b   c   d   e   f   g   h  \n\n";
    } else {
        oss << "  h   g   f   e   d   c   b   a  \n\n";
    }

    if (include_fen) {
        oss << fmt::interpolate("Fen         : {}\n", "Not implemented");
    }

    if (include_hash) {
        oss << fmt::interpolate("Hash        : {}", "Not implemented");
    }

    return oss.str();
}

bool Board::make_king_move(Coord start_coord, Coord target_coord, int move_flag, Piece piece_from,
                           Piece piece_to) {
    PROFILE_FUNCTION();
    if (move_flag != NO_FLAG && move_flag != CASTLE_FLAG) {
        return false;
    }

    Bitboard opponent_rays = opponent_attack_rays();
    if (move_flag == NO_FLAG) {
        if (!King::can_move_to(start_coord.square_idx_unchecked(),
                               target_coord.square_idx_unchecked())) {
            return false;
        }

        if (piece_from.color() == piece_to.color() &&
            m_AllPieceBB.contains_square(target_coord.square_idx_unchecked())) {
            return false;
        }

        move_piece(m_KingBB, start_coord.square_idx_unchecked(),
                   target_coord.square_idx_unchecked(), piece_from);
    } else if (move_flag == CASTLE_FLAG) {
        const int king_from = start_coord.square_idx_unchecked();
        const int king_to = target_coord.square_idx_unchecked();
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
        int rook_from, rook_to;
        if (piece_from.is_white()) {
            if (king_side) {
                rook_from = Square::H1;
                rook_to = Square::F1;
            } else {
                rook_from = Square::A1;
                rook_to = Square::D1;
            }
        } else {
            if (king_side) {
                rook_from = Square::H8;
                rook_to = Square::F8;
            } else {
                rook_from = Square::A8;
                rook_to = Square::D8;
            }
        }

        Piece rook_piece = m_StoredPieces[rook_from];
        if (!rook_piece.is_rook() || rook_piece.color() != piece_from.color()) {
            return false;
        }

        // Now move the pieces
        move_piece(m_KingBB, king_from, king_to, piece_from);
        move_piece(m_RookBB, rook_from, rook_to, rook_piece);
    }

    // Any king move that makes it this far will invalidate its castling rights
    if (piece_from.is_white()) {
        m_State.white_lost_kingside_right();
        m_State.white_lost_queenside_right();
    } else {
        m_State.black_lost_kingside_right();
        m_State.black_lost_queenside_right();
    }
    return true;
}

bool Board::make_pawn_move(Coord start_coord, Coord target_coord, int move_flag, Piece piece_from,
                           Piece piece_to) {
    PROFILE_FUNCTION();
    if (piece_from.is_white() &&
        !Pawn::can_move_to<PieceColor::White>(start_coord.square_idx_unchecked(),
                                              target_coord.square_idx_unchecked())) {
        return false;
    } else if (piece_from.is_black() &&
               !Pawn::can_move_to<PieceColor::Black>(start_coord.square_idx_unchecked(),
                                                     target_coord.square_idx_unchecked())) {
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
            m_AllPieceBB.contains_square(target_coord.square_idx_unchecked())) {
            return false;
        }

        move_piece(m_PawnBB, start_coord.square_idx_unchecked(),
                   target_coord.square_idx_unchecked(), piece_from);
    } else if (move_flag == PAWN_TWO_UP_FLAG) {
        if (piece_from.color() == piece_to.color() &&
            m_AllPieceBB.contains_square(target_coord.square_idx_unchecked())) {
            return false;
        }

        int ep_square = start_coord.square_idx_unchecked() + (piece_from.is_white() ? 8 : -8);
        if (m_AllPieceBB.contains_square(ep_square)) {
            return false;
        }

        m_State.set_ep(ep_square);
        move_piece(m_PawnBB, start_coord.square_idx_unchecked(),
                   target_coord.square_idx_unchecked(), piece_from);
    } else if (move_flag == PAWN_CAPTURE_FLAG) {
        int old_ep_square = m_State.get_ep_square();

        // Handle ep side of moves
        if (old_ep_square == target_coord.square_idx_unchecked()) {
            if (!can_capture_ep(piece_from.color() == PieceColor::White)) {
                return false;
            }

            // Move and capture involved pawns
            int captured_pawn_square = old_ep_square + (piece_from.is_white() ? -8 : 8);
            remove_piece_at(captured_pawn_square);
            m_State.indicate_capture();
            move_piece(m_PawnBB, start_coord.square_idx_unchecked(),
                       target_coord.square_idx_unchecked(), piece_from);
        } else {
            // Fallback to basic captures, diagonal moves must attack an enemy piece, but we know it
            // is a valid attack square due to passing can_move_to checks
            if (piece_from.color() == piece_to.color()) {
                return false;
            } else if ((int)piece_at(target_coord.square_idx_unchecked()) == Piece::none()) {
                return false;
            }

            move_piece(m_PawnBB, start_coord.square_idx_unchecked(),
                       target_coord.square_idx_unchecked(), piece_from);
        }
    } else if (Move::is_promotion(move_flag)) {
        // 1. Ensure the target square is a promotion rank
        int target_idx = target_coord.square_idx_unchecked();
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

        // 4. Remove pawn and add promoted piece
        remove_piece_at(start_coord.square_idx_unchecked());
        if (piece_to.type() != PieceType::None) {
            remove_piece_at(target_idx);
        }
        add_piece(promotion_piece, target_idx);
    } else {
        return false;
    }

    m_State.indicate_pawn_move();
    return true;
}

template <PrecomputedValidator Validator>
bool Board::make_basic_precomputed_move(Coord start_coord, Coord target_coord, Piece piece_from,
                                        Piece piece_to, Bitboard& piece_bb) {
    PROFILE_FUNCTION();
    int piece_idx = start_coord.square_idx_unchecked();
    int target_idx = target_coord.square_idx_unchecked();

    // Validate move request
    if (!Validator::can_move_to(piece_idx, target_idx, m_AllPieceBB)) {
        return false;
    }

    // We cannot capture a friendly piece
    if (piece_from.color() == piece_to.color() && m_AllPieceBB.bit_value_at(target_idx) == 1) {
        return false;
    }

    move_piece(piece_bb, piece_idx, target_idx, piece_from);

    // If were moving a rook, then we have to update castling rights
    if constexpr (Validator::as_piece_type() == PieceType::Rook) {
        if (piece_from.is_white()) {
            if (m_State.can_white_kingside() && start_coord.square_idx_unchecked() == Square::H1) {
                m_State.white_lost_kingside_right();
            } else if (m_State.can_white_queenside() &&
                       start_coord.square_idx_unchecked() == Square::A1) {
                m_State.white_lost_queenside_right();
            }
        } else {
            if (m_State.can_black_kingside() && start_coord.square_idx_unchecked() == Square::H8) {
                m_State.black_lost_kingside_right();
            } else if (m_State.can_black_queenside() &&
                       start_coord.square_idx_unchecked() == Square::A8) {
                m_State.black_lost_queenside_right();
            }
        }
    }

    return true;
}

void Board::move_piece(Bitboard& piece_bb, int from, int to, Piece piece) {
    PROFILE_FUNCTION();
    piece_bb.clear_bit(from);

    // If there is an enemy piece on the target, remove it BEFORE placing the new piece
    if (piece.is_white()) {
        if (m_BlackBB.bit_value_at(to) == 1) {
            m_State.indicate_capture();
            remove_piece_at(to);
        }
    } else {
        if (m_WhiteBB.bit_value_at(to) == 1) {
            m_State.indicate_capture();
            remove_piece_at(to);
        }
    }

    piece_bb.set_bit(to);

    if (piece.is_white()) {
        m_WhiteBB.clear_bit(from);
        m_WhiteBB.set_bit(to);
    } else {
        m_BlackBB.clear_bit(from);
        m_BlackBB.set_bit(to);
    }

    m_AllPieceBB.clear_bit(from);
    m_AllPieceBB.set_bit(to);

    m_StoredPieces[from].clear();
    m_StoredPieces[to] = piece;
}

void Board::remove_piece_at(int square_idx) {
    PROFILE_FUNCTION();
    Piece piece = m_StoredPieces[square_idx];
    if (piece.is_none()) {
        return;
    }
    m_AllPieceBB.clear_bit(square_idx);

    PieceColor occupied_piece_color = piece.color();
    PieceType occupied_piece_type = piece.type();

    if (occupied_piece_type == PieceType::Rook) {
        if (occupied_piece_color == PieceColor::White) {
            if (square_idx == Square::H1 && m_State.can_white_kingside()) {
                m_State.white_lost_kingside_right();
            } else if (square_idx == Square::A1 && m_State.can_white_queenside()) {
                m_State.white_lost_queenside_right();
            }
        } else {
            if (square_idx == Square::H8 && m_State.can_black_kingside()) {
                m_State.black_lost_kingside_right();
            } else if (square_idx == Square::A8 && m_State.can_black_queenside()) {
                m_State.black_lost_queenside_right();
            }
        }
    }

    if (occupied_piece_color == PieceColor::White) {
        m_WhiteBB.clear_bit_unchecked(square_idx);
    } else {
        m_BlackBB.clear_bit_unchecked(square_idx);
    }

    get_piece_bb(occupied_piece_type).clear_bit_unchecked(square_idx);
    m_StoredPieces[square_idx].clear();
}

Piece Board::piece_at(int square_idx) const {
    if (!Coord::valid_square_idx(square_idx)) {
        return Piece::none();
    }

    return m_StoredPieces[square_idx];
}

void Board::add_piece(Piece piece, int square_idx) {
    if (!Coord::valid_square_idx(square_idx)) {
        return;
    }

    m_StoredPieces[square_idx] = piece;
    get_piece_bb(piece.type()).set_bit_unchecked(square_idx);

    if (piece.is_white()) {
        m_WhiteBB.set_bit_unchecked(square_idx);
    } else {
        m_BlackBB.set_bit_unchecked(square_idx);
    }

    m_AllPieceBB.set_bit_unchecked(square_idx);
}

void Board::make_move(const Move& move, bool in_search) {
    PROFILE_FUNCTION();

    // piece move handlers assume legality and valid start and end coords
    auto maybe_validated_move = is_legal_move(move);
    if (maybe_validated_move.is_none()) {
        return;
    }

    auto validated = maybe_validated_move.unwrap();
    Coord start_coord = validated.StartCoord;
    Coord target_coord = validated.TargetCoord;
    Piece piece_start = validated.PieceStart;
    Piece piece_target = validated.PieceTarget;
    int move_flag = validated.MoveFlag;

    // The move has transendendid pseudo-legality
    bool was_valid;
    switch (piece_start.type()) {
    case PieceType::Rook:
        was_valid = make_basic_precomputed_move<Rook>(start_coord, target_coord, piece_start,
                                                      piece_target, m_RookBB);
        break;
    case PieceType::Knight:
        was_valid = make_basic_precomputed_move<Knight>(start_coord, target_coord, piece_start,
                                                        piece_target, m_KnightBB);
        break;
    case PieceType::Bishop:
        was_valid = make_basic_precomputed_move<Bishop>(start_coord, target_coord, piece_start,
                                                        piece_target, m_BishopBB);
        break;
    case PieceType::Queen:
        was_valid = make_basic_precomputed_move<Queen>(start_coord, target_coord, piece_start,
                                                       piece_target, m_QueenBB);
        break;
    case PieceType::King:
        was_valid = make_king_move(start_coord, target_coord, move_flag, piece_start, piece_target);
        break;
    case PieceType::Pawn:
        was_valid = make_pawn_move(start_coord, target_coord, move_flag, piece_start, piece_target);
        break;
    default:
        return;
    }

    if (!was_valid) {
        return;
    }

    if (!(piece_start.is_pawn() && move_flag == PAWN_TWO_UP_FLAG)) {
        m_State.clear_ep();
    }

    m_State.try_reset_halfmove_clock();

    cache_self();

    m_StateHistory.push_back(m_State);
    m_WhiteToMove = !m_WhiteToMove;

    if (!in_search) {
        m_AllMoves.push_back(move);
    }
}

void Board::unmake_last_move(bool in_search) {
    if (!in_search) {
        m_AllMoves.pop_back();
    }

    m_StateHistory.pop_back();
    m_State = m_StateHistory.back();
    m_WhiteToMove = !m_WhiteToMove;

    auto bbs = m_State.get_cache();

    m_StoredPieces = bbs.StoredPieces;
    m_WhiteBB = bbs.WhiteBB;
    m_BlackBB = bbs.BlackBB;
    m_PawnBB = bbs.PawnBB;
    m_KnightBB = bbs.KnightBB;
    m_BishopBB = bbs.BishopBB;
    m_RookBB = bbs.RookBB;
    m_QueenBB = bbs.QueenBB;
    m_KingBB = bbs.KingBB;
    m_AllPieceBB = bbs.AllPieceBB;
}

Result<void, std::string> Board::load_from_fen(const std::string& fen) {
    PROFILE_FUNCTION();
    auto maybe_pos = PositionInfo::from_fen(fen);
    if (maybe_pos.is_err()) {
        return Result<void, std::string>::Err(maybe_pos.unwrap_err());
    }

    load_from_position(maybe_pos.unwrap());
    return Result<void, std::string>();
}

Bitboard& Board::get_piece_bb(PieceType piece_type) {
    switch (piece_type) {
    case PieceType::Pawn:
        return get_piece_bb<PieceType::Pawn>();
    case PieceType::Knight:
        return get_piece_bb<PieceType::Knight>();
    case PieceType::Bishop:
        return get_piece_bb<PieceType::Bishop>();
    case PieceType::Rook:
        return get_piece_bb<PieceType::Rook>();
    case PieceType::Queen:
        return get_piece_bb<PieceType::Queen>();
    case PieceType::King:
        return get_piece_bb<PieceType::King>();
    default:
        return get_piece_bb<PieceType::None>();
    }
}

Result<void, std::string> Board::load_startpos() {
    return load_from_fen(str::from_view(STARTING_FEN));
}
