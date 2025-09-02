#pragma once

#include "bitboard/bitboard.hpp"

#include "game/board.hpp"
#include "game/move.hpp"
#include "game/piece.hpp"

#include "generator/king.hpp"
#include "generator/knight.hpp"
#include "generator/pawn.hpp"
#include "generator/sliders.hpp"

enum class PromotionFlag {
    Queen = QUEEN_PROMOTION_FLAG,
    Rook = ROOK_PROMOTION_FLAG,
    Bishop = BISHOP_PROMOTION_FLAG,
    Knight = KNIGHT_PROMOTION_FLAG,
};

enum class PromotionsToGenerate {
    None,
    AllTypes,
    QueenOnly,
    RookOnly,
    BishopOnly,
    KnightOnly,
    QueenRookOnly,
    QueenBishopOnly,
    QueenKnightOnly,
    RookBishopOnly,
    RookKnightOnly,
    BishopKnightOnly,
    QueenRookBishopOnly,
    QueenRookKnightOnly,
    QueenBishopKnightOnly,
    RookBishopKnightOnly,
};

template <PromotionsToGenerate P>
constexpr auto promotions_for = [] {
    if constexpr (P == PromotionsToGenerate::AllTypes) {
        return std::array{PromotionFlag::Queen, PromotionFlag::Rook, PromotionFlag::Bishop,
                          PromotionFlag::Knight};
    } else if constexpr (P == PromotionsToGenerate::QueenOnly) {
        return std::array{PromotionFlag::Queen};
    } else if constexpr (P == PromotionsToGenerate::RookOnly) {
        return std::array{PromotionFlag::Rook};
    } else if constexpr (P == PromotionsToGenerate::BishopOnly) {
        return std::array{PromotionFlag::Bishop};
    } else if constexpr (P == PromotionsToGenerate::KnightOnly) {
        return std::array{PromotionFlag::Knight};
    } else if constexpr (P == PromotionsToGenerate::QueenRookOnly) {
        return std::array{PromotionFlag::Queen, PromotionFlag::Rook};
    } else if constexpr (P == PromotionsToGenerate::QueenBishopOnly) {
        return std::array{PromotionFlag::Queen, PromotionFlag::Bishop};
    } else if constexpr (P == PromotionsToGenerate::QueenKnightOnly) {
        return std::array{PromotionFlag::Queen, PromotionFlag::Knight};
    } else if constexpr (P == PromotionsToGenerate::RookBishopOnly) {
        return std::array{PromotionFlag::Rook, PromotionFlag::Bishop};
    } else if constexpr (P == PromotionsToGenerate::RookKnightOnly) {
        return std::array{PromotionFlag::Rook, PromotionFlag::Knight};
    } else if constexpr (P == PromotionsToGenerate::BishopKnightOnly) {
        return std::array{PromotionFlag::Bishop, PromotionFlag::Knight};
    } else if constexpr (P == PromotionsToGenerate::QueenRookBishopOnly) {
        return std::array{PromotionFlag::Queen, PromotionFlag::Rook, PromotionFlag::Bishop};
    } else if constexpr (P == PromotionsToGenerate::QueenRookKnightOnly) {
        return std::array{PromotionFlag::Queen, PromotionFlag::Rook, PromotionFlag::Knight};
    } else if constexpr (P == PromotionsToGenerate::QueenBishopKnightOnly) {
        return std::array{PromotionFlag::Queen, PromotionFlag::Bishop, PromotionFlag::Knight};
    } else if constexpr (P == PromotionsToGenerate::RookBishopKnightOnly) {
        return std::array{PromotionFlag::Rook, PromotionFlag::Bishop, PromotionFlag::Knight};
    }
}();

class MoveList {
  private:
    static constexpr size_t MAX_MOVES = 256;

    std::array<Move, MAX_MOVES> m_Moves{};
    std::array<int, MAX_MOVES> m_Scores{};
    size_t m_Size = 0;

  public:
    inline size_t size() const { return m_Size; }

    inline void push_back(const Move& m) {
        if (m_Size >= m_Moves.size()) {
            return;
        }

        m_Moves[m_Size++] = m;
    }

