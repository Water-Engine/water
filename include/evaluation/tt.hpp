#pragma once

enum class NodeType { Void, Exact, UpperBound, LowerBound };

struct Node {
    uint64_t ZobristKey;
    chess::Move BestMove;
    int Depth;
    int EvaluationScore;
    NodeType Type{NodeType::Void};

    Node() = default;
    Node(uint64_t key, const chess::Move& best_move_so_far, int ply_searched, int eval,
         NodeType type);
};

constexpr size_t NodeSize = sizeof(Node);

/// A custom data structure that uses board hashes to store evaluation data. Uses the 'Always
/// Replace' strategy currently
class TranspositionTable {
  private:
    Ref<chess::Board> m_Board;
    std::vector<Node> m_Entries;
    size_t m_Count;

  private:
    void reset_nodes();

  public:
    TranspositionTable(Ref<chess::Board> board, size_t table_size_mb);

    inline void clear() { reset_nodes(); }
    void resize(size_t new_table_size_mb);

    inline uint64_t current_idx() const { return m_Board->hash() % m_Count; }
    inline uint64_t current_idx(uint64_t key) const { return key % m_Count; }

    inline Option<chess::Move> try_get_best_move() const {
        return try_get_best_move(m_Board->hash());
    }
    Option<chess::Move> try_get_best_move(uint64_t key) const;

    inline Option<Node> probe() const { return probe(m_Board->hash()); };
    Option<Node> probe(uint64_t key) const;

    inline void insert(const Node& node) { insert(current_idx(), node); }
    void insert(size_t index, const Node& node);
};