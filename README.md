# water [![C++20](https://img.shields.io/badge/C%2B%2B-20-blue?logo=c%2B%2B&logoColor=white)](https://en.cppreference.com/w/cpp/20.html) [![License](https://img.shields.io/github/license/Water-Engine/water)](LICENSE) [![LOC](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/Water-Engine/water/loc/.github/loc_badge.json)](https://github.com/Water-Engine/water/actions/workflows/loc.yml) [![Last commit](https://img.shields.io/github/last-commit/Water-Engine/water)](https://github.com/Water-Engine/water) [![Formatting](https://github.com/Water-Engine/water/actions/workflows/format.yml/badge.svg)](https://github.com/Water-Engine/water/actions/workflows/format.yml) [![CI](https://github.com/Water-Engine/water/actions/workflows/ci.yml/badge.svg)](https://github.com/Water-Engine/water/actions/workflows/ci.yml)
A chess engine written in C++, powered by magic bitboard and neural networks.

# Getting Started
For a quick build of the project, run:
```shell
git clone https://github.com/Water-Engine/water.git
cd water
make -j4 run
```

# Dependencies
- g++ with C++20
- GNU Make
- Clang-format
- [Catch2](https://github.com/catchorg/Catch2) (included in this repository)
- [cloc](https://github.com/AlDanial/cloc) (for cloc make target > optional)
- [python](https://www.python.org/downloads/) for script running

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
- `help`: Print this help menu

# For Developers
Contributing guidelines, information on tests, formatting, and profiling can be found in [CONTRIBUTING.md](.github/CONTRIBUTING.md).
