# water [![C++20](https://img.shields.io/badge/C%2B%2B-20-blue?logo=c%2B%2B&logoColor=white)](https://en.cppreference.com/w/cpp/20.html) [![License](https://img.shields.io/github/license/trevorswan11/water)](LICENSE) [![Last commit](https://img.shields.io/github/last-commit/trevorswan11/water)](https://github.com/trevorswan11/water) [![Formatting](https://github.com/trevorswan11/water/actions/workflows/format.yml/badge.svg)](https://github.com/trevorswan11/water/actions/workflows/format.yml) [![CI](https://github.com/trevorswan11/water/actions/workflows/ci.yml/badge.svg)](https://github.com/trevorswan11/water/actions/workflows/ci.yml)
A chess engine written in C++, powered by NNUE and magic bitboards.

# Getting Started
For a quick build of the project, run:
```shell
git clone https://github.com/trevorswan11/water.git
cd water
make -j4 run
```

# Dependencies
- g++ with C++20
- GNU Make
- Clang-format
- Catch2 (included in this repository)

# License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

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
- `fmt-check`: Validates formatting rules without altering project files

# Testing
This project uses unit tests to verify the correctness of the engine’s foundation and functionality. To run tests, simply call `make test`. The [Catch2](https://github.com/catchorg/Catch2) framework is used, and the amalgamated files are compiled directly into the test executable, resulting in longer initial build times.  

# Formatting
`clang-format` is used for formatting in this project, but we have also decided on custom formatting rules and naming conventions for this project.
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

# Contributing
This project's source code and build system is designed such that it can be run on any major platform assuming you have the correct tools installed. To confirm cross-platform behavior, GitHub Actions runs the project's build and test system on Windows, Linux, and macOS. This project is compiled using the GNU Compiler Collection's g++ compiler, and formatting is done through clang-format. Building this repository on your own should be as simple as running `make`. Please follow the project's formatting guides, and call `make fmt` on code that you contribute. Please do not push AI-generated code. This project should be a learning experience, not a copy-paste speedrun. Additional learning resources can be found in [READING.md](READING.md). If you aren't a main contributor, please open a pull request against the main branch when contributing.

# Profiling
Water uses a profiling system that allows you to track wall time of called functions and entered scopes. You can use macros found in `core.hpp` to profile functions and scopes. This is an opt-in system, so you must use `PROFILE_FUNCTION()` and `PROFILE_SCOPE(name)` wherever desired. The data outputted by these macros can be found in `Water-Main.json`, and you can analyze it by going to `chrome://tracing` in a chromium-based browser (i.e. Edge, Google Chrome). Profiling runs on a separate thread, but it does take up CPU time. To maximize performance, profiling is disabled when building and running the `dist` configuration. You can configure the project to always enable profiling by uncommenting `// #define PROFILE` in `core.hpp`. This is not recommended, though.