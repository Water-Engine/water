#include <pch.hpp>

#include "launcher.hpp"

void signal_handler(int) {
    PROFILE_END_SESSION();
    std::_Exit(0);
}

class ChessPerft {
   public:
    virtual void setup(std::string fen) = 0;

    virtual uint64_t perft(int depth) = 0;

    void benchPerft(std::string fen, int depth, uint64_t expected_node_count) {
        using namespace std::chrono;
        setup(fen);

        const auto t1    = high_resolution_clock::now();
        const auto nodes = perft(depth);
        const auto t2    = high_resolution_clock::now();
        const auto ms    = duration_cast<milliseconds>(t2 - t1).count();

        std::stringstream ss;
        // clang-format off
        ss << "depth " << std::left << std::setw(2) << depth
           << " time " << std::setw(5) << ms
           << " nodes " << std::setw(12) << nodes
           << " nps " << std::setw(9) << (nodes * 1000) / (ms + 1)
           << " fen " << std::setw(87) << fen;
        // clang-format on
        std::cout << ss.str() << std::endl;
    }
};

class DisservinChess : public ChessPerft {
   public:
    void setup(std::string fen) override { board_.setFen(fen); }

    uint64_t perft(int depth) {
        chess::Movelist moves;
        chess::movegen::legalmoves(moves, board_);

        if (depth == 1) {
            return moves.size();
        }

        uint64_t nodes = 0;

        for (const auto& move : moves) {
            board_.makeMove(move);
            nodes += perft(depth - 1);
            board_.unmakeMove(move);
        }

        return nodes;
    }

   private:
    chess::Board board_;
};

int main() {
    std::signal(SIGINT, signal_handler);
    PROFILE_BEGIN_SESSION("Water", "Water-Main.json");
    // launch();
    DisservinChess c;
    c.benchPerft("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", 7, 0);
    // std::ofstream of("cpp_d3.txt");
    // of << c.oss.str();
    PROFILE_END_SESSION();
}