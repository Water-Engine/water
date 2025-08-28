# water [![C++20](https://img.shields.io/badge/C%2B%2B-20-blue?logo=c%2B%2B&logoColor=white)](https://en.cppreference.com/w/cpp/20.html) [![Rust](https://img.shields.io/static/v1?label=Rust&message=2024&labelColor=gray&color=F1592A)](https://github.com/rust-lang/rust) [![License](https://img.shields.io/github/license/trevorswan11/water)](LICENSE) [![LOC](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/trevorswan11/water/loc/badge.json)](https://github.com/trevorswan11/water/actions/workflows/loc.yml) [![Last commit](https://img.shields.io/github/last-commit/trevorswan11/water)](https://github.com/trevorswan11/water) [![Formatting](https://github.com/trevorswan11/water/actions/workflows/format.yml/badge.svg)](https://github.com/trevorswan11/water/actions/workflows/format.yml) [![CI](https://github.com/trevorswan11/water/actions/workflows/ci.yml/badge.svg)](https://github.com/trevorswan11/water/actions/workflows/ci.yml)
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

# Testing

## Water
This project uses unit tests to verify the correctness of the engine’s foundation and functionality. To run tests, simply call `make test`. The Catch2 framework is used, and the amalgamated files are compiled directly into the test executable, resulting in longer initial build times. 

## Cactus
There are no tests for the GUI.

# Formatting

## Water
`clang-format` is used for formatting on this side of the project, but we have also decided on custom formatting rules and naming conventions for this project.
- All local variables and custom exceptions should be written in snake_case
- All constants should be written as CONSTANT_VALUE and should be at the top of their files
- Class member variables should be written as m_PascalCase
- Struct member variables should be written in PascalCase
- All functions should be written in snake_case
- Enum/Class names and enum variants should be written in PascalCase
- Enum classes should be preferred over enums
- All `if/for/while` code blocks should be wrapped in { curly braces }
- Switch statements and their cases should be aligned on the same column
- Class member order: private fields -> private constructors -> private functions -> public fields -> public constructors -> public functions
- Structs should be used as data structures and should not have many member functions
- The first include in every cpp file should be `#include <pch.hpp>`
- All includes should be logically grouped
- Never use `using namespace std`
- If you need a std_lib include, place them in `pch.hpp` under the corresponding category, do not include them in any other hpp or cpp files
- Do not abuse ternary operators, though there are plenty of situations where their use is acceptable
- Explanatory variable and function names should be preferred to comments and doc-comments

## Cactus
`cargo fmt` is used for formatting on this side of the project. No custom formatting rules apply to written Rust code. The only requirement is that it aligns with the standard enforcing by cargo.

# Contributing
This project's source code and build system is designed such that it can be run on any major platform assuming you have the correct tools installed. To confirm cross-platform behavior, GitHub Actions runs the project's build and test system on Windows, Linux, and macOS. This project is compiled using the GNU Compiler Collection's g++ compiler, and formatting is done through clang-format. Building this repository on your own should be as simple as running `make`. Please follow the project's formatting guides, and call `make fmt` on code that you contribute. Please do not push AI-generated code. This project should be a learning experience, not a copy-paste speedrun. Additional learning resources can be found in [READING.md](READING.md). If you aren't a main contributor, please open a pull request against the main branch when contributing.

# Profiling
Water uses a profiling system that allows you to track wall time of called functions and entered scopes. You can use macros found in `core.hpp` to profile functions and scopes. This is an opt-in system, so you must use `PROFILE_FUNCTION()` and `PROFILE_SCOPE(name)` wherever desired. The data outputted by these macros can be found in `Water-Main.json`, and you can analyze it by going to `chrome://tracing` in a chromium-based browser (i.e. Edge, Google Chrome). Profiling runs on a separate thread, but it does take up CPU time. To maximize performance, profiling is disabled when building and running the `dist` configuration. You can configure the project to always enable profiling by uncommenting `// #define PROFILE` in `core.hpp`. This is not recommended, though.