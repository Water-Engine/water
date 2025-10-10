# water [![Zig](https://img.shields.io/badge/zig-0.15.1-orange)](https://ziglang.org/) [![License](https://img.shields.io/github/license/Water-Engine/water)](LICENSE) [![Last commit](https://img.shields.io/github/last-commit/Water-Engine/water)](https://github.com/Water-Engine/water) [![Formatting](https://github.com/Water-Engine/water/actions/workflows/format.yml/badge.svg)](https://github.com/Water-Engine/water/actions/workflows/format.yml) [![CI](https://github.com/Water-Engine/water/actions/workflows/ci.yml/badge.svg)](https://github.com/Water-Engine/water/actions/workflows/ci.yml)

<p align="center">
  <img src="/.github/resources/logo.png" alt="water logo" width="250"/>
</p>

<p align="center">
  A zero-dependency chess library written in Zig.
</p>

# Goals
Water aims to provide a performant chess engine library allowing users to easily architect chess engines by providing a core library and search management scheme.

The water engine itself is crafted using this library, with the goals of making:
- An iterative search engine with Alpha-Beta Pruning, Quiescence, etc.
- A neural network-powered engine using NNUE

# Getting Started
For a quick build of the project, simply run `zig build run --release`.

_Note: The engine communicates through the UCI protocol. You can read more about the standard [here](https://gist.github.com/DOBRO/2592c6dad754ba67e6dcaec8c90165bf)._

## Build Tools
- [Zig 0.15.1](https://ziglang.org/download/) - older versions _will not_ work due to 'Writergate'
- [cloc](https://github.com/AlDanial/cloc) for the cloc step (optional)

## All Build Steps
| **Step**    | Description                                                                           |
|:------------|:--------------------------------------------------------------------------------------|
| `build`     | Builds `water`. Pass `--release` for ReleaseFast.                                     |
| `run`       | Build and run `water`. Pass `--release` for ReleaseFast.                              |
| `perft`    | Run the perft suite. Running with `--release` is highly recommended.                   |
| `bench`    | Run the perft benchmarking suite. Running with `--release` is highly recommended.      |
| `search`   | Run the search benchmarking suite. Running with `--release` is highly recommended.     |
| `test`      | Run all unit tests.                                                                   |
| `lint`      | Checks formatting of all source files excluding `build.zig`.                          |
| `fmt`       | Format all source code excluding `build.zig`.                                         |
| `cloc`      | Count the total lines of zig code. Requires [cloc](https://github.com/AlDanial/cloc). |

The `perft`, `bench`, and `search` commands are all ephemeral by default, but you can install the binary by appending `-Dephemeral=false` to your build command.

## Adding Water to Your Project
To add water as a dependency to your project, simply run `zig fetch --save git+https://github.com/Water-Engine/water`. This will add water as a dependency to your `build.zig.zon` file.

You'll then need to explicitly add it as a module in `build.zig`, which might looks like:

```zig
const exe = b.addExecutable(.{
    .name = "foo",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),

        .target = target,
        .optimize = optimize,

        .imports = &.{
            .{
                .name = "water",
                .module = b.dependency("water", .{}).module("water"),
            },
        },
    }),
});
```

To confirm the dependency was added successfully, try this out in `main.zig`:

```zig
const std = @import("std");
const water = @import("water");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var board = try water.Board.init(allocator, .{});
    defer board.deinit();
    const diagram = try water.uci.uciBoardDiagram(board, .{});
    defer allocator.free(diagram);
    std.debug.print("{s}", .{diagram});
}
```

# Contributing
Contributors are always welcome! As this project progresses and the engine improves, it will become increasingly difficult for a single developer to make meaningful improvements or address bugs in a timely manner. Checkout [CONTRIBUTING.md](.github/CONTRIBUTING.md) for the project's guidelines.

# Credits
Water could not be where it is today without the formative work done by experienced developers in the past. Core references used during development include:
- [chess-library](https://github.com/Disservin/chess-library) inspired the of rewrite to zig and served as a core pillar for ideas and verifying behavior in the core library.
- The [Chess Programming Wiki](https://www.chessprogramming.org/) for obvious reasons, but especially for their explanation and code examples for [NNUE](https://www.chessprogramming.org/NNUE)
- The [Avalanche](https://github.com/SnowballSH/Avalanche) chess engine which is dubbed 'the first and strongest UCI chess engine written in zig' for providing a huge source of motivation for improvement. The transposition table and classical search/evaluation algorithms are heavily inspired by this project. The neural networks from this project are currently used in the engine.
- The [Fathom](https://github.com/basil00/Fathom) library which was used as a reference for the included syzygy suite. 
- The legendary [Stockfish](https://github.com/official-stockfish/Stockfish) engine which served as an invaluable resource through all steps of the development process.
