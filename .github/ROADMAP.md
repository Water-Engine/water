# Core Roadmap
- [x] Unit tests for core
    - [x] Launcher
    - [x] Bot
- [x] Knight move validation - naive (Precomputed locations)
- [x] Rook move validation - naive (magics for ortho sliders & blockers)
- [x] Bishop move validation - naive (magics for diag sliders & blockers)
- [x] Queen move validation - naive (bitwise or of bishops and rooks)
- [x] King move validation (check, double check, etc.)
- [x] Pawn move validation (most complex piece)
- [X] Pseudo legal moves vs. legal moves
- [x] Perft testing (Will validate correctness is Board, move, Coord, etc.)
- [x] Zobrist hashing
- [x] Custom Hash (Transposition) Table for positions

# Search Core
- [x] Make/Unmake move system, including null moves for evaluation if needed
- [ ] Search thread - `go` command should not halt io operations
- [ ] Evaluating positions with NNUE and piece-square-tables (after NN implemented)
- [x] Opening book for well-played openings

# Neural Net
- [ ] Input Encoding
    - [ ] Define board → tensor format (pieces, side to move, castling rights, en passant, move counters)
    - [ ] Map moves → fixed policy index space
    - [ ] Conversion functions: engine moves <> policy vector
- [ ] Network Architecture
    - [ ] Prototype small CNN (conv layers + policy/value heads)
    - [ ] Forward pass in C++ 
    - [ ] Optimizer implementation (SGD/Adam) and backprop
- [ ] Self-Play & Data Pipeline
    - [ ] Implement MCTS guided by policy net
    - [ ] Store (state, π, z) tuples for training
    - [ ] Optional PGN import for supervised bootstrapping
- [ ] Training Loop
    - [ ] Train network on collected self-play data
    - [ ] Arena matches for selecting stronger nets
    - [ ] Track Elo/progress internally
- [ ] Scaling & Optimization
    - [ ] Residual networks / deeper nets
    - [ ] Batch evaluation
    - [ ] GPU acceleration / distributed self-play

# Milestones
- [x] All pieces move as expected
- [x] Legal move generation
- [x] Implement perft for regression testing
- [ ] Non-blocking commands
- [ ] Iterative search
- [ ] Basic NN setup
- [ ] Basic Neural Net setup (forward pass + policy/value heads)
- [ ] NN Trainer and Self-Play implemented
- [ ] NN integrated with search (MCTS or alpha-beta)
- [ ] NN improves through self-play / arena matches
- [ ] Opening book + NN evaluation working together
