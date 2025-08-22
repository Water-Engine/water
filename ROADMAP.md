# Core Roadmap
- [ ] Unit tests for core
    - [x] Launcher
    - [ ] Move
    - [ ] Piece
    - [ ] Coord
    - [ ] Board
- [x] Knight move validation - naive (Precomputed locations)
- [x] Rook move validation - naive (magics for ortho sliders & blockers)
- [x] Bishop move validation - naive (magics for diag sliders & blockers)
- [x] Queen move validation - naive (bitwise or of bishops and rooks)
- [ ] King move validation (check, double check, etc.)
- [ ] Pawn move validation (most complex piece)
- [ ] Pseudo legal moves vs. legal moves
- [ ] Perft testing

# Search Core
- [ ] Zobrist hashing
- [ ] Custom Hash (Transposition) Table for positions
- [ ] Search thread - `go` command should not halt io operations
- [ ] Make/Unmake move system, including null moves for evaluation
- [ ] Evaluating positions with NNUE and piece-square-boards

# Milestones
- [ ] All pieces move as expected
- [ ] Legal move generation
- [ ] Implement perft for regression testing