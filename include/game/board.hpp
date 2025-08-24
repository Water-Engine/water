#pragma once

#include "game/coord.hpp"
#include "game/move.hpp"
#include "game/piece.hpp"
#include "game/state.hpp"

#include "bitboard/bitboard.hpp"

constexpr std::string_view STARTING_FEN =
    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

constexpr std::string_view FILES = "abcdefgh";
constexpr std::string_view RANKS = "12345678";

// ================ POSITION INFORMATION ================

class PositionInfo {
  private:
    std::string m_Fen;
    std::array<Piece, 64> m_Squares;
    bool m_WhiteToMove;

    bool m_WhiteCastleKingside;
    bool m_WhiteCastleQueenside;
    bool m_BlackCastleKingside;
    bool m_BlackCastleQueenside;

    int m_EpSquare;
    int m_HalfmoveClock;
    int m_MoveClock;

  private:
    PositionInfo(std::string fen, std::array<Piece, 64> squares, bool white_to_move, bool wck,
                 bool wcq, bool bck, bool bcq, int ep, int halfmove_clock, int move_clock)
        : m_Fen(fen), m_Squares(squares), m_WhiteToMove(white_to_move), m_WhiteCastleKingside(wck),
          m_WhiteCastleQueenside(wcq), m_BlackCastleKingside(bck), m_BlackCastleQueenside(bcq),
          m_EpSquare(ep), m_HalfmoveClock(halfmove_clock), m_MoveClock(move_clock) {}

  public:
    PositionInfo() = default;
    static Result<PositionInfo, std::string> from_fen(const std::string& fen);

    friend class Board;
};

// ================ BOARD ================

struct ValidatedMove {
    Coord StartCoord;
    Coord TargetCoord;
    Piece PieceStart;
    Piece PieceTarget;
    int MoveFlag;
};

template <typename T>
concept PrecomputedValidator = requires(T t, int from, int to, const Bitboard& bb) {
    { T::can_move_to(from, to, bb) } -> std::convertible_to<bool>;
    { T::attacked_squares(from, bb) } -> std::convertible_to<Bitboard>;
    { T::as_piece_type() } -> std::convertible_to<PieceType>;
};

class illegal_board_access : public std::exception {
  private:
    std::string message;

  public:
    illegal_board_access() = delete;
    explicit illegal_board_access(const std::string& msg) : message(msg) {}

    const char* what() const noexcept override { return message.c_str(); }
};

class Board {
  private:
    PositionInfo m_StartPos;

    std::array<Piece, 64> m_StoredPieces;

    Bitboard m_WhiteBB;
    Bitboard m_BlackBB;
    Bitboard m_PawnBB;
    Bitboard m_KnightBB;
    Bitboard m_BishopBB;
    Bitboard m_RookBB;
    Bitboard m_QueenBB;
    Bitboard m_KingBB;

    Bitboard m_AllPieceBB;

    GameState m_State;
    bool m_WhiteToMove;

    std::vector<GameState> m_StateHistory;
    std::vector<Move> m_AllMoves;

  private:
    void load_from_position(const PositionInfo& pos);
    void reset();

    std::string diagram(bool black_at_top, bool include_fen = true, bool include_hash = true) const;

    bool make_king_move(Coord start_coord, Coord target_coord, int move_flag, Piece piece_from,
                        Piece piece_to);
    bool make_pawn_move(Coord start_coord, Coord target_coord, int move_flag, Piece piece_from,
                        Piece piece_to);

    template <PrecomputedValidator Validator>
    bool make_basic_precomputed_move(Coord start_coord, Coord target_coord, Piece piece_from,
                                     Piece piece_to, Bitboard& piece_bb);

    bool validate_king_move(Coord start_coord, Coord target_coord, int move_flag, Piece piece_from,
                            Piece piece_to) const;
    bool validate_pawn_move(Coord start_coord, Coord target_coord, int move_flag, Piece piece_from,
                            Piece piece_to) const;

    template <PrecomputedValidator Validator>
    bool validate_basic_precomputed_move(Coord start_coord, Coord target_coord, Piece piece_from,
                                         Piece piece_to) const;

    void move_piece(Bitboard& piece_bb, int from, int to, Piece piece);
    void remove_piece_at(int square_idx);

    bool move_leaves_self_checked(Coord start_coord, Coord target_coord, int move_flag,
                                  Piece piece_start, Piece piece_target);

    bool can_capture_ep(bool is_white) const;

    Bitboard& get_piece_bb(PieceType piece_type);
    template <PieceType Type> inline Bitboard& get_piece_bb() {
        if constexpr (Type == PieceType::Pawn) {
            return m_PawnBB;
        } else if constexpr (Type == PieceType::Knight) {
            return m_KnightBB;
        } else if constexpr (Type == PieceType::Bishop) {
            return m_BishopBB;
        } else if constexpr (Type == PieceType::Rook) {
            return m_RookBB;
        } else if constexpr (Type == PieceType::Queen) {
            return m_QueenBB;
        } else if constexpr (Type == PieceType::King) {
            return m_KingBB;
        } else {
            throw illegal_board_access("No bitboard associated for PieceType::None");
        }
    }

  public:
    Board() {};

    bool is_white_to_move() const { return m_WhiteToMove; }
    PieceColor friendly_color() const {
        return is_white_to_move() ? PieceColor::White : PieceColor::Black;
    }
    PieceColor opponent_color() const {
        return is_white_to_move() ? PieceColor::Black : PieceColor::White;
    }

    /// Important: Calling deep_verify will check the entire move legality including move_flags
    Option<ValidatedMove> is_legal_move(const Move& move, bool deep_verify = false);
    Bitboard pawn_attack_rays(PieceColor attacker_color) const;
    template <PrecomputedValidator Validator>
    Bitboard non_pawn_attack_rays(PieceColor attacker_color) const;

    Bitboard calculate_attack_rays(PieceColor attacker_color) const;
    Bitboard friendly_attack_rays() const {
        return calculate_attack_rays(m_WhiteToMove ? PieceColor::White : PieceColor::Black);
    };
    Bitboard opponent_attack_rays() const {
        return calculate_attack_rays(!m_WhiteToMove ? PieceColor::White : PieceColor::Black);
    };

    bool is_square_attacked(int square_idx, PieceColor occupied_color) const;
    bool king_in_check(PieceColor king_color) const;

    inline bool occupied(int square_idx) const { return m_AllPieceBB.contains_square(square_idx); }

    inline bool occupied_by_enemy(int square_idx, PieceColor friendly_color) const {
        if (friendly_color == PieceColor::White) {
            return m_BlackBB.contains_square(square_idx);
        } else {
            return m_WhiteBB.contains_square(square_idx);
        }
    }

    Piece piece_at(int square_idx) const;
    void add_piece(Piece piece, int square_idx);
    void make_move(const Move& move, bool in_search = false);
    void unmake_move(const Move& move, bool in_search = false);

    Result<void, std::string> load_from_fen(const std::string& fen);
    Result<void, std::string> load_startpos();
    std::string to_string() const { return diagram(m_WhiteToMove); };

    friend std::ostream& operator<<(std::ostream& os, const Board& board) {
        os << board.to_string();
        return os;
    }

    friend class Generator;
};
