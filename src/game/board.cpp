#include <pch.hpp>

#include "game/board.hpp"

std::string Board::to_string() { return std::string("Im not finished"); }

Result<void, std::string> Board::load_from_fen(const std::string& fen) {
    return Result<void, std::string>::Err("Im not finished");
}