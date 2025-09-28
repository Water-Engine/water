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
    chess::Board b("1nbqkb1r/Pp3p2/2r2n2/2p1p2P/1PPp2PN/2N1Q2p/1BP1P1B1/R3K2R w KQk - 0 1");
    chess::Movelist moves;
    chess::movegen::legalmoves<chess::movegen::MoveGenType::ALL>(moves, b, chess::PieceGenType::KING);
    // fmt::println();

    // std::ostringstream oss;
    // int count = 0;
    // for (auto& m : moves) {
    //     oss << m.move() << ", ";
    //     if ((count + 1) % 8 == 0) {
    //         oss << "\n";
    //     }
    //     count += 1;
    // }
    // fmt::println(oss.str());
    PROFILE_END_SESSION();
}