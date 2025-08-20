# Core Roadmap
- [ ] Unit tests for core game
    - [ ] Move
    - [ ] Piece
    - [ ] Coord
    - [ ] Board
- [ ] Knight move validation (Precomputed locations)
- [ ] Rook move validation (magics for ortho sliders & blockers)
- [ ] Bishop move validation (magics for diag sliders & blockers)
- [ ] Queen move validation (bitwise or of bishops and rooks)
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