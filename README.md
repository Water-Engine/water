# water
A chess engine, with the goal of being powered by some ML.

# Contributing
This project's source code and build system is designed such that it can be ran on any major platform assuming you have the correct tools installed. This project is compiled using the GNU Compiler Collection's g++ compiler, and formatting is done through clang-format. Building this repository on your own should be as simple as running `make`.

# Makefile Opts
- `all`: Build the project (default)
- `run`: Run the compiled program
- `clean`: Remove object files, dependency files, and binary
- `fmt`: Format all source and header files using clang-format
- `help`: Show this help message