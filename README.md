# water [![Zig](https://img.shields.io/badge/zig-0.15.1-orange)](https://ziglang.org/) [![License](https://img.shields.io/github/license/Water-Engine/water)](LICENSE) [![LOC](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/Water-Engine/water/loc/.github/loc_badge.json)](https://github.com/Water-Engine/water/actions/workflows/loc.yml) [![Last commit](https://img.shields.io/github/last-commit/Water-Engine/water)](https://github.com/Water-Engine/water) [![Formatting](https://github.com/Water-Engine/water/actions/workflows/format.yml/badge.svg)](https://github.com/Water-Engine/water/actions/workflows/format.yml) [![CI](https://github.com/Water-Engine/water/actions/workflows/ci.yml/badge.svg)](https://github.com/Water-Engine/water/actions/workflows/ci.yml)
A zero-dependency chess library & engine written in Zig.

# Goals
While this project is still a major WIP, the end-goal is a zero-dependency library and dual-mode engine:
- A fully documented and performant chess library, making Chess Engine programming more accessible for the Zig community
- An iterative search engine with Alpha-Beta Pruning, Quiescence, etc.
- A neural network-powered engine using Monte Carlo Tree Search (MCTS)

# Getting Started
For a quick build of the project, simply run `zig build run --release`.

## All Build Steps
| **Step**    | Description                                                                           |
|:------------|:--------------------------------------------------------------------------------------|
| `build`     | Builds `water`. Pass `--release` for ReleaseFast.                                     |
| `run`       | Build and run `water`. Pass `--release` for ReleaseFast.                              |
| `perft`     | Run the perft suite. Running with `--release` is highly recommended.                  |
| `test`      | Run all unit tests.                                                                   |
| `lint`      | Checks formatting of all source files excluding `build.zig`.                          |
| `fmt`       | Format all source code excluding `build.zig`.                                         |
| `cloc`      | Count the total lines of zig code. Requires [cloc](https://github.com/AlDanial/cloc). |

_The engine communicates through the UCI protocol for terminal interaction._

# Toolchain
- [Zig 0.15.1](https://ziglang.org/download/) - older versions _will not_ work due to 'Writergate'
- [cloc](https://github.com/AlDanial/cloc) for the cloc step (optional)

# Contributing
Contributors are always welcome! As this project progresses and the engine improves, it will become increasingly difficult for a single developer to make meaningful improvements or address bugs in a timely manner. Checkout [CONTRIBUTING.md](.github/CONTRIBUTING.md) for the project's guidelines.

# Credits
Water could not be where it is today without the formative work done by experienced developers in the past. Core references used during development include:
- [chess-library](https://github.com/Disservin/chess-library) inspired the rewrite to zig and served as a core pillar for ideas and verifying behavior in the core library.
- The [Avalanche](https://github.com/SnowballSH/Avalanche) chess engine which is dubbed 'the first and strongest UCI chess engine written in zig' for providing a huge source of motivation for improvement.
- The [Aurora](https://github.com/kjljixx/Aurora-Chess-Engine) chess engine which previously implemented a similar hybrid evaluation approach
- The legendary [Stockfish](https://github.com/official-stockfish/Stockfish) engine - used for verifying certain tests on the fly
