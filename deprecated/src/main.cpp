#include <pch.hpp>

#include "launcher.hpp"

void signal_handler(int) {
    PROFILE_END_SESSION();
    std::_Exit(0);
}

int main() {
    std::signal(SIGINT, signal_handler);
    PROFILE_BEGIN_SESSION("Water", "Water-Main.json");
    // launch();
    chess::Board b("rnbqkbnr/pppppppp/8/8/8/3BPP1N/PPPP2PP/RNBQK2R w KQkq - 0 1");
    const auto m = chess::uci::uciToMove(b, "e1h1");
    fmt::println(b.hash());
    b.makeMove(m);
    fmt::println(b.hash());
    b.unmakeMove(m);
    fmt::println(b.hash());
    PROFILE_END_SESSION();
}