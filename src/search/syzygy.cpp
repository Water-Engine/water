#include <pch.hpp>

#include "fathom/tbprobe.h"

#include "search/syzygy.hpp"

using namespace chess;

uint32_t SyzygyManager::tb_castling_mask() const {
    uint32_t mask = 0;
    using CastlingSide = Board::CastlingRights::Side;
    if (m_Board->castlingRights().has(Color::WHITE, CastlingSide::KING_SIDE)) {
        mask |= TB_CASTLING_K;
    }
    if (m_Board->castlingRights().has(Color::WHITE, CastlingSide::QUEEN_SIDE)) {
        mask |= TB_CASTLING_Q;
    }
    if (m_Board->castlingRights().has(Color::BLACK, CastlingSide::KING_SIDE)) {
        mask |= TB_CASTLING_k;
    }
    if (m_Board->castlingRights().has(Color::BLACK, CastlingSide::QUEEN_SIDE)) {
        mask |= TB_CASTLING_q;
    }
    return mask;
}

bool SyzygyManager::init(const std::string& folder) {
    std::lock_guard<std::mutex> lock(m_TBMutex);
    tb_free();

    std::filesystem::path tb_folder(folder);
    tb_folder = std::filesystem::absolute(tb_folder);
    bool exist = std::filesystem::exists(tb_folder);
    bool is_dir = std::filesystem::is_directory(tb_folder);

    if (!exist || !is_dir) {
        return false;
    }

    m_Loaded = tb_init(folder.c_str());
    m_FolderPath = tb_folder;
    return m_Loaded;
}

void SyzygyManager::clear() {
    std::lock_guard<std::mutex> lock(m_TBMutex);
    tb_free();
    m_Loaded = false;
    m_FolderPath.clear();
}

uint64_t SyzygyManager::probe_wdl() const {
    if (!m_Loaded) {
        return TB_RESULT_FAILED;
    }

    if (m_Board->all().count() > MAX_TB_PIECES) {
        return TB_RESULT_FAILED;
    }

    auto white = m_Board->us(chess::Color::WHITE).getBits();
    auto black = m_Board->us(chess::Color::BLACK).getBits();

    auto kings = m_Board->pieces(chess::PieceType::KING).getBits();
    auto queens = m_Board->pieces(chess::PieceType::QUEEN).getBits();
    auto rooks = m_Board->pieces(chess::PieceType::ROOK).getBits();
    auto bishops = m_Board->pieces(chess::PieceType::BISHOP).getBits();
    auto knights = m_Board->pieces(chess::PieceType::KNIGHT).getBits();
    auto pawns = m_Board->pieces(chess::PieceType::PAWN).getBits();

    uint32_t fifty_move = m_Board->halfMoveClock();
    auto castling = tb_castling_mask();
    Square ep_square = m_Board->enpassantSq();
    uint32_t ep = ep_square == Square::NO_SQ ? 0 : ep_square.index();
    bool turn = m_Board->sideToMove() == Color::WHITE;

    return tb_probe_wdl(white, black, kings, queens, rooks, bishops, knights, pawns, fifty_move,
                        castling, ep, turn);
}

Option<TbRootMoves> SyzygyManager::probe_dtz() const {
    if (!m_Loaded) {
        return Option<TbRootMoves>();
    }

    TbRootMoves results{};
    auto white = m_Board->us(Color::WHITE).getBits();
    auto black = m_Board->us(Color::BLACK).getBits();

    auto kings = m_Board->pieces(PieceType::KING).getBits();
    auto queens = m_Board->pieces(PieceType::QUEEN).getBits();
    auto rooks = m_Board->pieces(PieceType::ROOK).getBits();
    auto bishops = m_Board->pieces(PieceType::BISHOP).getBits();
    auto knights = m_Board->pieces(PieceType::KNIGHT).getBits();
    auto pawns = m_Board->pieces(PieceType::PAWN).getBits();

    uint32_t fifty_move = m_Board->halfMoveClock();
    auto castling = tb_castling_mask();
    Square ep_square = m_Board->enpassantSq();
    uint32_t ep = ep_square == Square::NO_SQ ? 0 : ep_square.index();
    bool turn = m_Board->sideToMove() == Color::WHITE;

    int ok = tb_probe_root_dtz(white, black, kings, queens, rooks, bishops, knights, pawns,
                               fifty_move, castling, ep, turn, false, true, &results);

    if (!ok) {
        return Option<TbRootMoves>();
    } else {
        return Option<TbRootMoves>(results);
    }
}