    inline void set_score(size_t idx, int score) {
        if (idx >= m_Scores.size()) {
            return;
        }

        m_Scores[idx] = score;
    }

    inline int score_at(size_t idx) const { return m_Scores[idx]; }

    inline Move* begin() { return m_Moves.data(); }
    inline Move* end() { return m_Moves.data() + m_Size; }
    inline const Move* begin() const { return m_Moves.data(); }
    inline const Move* end() const { return m_Moves.data() + m_Size; }

    inline Move& operator[](size_t idx) { return m_Moves[idx]; }
    inline const Move& operator[](size_t idx) const { return m_Moves[idx]; }

    inline void filter(Board& board) {
        size_t i = 0;
        for (size_t j = 0; j < size(); ++j) {
            if (board.is_legal_move(m_Moves[j], true).is_some()) {
                m_Moves[i++] = m_Moves[j];
            }
        }
        m_Size = i;
    }

    inline void sort_by_scores() {
        std::array<size_t, MoveList::MAX_MOVES> indices{};
        for (size_t i = 0; i < m_Size; ++i) {
            indices[i] = i;
        }

        // Sort indices by scores descending
        std::sort(indices.begin(), indices.begin() + m_Size,
                  [&](size_t a, size_t b) { return m_Scores[a] > m_Scores[b]; });

        // Reorder moves and scores in-place
        std::array<Move, MoveList::MAX_MOVES> moves_copy = m_Moves;
        std::array<int, MoveList::MAX_MOVES> scores_copy = m_Scores;

        for (size_t i = 0; i < m_Size; ++i) {
            m_Moves[i] = moves_copy[indices[i]];
            m_Scores[i] = scores_copy[indices[i]];
        }
    }

    friend class Generator;
};

class Generator {
  private:
    template <PieceColor Color, PromotionsToGenerate Promotions>
    inline static void generate_pawn_moves(Bitboard& relevant_pawn_bb, Board& board,
                                           MoveList& out) {
        PROFILE_FUNCTION();
        while (relevant_pawn_bb != 0) {
            int pawn_idx = relevant_pawn_bb.pop_lsb();

            // Forward moves
            int single_push_idx = Color == PieceColor::White ? pawn_idx + 8 : pawn_idx - 8;
            if (!board.occupied(single_push_idx)) {
                // promotion check
                if (Coord::rank_from_square(single_push_idx) == 7 ||
                    Coord::rank_from_square(single_push_idx) == 0) {
                    auto flags = promotions_for<Promotions>;
                    for (auto& flag : flags) {
                        out.push_back(Move(pawn_idx, single_push_idx, static_cast<int>(flag)));
                    }
                } else {
                    out.push_back(Move(pawn_idx, single_push_idx));
                }

                // Double push (only from starting rank)
                int double_push_idx = Color == PieceColor::White ? pawn_idx + 16 : pawn_idx - 16;
                int intermediate_idx = Color == PieceColor::White ? pawn_idx + 8 : pawn_idx - 8;
                if ((Color == PieceColor::White && Coord::rank_from_square(pawn_idx) == 1) ||
                    (Color == PieceColor::Black && Coord::rank_from_square(pawn_idx) == 6)) {
                    if (!board.occupied(double_push_idx) && !board.occupied(intermediate_idx)) {
                        out.push_back(Move(pawn_idx, double_push_idx, PAWN_TWO_UP_FLAG));
                    }
                }
            }

            // Captures
            int left_capture = Color == PieceColor::White ? pawn_idx + 7 : pawn_idx - 9;
            int right_capture = Color == PieceColor::White ? pawn_idx + 9 : pawn_idx - 7;

            auto maybe_push_capture = [&](int target_idx) {
                if (!Coord::valid_square_idx(target_idx)) {
                    return;
                }

                bool is_capture = false;
                bool is_ep = false;

                // normal capture
                if (board.occupied_by_enemy(target_idx, Color)) {
                    is_capture = true;
                }

                // en-passant capture (target square empty but equals EP target)
                else if (board.get_ep_square() == target_idx) {
                    is_ep = true;
                    is_capture = true;
                }

                if (is_capture) {
                    // Check if it's a promotion capture
                    if (Coord::rank_from_square(target_idx) == 7 ||
                        Coord::rank_from_square(target_idx) == 0) {
                        auto flags = promotions_for<Promotions>;
                        for (auto& flag : flags) {
                            out.push_back(Move(pawn_idx, target_idx, static_cast<int>(flag)));
                        }
                    } else {
                        out.push_back(
                            Move(pawn_idx, target_idx, is_ep ? EP_FLAG : PAWN_CAPTURE_FLAG));
                    }
                }
            };

            maybe_push_capture(left_capture);
            maybe_push_capture(right_capture);
        }
    }

