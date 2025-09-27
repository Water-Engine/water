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
    chess::Board b;
    const auto m = chess::uci::uciToMove(b, "e2e4");
    b.makeMove(m);
    // fmt::println(b.hash());
    b.unmakeMove(m);
    // fmt::println(b.hash());
    PROFILE_END_SESSION();
}