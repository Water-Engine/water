#include "test_framework/catch_amalgamated.hpp"
#include <pch.hpp>

#include "game/board.hpp"
#include "game/move.hpp"

TEST_CASE("move constructors") {
    auto board = CreateRef<Board>();
    board->load_startpos();
}