    template <PieceColor Color>
    inline static void generate_king_moves(Bitboard& relevant_king_bb, MoveList& out) {
        PROFILE_FUNCTION();
        while (relevant_king_bb != 0) {
            int king_idx = relevant_king_bb.pop_lsb();
            Bitboard attacked = King::attacked_squares(king_idx);
            append_attacked(king_idx, attacked, out);

            Bitboard castle_moves = King::castle_squares<Color>(king_idx);
            while (castle_moves != 0) {
                int castle_idx = castle_moves.pop_lsb();
                Move castle_move(king_idx, castle_idx, CASTLE_FLAG);
                out.push_back(castle_move);
            }
        }
    }

    template <PrecomputedValidator Validator>
    inline static void generate_basic_precomputed_moves(Bitboard& relevant_bb,
                                                        const Bitboard& occupancy, MoveList& out) {
        PROFILE_FUNCTION();
        while (relevant_bb != 0) {
            int piece_idx = relevant_bb.pop_lsb();
            Bitboard attacked = Validator::attacked_squares(piece_idx, occupancy);
            append_attacked(piece_idx, attacked, out);
        }
    }

    inline static void append_attacked(int start_idx, Bitboard& attacked, MoveList& out) {
        PROFILE_FUNCTION();
        while (attacked != 0) {
            int attacked_idx = attacked.pop_lsb();
            Move attacking_move(start_idx, attacked_idx);
            out.push_back(attacking_move);
        }
    }

  public:
    Generator() = delete;
    Generator(const Generator&) = delete;

    template <PieceColor Color, PromotionsToGenerate Promotions = PromotionsToGenerate::AllTypes>
    inline static MoveList generate(Board& board) {
        PROFILE_FUNCTION();
        bool is_white = Color == PieceColor::White;
        auto& color_bb = is_white ? board.m_WhiteBB : board.m_BlackBB;
        auto relevant_pawns = board.m_PawnBB & color_bb;
        auto relevant_knights = board.m_KnightBB & color_bb;
        auto relevant_bishops = board.m_BishopBB & color_bb;
        auto relevant_rooks = board.m_RookBB & color_bb;
        auto relevant_queens = board.m_QueenBB & color_bb;
        auto relevant_kings = board.m_KingBB & color_bb;

// While compiler warning can be helpful, the MoveList data structure cannot overflow
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Warray-bounds"
        MoveList all_moves;

        generate_pawn_moves<Color, Promotions>(relevant_pawns, board, all_moves);
        generate_king_moves<Color>(relevant_kings, all_moves);
        generate_basic_precomputed_moves<Knight>(relevant_knights, board.m_AllPieceBB, all_moves);
        generate_basic_precomputed_moves<Bishop>(relevant_bishops, board.m_AllPieceBB, all_moves);
        generate_basic_precomputed_moves<Rook>(relevant_rooks, board.m_AllPieceBB, all_moves);
        generate_basic_precomputed_moves<Queen>(relevant_queens, board.m_AllPieceBB, all_moves);
#pragma GCC diagnostic pop

        if (all_moves.size() == 0) {
            return all_moves;
        }

        all_moves.filter(board);
        return all_moves;
    }

    inline static MoveList generate(Board& board) {
        if (board.is_white_to_move()) {
            return generate<PieceColor::White>(board);
        } else {
            return generate<PieceColor::Black>(board);
        }
    }
};
