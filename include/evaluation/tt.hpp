#pragma once

enum class NodeType { Void, Exact, UpperBound, LowerBound };

struct Node {
    uint64_t ZobristKey;
    Move BestMove;
    int Depth;
    int EvaluationScore;
    NodeType Type{NodeType::Void};

    Node() = default;
    Node(uint64_t key, const Move& best_move_so_far, int ply_searched, int eval, NodeType type);
};

constexpr size_t NodeSize = sizeof(Node);

/// A custom data structure that uses board hashes to store evaluation data. Uses the 'Always
/// Replace' strategy currently
class TranspositionTable {
  private:
    Ref<Board> m_Board;
    std::vector<Node> m_Entries;
    size_t m_Count;

  private:
    void reset_nodes();

  public:
    TranspositionTable(Ref<Board> board, size_t table_size_mb);

    inline void clear() { reset_nodes(); }
    inline uint64_t current_idx() const { return m_Board->hash() % m_Count; }

    inline Option<Move> try_get_best_move() const { return try_get_best_move(current_idx()); }
    Option<Move> try_get_best_move(size_t index) const;

    void insert(size_t index, const Node& node) { m_Entries[index] = node; }
    void insert(const Node& node) { insert(current_idx(), node); }
};