# Core Roadmap
- [ ] Unit tests for core
    - [x] Launcher
    - [ ] Bot
- [x] Knight move validation - naive (Precomputed locations)
- [x] Rook move validation - naive (magics for ortho sliders & blockers)
- [x] Bishop move validation - naive (magics for diag sliders & blockers)
- [x] Queen move validation - naive (bitwise or of bishops and rooks)
- [x] King move validation (check, double check, etc.)
- [x] Pawn move validation (most complex piece)
- [X] Pseudo legal moves vs. legal moves
- [ ] Perft testing (Will validate correctness is Board, move, Coord, etc.)

# Search Core
- [ ] Zobrist hashing
- [ ] Custom Hash (Transposition) Table for positions
- [ ] Search thread - `go` command should not halt io operations
- [ ] Make/Unmake move system, including null moves for evaluation if needed
- [ ] Evaluating positions with NNUE and piece-square-boards

# Milestones
- [ ] All pieces move as expected
- [ ] Legal move generation
- [ ] Implement perft for regression testing