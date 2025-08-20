#pragma once

#include "game/move.hpp"
#include "game/piece.hpp"
#include "game/state.hpp"

#include "bitboard/bitboard.hpp"

constexpr std::string_view STARTING_FEN =
    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

constexpr std::string_view FILES = "abcdefgh";
constexpr std::string_view RANKS = "12345678";

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

    GameState m_State;
    bool m_WhiteToMove;

    std::deque<GameState> m_StateHistory;
    std::vector<Move> m_AllMoves;

    int m_HalfmoveClock;

  private:
    void load_from_position(const PositionInfo& pos);
    void reset();

    std::string diagram(bool black_at_top, bool include_fen = true, bool include_hash = true) const;

  public:
    Board() {};

    bool is_white_to_move() const { return m_WhiteToMove; }
    PieceColor friendly_color() const {
        return is_white_to_move() ? PieceColor::White : PieceColor::Black;
    }
    PieceColor opponent_color() const {
        return is_white_to_move() ? PieceColor::Black : PieceColor::White;
    }

    Bitboard all_pieces() const;
    Piece piece_at(int square_idx);
    void make_move(Move move);

    Result<void, std::string> load_from_fen(const std::string& fen);
    std::string to_string() const { return diagram(m_WhiteToMove); };

    friend std::ostream& operator<<(std::ostream& os, const Board& board) {
        os << board.to_string();
        return os;
    }

    friend class Validator;
};
