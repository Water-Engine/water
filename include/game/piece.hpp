enum Color { WHITE, BLACK };

class Piece {
  private:
    enum class PieceType : uint8_t {
        NONE = 0,
        ROOK = 1,
        KNIGHT = 2,
        BISHOP = 3,
        QUEEN = 4,
        KING = 5,
        PAWN = 6,
    };
};
