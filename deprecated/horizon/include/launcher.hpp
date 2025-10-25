#pragma once

constexpr uint64_t DEFAULT_DEPTH = 6;
constexpr uint64_t MAX_OPENING_DEPTH = 16;
constexpr std::string_view DEFAULT_PGN_PARENT = "pgn";
constexpr std::string_view DEFAULT_PGN_EXT = ".pgn";
constexpr std::string_view DEFAULT_OUTPUT = "polyglot.bin";

int launch(int argc, char* argv[]);
