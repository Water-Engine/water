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
    chess::Board b("bbrknnqr/pppppppp/8/8/8/8/PPPPPPPP/BBRKNNQR w KQkq - 0 1", true);
    fmt::println(b.getCastlingPath(chess::Color::WHITE, false).getBits());
    fmt::println(b.getCastlingPath(chess::Color::WHITE, true).getBits());
    fmt::println(b.getCastlingPath(chess::Color::BLACK, false).getBits());
    fmt::println(b.getCastlingPath(chess::Color::BLACK, true).getBits());
    PROFILE_END_SESSION();
}