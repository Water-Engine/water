#include "test_framework/catch_amalgamated.hpp"
#include <pch.hpp>

#include "game/board.hpp"
#include "game/move.hpp"

#include "evaluation/tt.hpp"

TEST_CASE("Basic insertion") {
    Ref<Board> board = CreateRef<Board>();
    TranspositionTable tt(board, 1);

    Move move(board, "e2e4");
    Node node(board->current_hash(), move, 1, 100, NodeType::Exact);

    tt.insert(node);
    auto best_move = tt.try_get_best_move();

    REQUIRE(best_move.is_some());
    REQUIRE(best_move.unwrap() == move);
}

TEST_CASE("Clearing entries") {
    Ref<Board> board = CreateRef<Board>();
    TranspositionTable tt(board, 1);

    Move move(board, "d2d4");
    Node node(board->current_hash(), move, 1, 50, NodeType::LowerBound);

    tt.insert(node);
    tt.clear();

    auto best_move = tt.try_get_best_move();
    REQUIRE(best_move.is_none());
}

TEST_CASE("Always replace strategy") {
    Ref<Board> board = CreateRef<Board>();
    TranspositionTable tt(board, 1);

    Move move1(board, "g1f3");
    Node node1(board->current_hash(), move1, 1, 20, NodeType::UpperBound);
    tt.insert(node1);

    Move move2(board, "c2c4");
    Node node2(board->current_hash(), move2, 2, 30, NodeType::Exact);
    tt.insert(node2);

    auto best_move = tt.try_get_best_move();
    REQUIRE(best_move.is_some());
    REQUIRE(best_move.unwrap() == move2);
}

TEST_CASE("Insert at specific index") {
    Ref<Board> board = CreateRef<Board>();
    TranspositionTable tt(board, 1);

    size_t index = 5;
    Move move(board, "b1c3");
    Node node(board->current_hash(), move, 1, 42, NodeType::Exact);
    tt.insert(index, node);

    auto best_move = tt.try_get_best_move(index);
    REQUIRE(best_move.is_some());
    REQUIRE(best_move.unwrap() == move);
}

TEST_CASE("Out-of-bounds index") {
    Ref<Board> board = CreateRef<Board>();
    TranspositionTable tt(board, 1);

    auto best_move = tt.try_get_best_move(UINT64_MAX);
    REQUIRE(best_move.is_none());
}