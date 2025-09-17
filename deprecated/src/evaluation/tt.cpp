#include <pch.hpp>

#include "evaluation/tt.hpp"

using namespace chess;

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

void TranspositionTable::resize(size_t new_table_size_mb) {
    size_t new_count = (new_table_size_mb * 1024 * 1024) / NodeSize;
    std::vector<Node> new_entries(new_count);

    // Rehash old nodes
    for (auto& node : m_Entries) {
        if (node.Type != NodeType::Void) {
            new_entries[current_idx(node.ZobristKey)] = node;
        }
    }

    m_Entries = std::move(new_entries);
    m_Count = new_count;
}

Option<Move> TranspositionTable::try_get_best_move(uint64_t key) const {
    auto index = current_idx(key);
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

Option<Node> TranspositionTable::probe(uint64_t key) const {
    auto index = current_idx(key);
    if (index >= m_Count) {
        return Option<Node>();
    }

    auto node = m_Entries[index];
    if (node.Type == NodeType::Void) {
        return Option<Node>();
    } else {
        return Option<Node>(node);
    }
}

void TranspositionTable::insert(size_t index, const Node& node) {
    auto& old_node = m_Entries[index];
    if (old_node.Type == NodeType::Void || node.Type == NodeType::Exact ||
        node.Depth >= old_node.Depth) {
        old_node = node;
    }
}