# 1.0.0
- Initial release
- Library
    - 49,548 total perft tests passed
    - Fully cross compatible and usable with engines
    - Relatively performative, see benchmarks for more information
- Engine
    - 800 games played against elo limited stockfish, see benchmarks for specifics
    - Initial estimates place engine somewhere between 2730 and 2775
    - Tests ran at TC=40/60+0.1
    - Crashed once throughout testing, though cause is unknown

# 1.0.1
- Updated NNUE dependency resolution technique to be local to the project and not visible by users using this as a library
- Added clarification to README regarding the zig llvm backend

# 1.0.2