#include "test_framework/catch_amalgamated.hpp"
#include <pch.hpp>

#include "game/board.hpp"
#include "game/move.hpp"

TEST_CASE("Pawn promotion") {
    Ref<Board> board = CreateRef<Board>();
    board->load_fen("7P/8/8/8/8/8/8/7k w - - 0 1");

    auto moves = board->generate_moves();
    REQUIRE(contains(moves, Move(board, "h7h8q")));
    REQUIRE(contains(moves, Move(board, "h7h8n")));
    REQUIRE(contains(moves, Move(board, "h7h8r")));
    REQUIRE(contains(moves, Move(board, "h7h8b")));
}

TEST_CASE("Pawn en passant") {
    Ref<Board> board = CreateRef<Board>();
    board->load_fen("8/8/8/3pP3/8/8/8/8 w - d6 0 2");

    auto moves = board->generate_moves();
    REQUIRE(contains(moves, Move(board, "e5d6"))); 
}

TEST_CASE("Knight moves from edge") {
    Ref<Board> board = CreateRef<Board>();
    board->load_fen("8/8/8/8/8/8/N7/8 w - - 0 1");

    auto moves = board->generate_moves();
    REQUIRE(moves.size() == 2);
    REQUIRE(contains(moves, Move(board, "a2b4")));
    REQUIRE(contains(moves, Move(board, "a2c3")));
}

TEST_CASE("Bishop blocked by own pieces") {
    Ref<Board> board = CreateRef<Board>();
    board->load_fen("8/8/8/3B4/2P5/8/8/8 w - - 0 1");

    auto moves = board->generate_moves();
    for (auto& move : moves) {
        REQUIRE(board->piece_at(move.to()).is_none() || board->piece_at(move.to())->color != Color::White);
    }
}

TEST_CASE("Bishop at edge of board") {
    Ref<Board> board = CreateRef<Board>();
    board->load_fen("B7/8/8/8/8/8/8/8 w - - 0 1");

    auto moves = board->generate_moves();
    for (auto& move : moves) {
        REQUIRE(move.from() == "a8");
    }
}

TEST_CASE("Rook moves blocked by own piece") {
    Ref<Board> board = CreateRef<Board>();
    board->load_fen("R7/8/8/8/8/8/P7/8 w - - 0 1");

    auto moves = board->generate_moves();
    for (auto& move : moves) {
        REQUIRE(board->piece_at(move.to()).is_none() || board->piece_at(move.to())->color != Color::White);
    }
}

TEST_CASE("Queen combining rook+bishop moves") {
    Ref<Board> board = CreateRef<Board>();
    board->load_fen("8/8/3Q4/8/8/8/8/8 w - - 0 1");

    auto moves = board->generate_moves();
    REQUIRE(contains(moves, Move(board, "d6d7")));
    REQUIRE(contains(moves, Move(board, "d6d5")));
    REQUIRE(contains(moves, Move(board, "d6e7")));
    REQUIRE(contains(moves, Move(board, "d6c5")));
}

TEST_CASE("King cannot move into check") {
    Ref<Board> board = CreateRef<Board>();
    board->load_fen("8/8/8/8/8/8/4r3/4K3 w - - 0 1");

    auto moves = board->generate_moves();
    for (auto& move : moves) {
        if (move.from() == "e1") {
            REQUIRE_FALSE(board->would_be_in_check(move, Color::White));
        }
    }
}

TEST_CASE("King castling") {
    Ref<Board> board = CreateRef<Board>();
    board->load_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1");

    auto moves = board->generate_moves();
    REQUIRE(contains(moves, Move(board, "e1g1")));
    REQUIRE(contains(moves, Move(board, "e1c1")));
}

TEST_CASE("King blocked castling") {
    Ref<Board> board = CreateRef<Board>();
    board->load_fen("r3k2r/8/8/8/8/8/8/R3K1R1 w KQ - 0 1");

    auto moves = board->generate_moves();
    REQUIRE_FALSE(contains(moves, Move(board, "e1c1")));
}
