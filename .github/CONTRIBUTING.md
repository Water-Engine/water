# Contributing Overview
This project's source code and build system is designed such that it can be run on any major platform assuming you have the correct tools installed. To confirm cross-platform behavior, GitHub Actions runs the project's build and test system on Windows, Linux, and macOS. This project is compiled using the GNU Compiler Collection's g++ compiler, and formatting is done through clang-format. Building this repository on your own should be as simple as running `make`. Please follow the project's formatting guides, and call `make fmt` on code that you wish to contribute. Please do not push AI-generated code. This project should be a learning experience, not a copy-paste speedrun. Additional learning resources can be found in [READING.md](READING.md). All code should be submitted to main via pull request, and your username can be added to `AUTHORS.md` upon merge.

Never commit code to the `loc` branch. It is unprotected but volatile. GH actions will reset this branch every time main is updated, so anything that shouldn't be there will be lost to the void...

# Formatting
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

# Testing
This project uses unit tests to verify the correctness of the engine’s foundation and functionality. To run tests, simply call `make test`. The Catch2 framework is used, and the amalgamated files are compiled directly into the test executable, resulting in longer initial build times. 

# Profiling
Water uses a profiling system that allows you to track wall time of called functions and entered scopes. You can use macros found in `core.hpp` to profile functions and scopes. This is an opt-in system, so you must use `PROFILE_FUNCTION()` and `PROFILE_SCOPE(name)` wherever desired. The data outputted by these macros can be found in `Water-Main.json`, and you can analyze it by going to `chrome://tracing` in a chromium-based browser (i.e. Edge, Google Chrome). Profiling runs on a separate thread, but it does take up CPU time. To maximize performance, profiling is disabled when building and running the `dist` configuration. You can configure the project to always enable profiling by uncommenting `// #define PROFILE` in `core.hpp`. This is not recommended, though.

Due to the shear amount of operations happening every few milliseconds, profiling is disabled at all optimization levels. This means that the `debug` configuration is the only option that builds with the profiler. 