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
    chess::Board b("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1");
    for (size_t i = 0; i < 64; ++i) {
        auto out = chess::attacks::attackers(b, chess::Color::BLACK, chess::Square(i));
        fmt::println("{},", out.getBits());
    }
    PROFILE_END_SESSION();
}