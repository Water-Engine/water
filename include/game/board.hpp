#include "core.hpp"

class Board
{
  public:
    Board() {}
    
    Result<void, std::string> load_from_fen(const std::string &fen);
    std::string to_string();
};