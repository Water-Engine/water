#include <pch.hpp>

#include "evaluation/tt.hpp"

Node::Node(uint64_t key, const Move& best_move_so_far, int ply_searched, int eval, NodeType type)
    : ZobristKey(key), BestMove(best_move_so_far), Depth(ply_searched), EvaluationScore(eval),
      Type(type) {}

void TranspositionTable::reset_nodes() {
    for (auto& node : m_Entries) {
        node.Type = NodeType::Void;
    }
}

TranspositionTable::TranspositionTable(Ref<Board> board, size_t table_size_mb) : m_Board(board) {

    size_t table_size_bytes = table_size_mb * 1024 * 1024;
    size_t total_capacity = table_size_bytes / NodeSize;

    m_Count = total_capacity;
    m_Entries.resize(m_Count);
}

Option<Move> TranspositionTable::try_get_best_move(size_t index) const {
    if (index >= m_Count) {
        return Option<Move>();
    }

    auto node = m_Entries[index];
    if (node.Type == NodeType::Void) {
        return Option<Move>();
    } else {
        return Option<Move>(node.BestMove);
    }
}