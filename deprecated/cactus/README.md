# cactus [![Rust](https://img.shields.io/static/v1?label=Rust&message=2024&labelColor=gray&color=F1592A)](https://github.com/rust-lang/rust) [![License](https://img.shields.io/github/license/Water-Engine/cactus)](LICENSE) [![LOC](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/Water-Engine/cactus/loc/.github/loc_badge.json)](https://github.com/Water-Engine/cactus/actions/workflows/loc.yml) [![Last commit](https://img.shields.io/github/last-commit/Water-Engine/cactus)](https://github.com/Water-Engine/cactus) [![Formatting](https://github.com/Water-Engine/cactus/actions/workflows/format.yml/badge.svg)](https://github.com/Water-Engine/cactus/actions/workflows/format.yml)
A chess client written in Rust.

# Getting Started
To build and run cactus, install the rust toolchain and run:
```shell
git clone https://github.com/Water-Engine/cactus.git
cd cactus
make run-release
```
To run the gui with the water engine (or any other external engine), its path must be given as a command line arg. The general format is `<binary> [white "path_to_engine"] [black "path_to_engine"]`. If the white or black options are not given or the paths are not valid, then it will default to a normal player.

Examples:
```shell
cargo run --release -- white path/to/water.exe
cargo run --release -- white path/to/water.exe black path/to/stockfish.exe
```

# Dependencies
- [Cargo](https://doc.rust-lang.org/beta/book/ch01-01-installation.html)
- GNU Make ()
- [cloc](https://github.com/AlDanial/cloc) (for cloc make target > optional)

# Building cactus
The project's build system uses cargo with make existing as a helper. Below is a list of targets with their requirements where applicable:

## Build Specific Targets
- `default`: Builds the release configuration (default)
- `install`: Alias for release (to be updated)
- `all`: Builds all optimization configurations for the project (release, and debug)
- `release`: Builds the project with all optimizations
- `debug`: Builds the project with no optimization, defining both PROFILE and DEBUG
- `run`: Alias for run-release
- `run-release`: Build and run the release binary
- `run-debug`: Build and run the debug binary
- `fmt`: Format all Rust source and header files using `cargo fmt`
- `fmt-check`: Validates Rust formatting rules without altering project files
- `clean`: Remove object files, dependency files, and binaries

## General Targets
- `cloc`: Count the lines of code in the project's relevant directories
- `help`: Print this help menu

# Motivation
Cactus is a minimal rust-based chess gui built for playing basic games against chess engines. It was created with the intent of being the engine itself, but a lack of understanding of chess engine mechanics resulted in a dead project. As a result, it has been stripped to just be the GUI. After Water is completed, we expect Cactus to grow into something like a 'match manager', allowing you to stress test the engine against humans, itself, or other engines. For now, it is a non-resizable square window and will remain as such until Water is complete.

# For Developers
Contributing guidelines, information on tests, formatting, and profiling can be found in [CONTRIBUTING.md](.github/CONTRIBUTING.md).
