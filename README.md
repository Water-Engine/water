# water [![C++20](https://img.shields.io/badge/C%2B%2B-20-blue?logo=c%2B%2B&logoColor=white)](https://en.cppreference.com/w/cpp/20.html) [![License](https://img.shields.io/github/license/Water-Engine/water)](LICENSE) [![LOC](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/Water-Engine/water/loc/.github/loc_badge.json)](https://github.com/Water-Engine/water/actions/workflows/loc.yml) [![Last commit](https://img.shields.io/github/last-commit/Water-Engine/water)](https://github.com/Water-Engine/water) [![Formatting](https://github.com/Water-Engine/water/actions/workflows/format.yml/badge.svg)](https://github.com/Water-Engine/water/actions/workflows/format.yml) [![CI](https://github.com/Water-Engine/water/actions/workflows/ci.yml/badge.svg)](https://github.com/Water-Engine/water/actions/workflows/ci.yml)
A chess engine written in C++, powered by Disservin's [chess-library](https://github.com/Disservin/chess-library), utilizing a hybrid approach of classical and neural network evaluation.

# Goals
While this project is still a major WIP, the end-goal is a dual-mode engine:
- An iterative search engine with Alpha-Beta Pruning, Quiescence, etc.
- A neural network-powered engine using Monte Carlo Tree Search (MCTS)

# Getting Started
Before building, ensure you have the necessary NNUE files, which can be fetched using `python scripts/stockfish_nnue.py`. Note that this script requires the [requests](https://pypi.org/project/requests/) package to work properly.

For a quick build of the project, run:
```shell
git clone https://github.com/Water-Engine/water.git
cd water
make -j4 run
```

_The engine communicates through the UCI protocol for terminal interaction._

# Core Dependencies
- g++ with C++20
- GNU Make
- Clang-format
- [Catch2](https://github.com/catchorg/Catch2) for tests (included in this repository)
- [cloc](https://github.com/AlDanial/cloc) for cloc make target (optional)
- [python](https://www.python.org/downloads/) for script running
- [Zig](https://ziglang.org/download/) for cross-platform packaging (optional)


# Building water
The project's build system uses C++20 and GNU Make, and it is recommended that you run make with the flag `-j4` to run batch jobs. Below is a list of targets with their requirements where applicable:

## Build Specific Targets
- `default`: Builds the release configuration (default)
- `install`: Builds the dist config (to be updated)
- `all`: Builds all optimization configurations for the project (dist, release, and debug)
- `dist`: Builds the project with maximum optimization and disabled profiling
- `release`: Builds the project with slightly fewer optimizations and no DEBUG define
- `debug`: Builds the project with no optimization, defining both PROFILE and DEBUG
- `test`: Run the project's unit tests Excludes perft testing
- `perft`: Run the perft tests
- `run`: Alias for run-release
- `run-dist`: Build and run the dist binary
- `run-release`: Build and run the release binary
- `run-debug`: Build and run the debug binary
- `fmt`: Format all C++ source and header files using `clang-format`
- `fmt-check`: Validates C++ formatting rules without altering project files
- `clean`: Remove object files, dependency files, and binaries

## General Targets
- `cloc`: Count the lines of code in the project's relevant directories
- `sliders`: Generate the magic numbers for the rooks and bishops
- `help`: Print this help menu

# For Developers
Contributing guidelines, information on tests, formatting, and profiling can be found in [CONTRIBUTING.md](.github/CONTRIBUTING.md). You can also check out a WIP roadmap for the project at [ROADMAP.md](.github/ROADMAP.md).

### Why Contribute?
- Learn engine internals such as move generation, evaluation, and search  
- Work on low-level performance optimizations in modern C++ 
- Explore and improve machine learning fine-tuning for chess 

# Credits
Water could not be where it is today without the formative work done by experienced developers in the past. Core references used during development include:
- [chess-library](https://github.com/Disservin/chess-library) revived my motivation after many failed attempts
    - Maybe in the future I'll roll my own core library, but it was taking too much out of me
    - This library saved a lot of time and frustration for me, so I would like to personally thank the chess-library teams for their hard work
- [Syzygy](https://www.chessprogramming.org/Syzygy_Bases) tables originally created by Dutch mathematician [Ronald de Man](https://www.chessprogramming.org/Ronald_de_Man)
- [Fathom](https://github.com/jdart1/Fathom) syzygy tablebase reader - rewritten and catered to the Water engine
- Sebastian Lague's [Chess Coding Adventure](https://github.com/SebLague/Chess-Coding-Adventure) engine - used for comparative testing for elo estimates
- The [Aurora](https://github.com/kjljixx/Aurora-Chess-Engine) chess engine which previously implemented a similar hybrid evaluation approach
- The legendary [Stockfish](https://github.com/official-stockfish/Stockfish) engine - used for verifying certain tests on the fly
