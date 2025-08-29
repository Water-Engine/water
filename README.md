# water [![C++20](https://img.shields.io/badge/C%2B%2B-20-blue?logo=c%2B%2B&logoColor=white)](https://en.cppreference.com/w/cpp/20.html) [![Rust](https://img.shields.io/static/v1?label=Rust&message=2024&labelColor=gray&color=F1592A)](https://github.com/rust-lang/rust) [![License](https://img.shields.io/github/license/trevorswan11/water)](LICENSE) ![LOC](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/trevorswan11/water/main/.github/loc_badge.json) [![Last commit](https://img.shields.io/github/last-commit/trevorswan11/water)](https://github.com/trevorswan11/water) [![Formatting](https://github.com/trevorswan11/water/actions/workflows/format.yml/badge.svg)](https://github.com/trevorswan11/water/actions/workflows/format.yml) [![CI](https://github.com/trevorswan11/water/actions/workflows/ci.yml/badge.svg)](https://github.com/trevorswan11/water/actions/workflows/ci.yml)
A chess engine written in C++ with a Rust frontend, powered by magic bitboard and neural networks.

# Getting Started

## Quick Build (Water)
For a quick build of the project, run:
```shell
git clone https://github.com/trevorswan11/water.git
cd water
make -j4 run
```

## Cactus
To build and run the gui, install the rust toolchain and run:
```shell
git clone https://github.com/trevorswan11/water.git
cd water
make gui
```
To run the gui with the water engine (or any other external engine), its path must be given as a command line arg. The general format is `<binary> [white "path_to_engine"] [black "path_to_engine"]`. If the white or black options are not given or the paths are not valid, then it will default to a normal player.

Examples:
```shell
cargo run --release -- white bin/dist/water.exe
cargo run --release -- black path/to/stockfish.exe
```

# Dependencies
- g++ with C++20
- GNU Make
- Clang-format
- [Catch2](https://github.com/catchorg/Catch2) (included in this repository)
- [Cargo](https://doc.rust-lang.org/beta/book/ch01-01-installation.html) (for building and running the gui > optional)
- [cloc](https://github.com/AlDanial/cloc) and [jq](https://github.com/jqlang/jq) (for cloc make target > optional)
- [python](https://www.python.org/downloads/) for script running including cloc (for cloc make target and general scripts)
    - On windows, Make will assume python is accessible as `python`, but will be assumed to be `python3` on UNIX systems

# Building water
The project's build system uses C++20 and GNU Make, and it is recommended that you run make with the flag `-j4` to run batch jobs. Below is a list of targets with their requirements where applicable:

## C++ Specific Targets
- `default`: Builds the release configuration (default)
- `install`: Builds the dist config (to be updated)
- `all`: Builds all optimization configurations for the project (dist, release, and debug)
- `dist`: Builds the project with maximum optimization and disabled profiling
- `release`: Builds the project with slightly fewer optimizations and no DEBUG define
- `debug`: Builds the project with no optimization, defining both PROFILE and DEBUG
- `test`: Run the project's unit tests Excludes perft testing
- `perft`: Run the perft tests
- `run`: Build and run the release binary
- `run-dist`: Build and run the dist binary
- `run-release`: Build and run the release binary
- `run-debug`: Build and run the debug binary
- `fmt`: Format all C++ source and header files using `clang-format`
- `fmt-check`: Validates C++ formatting rules without altering project files
- `clean`: Remove object files, dependency files, and binaries

## Rust (Cargo) Specific Targets
- `gui`: Alias for `gui-release`
- `gui-release`: Builds the GUI release configuration
- `gui-debug`: Builds the GUI debug configuration. This is not recommended and is considerably slower
- `gui-fmt`: Format all Rust source files using `cargo fmt`
- `gui-fmt-check`: Validates Rust formatting rules without altering project files
- `gui-clean`: Cleans Rust's `target` directory. Will result in a very long compilation time on next build

## General Targets
- `fmt-all`: Format all project source files. Assumes Cargo is installed
- `cloc`: Count the lines of code in the project's relevant directories
- `everything`: Make all C++ targets and build the Rust debug and release targets. Assumes Cargo is installed
- `clean-all`: Remove all C++ and Rust object files, dependency files, and binaries

# The GUI (Cactus)
Cactus is a minimal rust-based chess gui built for playing basic games against chess engines. It was created with the intent of being the engine itself, but a lack of understanding of chess engine mechanics resulted in a dead project. As a result, it has been stripped to just be the GUI. After Water is completed, we expect Cactus to grow into something like a 'match manager', allowing you to stress test the engine against humans, itself, or other engines. For now, it is a non-resizable square window and will remain as such until Water is complete.

# For Developers
Contributing guidelines, information on tests, formatting, and profiling can be found in [CONTRIBUTING.md](.github/CONTRIBUTING.md).
