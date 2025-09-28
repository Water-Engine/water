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
    chess::Board b("rnbqkb1r/Pp3p2/5n2/2p5/1P1ppPP1/3PQN2/2P1P1pp/RNB1KB1R b KQkq - 0 1");
    chess::Movelist moves;
    chess::movegen::legalmoves<chess::movegen::MoveGenType::ALL>(moves, b, chess::PieceGenType::BISHOP);
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