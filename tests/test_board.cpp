#include "test_framework/catch_amalgamated.hpp"
#include <pch.hpp>

#include "game/board.hpp"
#include "game/move.hpp"

TEST_CASE("Castling rights and moves") {
    Ref<Board> board = CreateRef<Board>();

    board->load_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1");
    auto moves = board->generate_moves();

    REQUIRE(contains(moves, Move(board, "e1g1")));
    REQUIRE(contains(moves, Move(board, "e1c1")));
    REQUIRE(contains(moves, Move(board, "e8g8")));
    REQUIRE(contains(moves, Move(board, "e8c8")));
}

TEST_CASE("En passant capture") {
    Ref<Board> board = CreateRef<Board>();

    board->load_fen("8/8/8/3pP3/8/8/8/8 w - d6 0 2");
    auto moves = board->generate_moves();

    REQUIRE(contains(moves, Move(board, "e5d6")));
}

TEST_CASE("Illegal moves rejected") {
    Ref<Board> board = CreateRef<Board>();

    board->load_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQ - 0 1");
    auto moves = board->generate_moves();

    board->load_fen("r3k2r/8/8/8/8/8/8/R3K1R1 w Q - 0 1");
    moves = board->generate_moves();

    REQUIRE_FALSE(contains(moves, Move(board, "e1c1")));
}

TEST_CASE("Promotion moves") {
    Ref<Board> board = CreateRef<Board>();

    board->load_fen("8/P7/8/8/8/8/7p/8 w - - 0 1");
    auto moves = board->generate_moves();

    REQUIRE(contains(moves, Move(board, "a7a8q")));
    REQUIRE(contains(moves, Move(board, "a7a8n")));

    board->load_fen("8/P7/8/8/8/8/7p/8 b - - 0 1");
    moves = board->generate_moves();
    REQUIRE(contains(moves, Move(board, "h2h1q")));
    REQUIRE(contains(moves, Move(board, "h2h1r")));
}

