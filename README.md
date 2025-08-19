# water [![C++20](https://img.shields.io/badge/C%2B%2B-20-blue?logo=c%2B%2B&logoColor=white)](https://en.cppreference.com/w/cpp/20.html) [![License](https://img.shields.io/github/license/trevorswan11/water)](LICENSE) [![Last commit](https://img.shields.io/github/last-commit/trevorswan11/water)](https://github.com/trevorswan11/water) [![CI](https://github.com/trevorswan11/water/actions/workflows/ci.yml/badge.svg)](https://github.com/trevorswan11/water/actions/workflows/ci.yml)
A chess engine written in C++, powered by NNUE and magic bitboards.

# Building water
The project's build system uses C++20 and GNU Make, and it is recommended that you run make with the flag `-j4` to run batch jobs. The following targets are supported:
- `default`: Builds the release configuration (default)
- `install`: Builds the dist config (to be updated)
- `all`: Builds all optimization configurations for the project (dist, release, and debug)
- `dist`: Builds the project with maximum optimization and disabled profiling
- `release`: Builds the project with slightly fewer optimizations and no DEBUG define
- `debug`: Builds the project with no optimization, defining both PROFILE and DEBUG
- `test`: Run the project's unit tests
- `run`: Build and run the release binary
- `run-dist`: Build and run the dist binary
- `run-release`: Build and run the release binary
- `run-debug`: Build and run the debug binary
- `clean`: Remove object files, dependency files, and binary
- `fmt`: Format all source and header files using clang-format

# Testing
This project uses unit tests to verify behavior of the engine's foundation and behavior. To run tests, simply call `make test`. The [Catch2](https://github.com/catchorg/Catch2) framework is used, and the amalgamated files are compiled directly into the test executable, resulting in longer initial build times.  

# Formatting
`clang-format` is used for formatting in this project, but I have also decided on custom formatting rules and naming conventions for this project.
- All local variables should be written in snake_case
- All constants should be written as CONSTANT_VALUE
- Member variables should be written in m_PascalCase
- Enum/Class names and enum variants should be written in PascalCase
- All `if/for/while` code blocks should be wrapped in { curly braces }

# Contributing
This project's source code and build system is designed such that it can be ran on any major platform assuming you have the correct tools installed. This project is compiled using the GNU Compiler Collection's g++ compiler, and formatting is done through clang-format. Building this repository on your own should be as simple as running `make`.