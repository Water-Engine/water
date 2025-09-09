#pragma once

constexpr size_t MAX_BUFFER_SIZE = 64 * 1024;

#pragma pack(push, 1)
struct PolyEntry {
    uint64_t key;
    uint16_t move;
    uint16_t weight;
    uint16_t learn;
};
#pragma pack(pop)

class PGNVisitor : public pgn::Visitor {
  private:
    Board m_Board;
    uint64_t m_MaxOpeningDepth;
    std::vector<PolyEntry> m_Buffer;
    std::unordered_map<uint64_t, std::unordered_map<uint16_t, uint16_t>> m_PositionMap;

    uint64_t m_NumHalfMovesSoFar;

    std::ostringstream m_OutData;

  private:
    static void write_entry(std::ostringstream& oss, const PolyEntry& e);

    void flush();
    void try_flush();

    inline void add_to_map(uint64_t key, uint16_t move) {
        auto& move_map = m_PositionMap[key];
        if (move_map[move] < UINT16_MAX) {
            move_map[move] += 1;
        }
    }

  public:
    PGNVisitor(uint64_t depth) : m_Board(), m_MaxOpeningDepth(depth), m_NumHalfMovesSoFar(0) {
        m_Board.setFen(constants::STARTPOS);
        m_Buffer.reserve(MAX_BUFFER_SIZE);
    }

    virtual ~PGNVisitor() { dump(); }

    virtual void startPgn() override;
    virtual void header([[maybe_unused]] std::string_view key,
                        [[maybe_unused]] std::string_view value) override {}
    virtual void startMoves() override {}
    virtual void move([[maybe_unused]] std::string_view move,
                      [[maybe_unused]] std::string_view comment) override;
    virtual void endPgn() override;

    inline void dump() {
        try_flush();
        flush();
    }

    inline std::string to_string() {
        dump();
        return m_OutData.str();
    }
};

std::string make_polyglot_book(int depth, const std::filesystem::path& pgn_file);
