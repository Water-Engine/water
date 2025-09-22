#include "test_framework/catch_amalgamated.hpp"
#include <pch.hpp>

#include "bot.hpp"

// All tests mimic documented results: https://www.chessprogramming.org/Perft_Results

// ================ SINGLE THREADED ================

TEST_CASE("Single threaded (Position 1)") {
    Bot b;
    b.set_position("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    REQUIRE(b.perft(1) == 20);
    REQUIRE(b.perft(2) == 400);
    REQUIRE(b.perft(3) == 8902);
    REQUIRE(b.perft(4) == 197281);
}

TEST_CASE("Single threaded (Position 2)") {
    Bot b;
    b.set_position("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -");
    REQUIRE(b.perft(1) == 48);
    REQUIRE(b.perft(2) == 2039);
    REQUIRE(b.perft(3) == 97862);
    REQUIRE(b.perft(4) == 4085603);
}

TEST_CASE("Single threaded (Position 3)") {
    Bot b;
    b.set_position("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1");
    REQUIRE(b.perft(1) == 14);
    REQUIRE(b.perft(2) == 191);
    REQUIRE(b.perft(3) == 2812);
    REQUIRE(b.perft(4) == 43238);
}

TEST_CASE("Single threaded (Position 4)") {
    Bot b;
    b.set_position("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1");
    REQUIRE(b.perft(1) == 6);
    REQUIRE(b.perft(2) == 264);
    REQUIRE(b.perft(3) == 9467);
    REQUIRE(b.perft(4) == 422333);
}

TEST_CASE("Single threaded (Position 5)") {
    Bot b;
    b.set_position("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8");
    REQUIRE(b.perft(1) == 44);
    REQUIRE(b.perft(2) == 1486);
    REQUIRE(b.perft(3) == 62379);
    REQUIRE(b.perft(4) == 2103487);
}

TEST_CASE("Single threaded (Position 6)") {
    Bot b;
    b.set_position("r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10");
    REQUIRE(b.perft(1) == 46);
    REQUIRE(b.perft(2) == 2079);
    REQUIRE(b.perft(3) == 89890);
    REQUIRE(b.perft(4) == 3894594);
}
