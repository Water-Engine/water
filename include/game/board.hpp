#include "core.hpp"

constexpr std::string_view STARTING_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

class Board
{
  public:
    Board() {}
    
    Result<void, std::string> load_from_fen(const std::string &fen);
    std::string to_string();
};