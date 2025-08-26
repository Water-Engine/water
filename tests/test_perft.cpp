#include "test_framework/catch_amalgamated.hpp"
#include <pch.hpp>

#include "bot.hpp"

TEST_CASE("Single threaded startpos") {
    Bot b;
    REQUIRE(b.perft(1, false) == 20);
    REQUIRE(b.perft(2, false) == 400);
    REQUIRE(b.perft(3, false) == 8902);
    REQUIRE(b.perft(4, false) == 197281);
}