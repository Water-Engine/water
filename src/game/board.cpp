#include <pch.hpp>

#include "game/board.hpp"

PositionInfo::PositionInfo(std::string fen) : fen(fen) {
    fmt::println("Does this work?");
}

std::string Board::to_string() { return std::string("Im not finished"); }

Result<void, std::string> Board::load_from_fen(const std::string& fen) {
    PositionInfo pos(fen);
    return Result<void, std::string>::Err("Im not finished");
}
