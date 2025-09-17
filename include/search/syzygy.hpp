#pragma once

struct TbRootMoves;

class SyzygyManager {
  private:
    Ref<chess::Board> m_Board;

    std::atomic<bool> m_Loaded;
    std::filesystem::path m_FolderPath;
    mutable std::mutex m_TBMutex;

  private:
    uint32_t tb_castling_mask() const;

  public:
    SyzygyManager(Ref<chess::Board> board) : m_Board(board), m_Loaded(false) {}

    /// Initialize / reload tablebases from a folder
    bool init(const std::string& folder);

    bool is_loaded() const { return m_Loaded; }
    void clear();

    uint64_t probe_wdl() const;
    Option<TbRootMoves> probe_dtz() const;
    std::string status() const;
};
