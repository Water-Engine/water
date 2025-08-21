#include "test_framework/catch_amalgamated.hpp"
#include <pch.hpp>

#include "launcher.hpp"

TEST_CASE("position type processing") {
    Engine e;

    auto missing_type = e.process_position_cmd("position");
    auto expected = Result<void, std::string>::Err(
        "Invalid position command: expected either 'startpos' or 'fen'");
    REQUIRE(missing_type == expected);

    auto both_types = e.process_position_cmd("position fen startpos");
    expected = Result<void, std::string>::Err(
        "Invalid position command: expected either 'startpos' or 'fen', received both");
    REQUIRE(both_types == expected);

    auto uci_result = e.process_position_cmd("position startpos");
    REQUIRE(uci_result.is_ok());
    auto fen_result = e.process_position_cmd(
        "position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    REQUIRE(fen_result.is_ok());
}

TEST_CASE("position moves processing") {
    auto uci_empty_moves = try_get_labeled_string("position startpos", "moves", POSITION_LABELS);
    REQUIRE(uci_empty_moves.is_none());

    auto fen_empty_moves = try_get_labeled_string(
        "position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", "moves",
        POSITION_LABELS);
    REQUIRE(fen_empty_moves.is_none());

    auto uci_moves =
        try_get_labeled_string("position startpos moves e2e4 e7e6", "moves", POSITION_LABELS);
    REQUIRE(uci_moves.is_some());
    REQUIRE(uci_moves.unwrap() == "e2e4 e7e6");

    auto fen_moves = try_get_labeled_string(
        "position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 moves e2e4 e7e6",
        "moves", POSITION_LABELS);
    REQUIRE(fen_moves.is_some());
    REQUIRE(fen_moves.unwrap() == "e2e4 e7e6");
}