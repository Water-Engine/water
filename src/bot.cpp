#include <pch.hpp>

#include "bot.hpp"

#include "evaluation/evaluation.hpp"
#include "evaluation/ordering.hpp"

#include "polyglot/book.hpp"

void Bot::new_game() {
    m_Board->setFen(constants::STARTPOS);
    m_Searcher.reset();
    m_LastMove = Move::NO_MOVE;
}

int Bot::evaluate_current() { return Evaluator(m_Board).evaluate(); }

Result<void, std::string> Bot::set_position(const std::string& fen) {
    if (m_Board->setFen(fen)) {
        return Result<void, std::string>();
    } else {
        return Result<void, std::string>::Err("Failed to load/parse fen");
    }
}

Result<void, std::string> Bot::make_move(const std::string& move_uci) {
    Move move = uci::uciToMove(*m_Board, move_uci);
    m_Board->makeMove(move);
    m_LastMove = move;
    return Result<void, std::string>();
}

int Bot::choose_think_time(int time_remaining_white_ms, int time_remaining_black_ms,
                           int increment_white_ms, int increment_black_ms) {
    int my_time =
        (m_Board->sideToMove() == Color::WHITE) ? time_remaining_white_ms : time_remaining_black_ms;
    int my_increment =
        (m_Board->sideToMove() == Color::WHITE) ? increment_white_ms : increment_black_ms;

    float think_time_ms = (float)my_time / 40.0;
    if (USE_MAX_THINKING_TIME) {
        think_time_ms = std::min((float)MAX_THINK_TIME_MS, think_time_ms);
    }

    if (my_time > my_increment * 2) {
        think_time_ms += (float)my_increment * 0.8;
    }

    float min_think_time = std::min(50.0, (float)my_time * 0.25);
    return std::ceil(std::max(min_think_time, think_time_ms));
}

Result<void, std::string> Bot::think_timed(int time_ms) {
    auto bm = Book::instance().try_get_book_move(m_Board, m_BookWeight);
    if (bm.is_some()) {
        fmt::println("bestmove {}", bm.unwrap());
        return Result<void, std::string>();
    }

    m_Searcher.find_bestmove(time_ms);
    return Result<void, std::string>();
}

std::string Bot::board_diagram() {
    std::ostringstream oss;
    int last_move_square = -1;
    bool black_at_top = m_Board->sideToMove() == Color::WHITE;
    if (m_LastMove != 0) {
        last_move_square = m_LastMove.to().index();
    }

    for (int y = 0; y < 8; ++y) {
        int rank_idx = black_at_top ? 7 - y : y;
        oss << "+---+---+---+---+---+---+---+---+\n";
        for (int x = 0; x < 8; ++x) {
            int file_idx = black_at_top ? x : 7 - x;
            Coord square_coord(file_idx, rank_idx);
            if (!square_coord.valid_square_idx()) {
                continue;
            }

            int square_idx = square_coord.square_idx();
            bool highlight = square_idx == last_move_square;
            const Piece& piece = m_Board->at(square_idx);
            const std::string piece_string =
                (piece.type() == PieceType::NONE) ? " " : static_cast<std::string>(piece);

            if (highlight) {
                oss << fmt::interpolate("|({})", piece_string);
            } else {
                oss << fmt::interpolate("| {} ", piece_string);
            }
        }

        oss << fmt::interpolate("| {}\n", rank_idx + 1);
    }

    oss << "+---+---+---+---+---+---+---+---+\n";
    if (black_at_top) {
        oss << "  a   b   c   d   e   f   g   h  \n\n";
    } else {
        oss << "  h   g   f   e   d   c   b   a  \n\n";
    }

    oss << fmt::interpolate("Fen         : {}\n", m_Board->getFen());

    oss << fmt::interpolate("Hash        : {}", m_Board->hash());

    return oss.str();
}