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

TEST_CASE("go options") {
    auto no_movetime = try_get_labeled_numeric<int>("go", "movetime", GO_LABELS);
    REQUIRE(no_movetime.is_none());

    auto movetime = try_get_labeled_numeric<int>("go movetime 10", "movetime", GO_LABELS);
    REQUIRE(movetime.is_some());
    REQUIRE(movetime.unwrap() == 10);

    auto wtime =
        try_get_labeled_numeric<int>("go wtime 10 btime 11 winc 12 binc 13", "wtime", GO_LABELS);
    auto btime =
        try_get_labeled_numeric<int>("go wtime 10 btime 11 winc 12 binc 13", "btime", GO_LABELS);
    auto winc =
        try_get_labeled_numeric<int>("go wtime 10 btime 11 winc 12 binc 13", "winc", GO_LABELS);
    auto binc =
        try_get_labeled_numeric<int>("go wtime 10 btime 11 winc 12 binc 13", "binc", GO_LABELS);

    REQUIRE(wtime.is_some());
    REQUIRE(btime.is_some());
    REQUIRE(winc.is_some());
    REQUIRE(binc.is_some());

    REQUIRE(wtime.unwrap() == 10);
    REQUIRE(btime.unwrap() == 11);
    REQUIRE(winc.unwrap() == 12);
    REQUIRE(binc.unwrap() == 13);
}