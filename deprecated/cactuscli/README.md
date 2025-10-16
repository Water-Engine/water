# Cactus
Cactus is a framework providing a gui, cli and a library for playing chess and developing utilities for it.  
It is designed to be lightweight and performant providing a flexible foundation for both developers and players.  
Cactus is written in rust and uses [raylib](https://www.raylib.com/index.html) for the gui.  

# Getting Started

> [!NOTE]
> Cactus project has not made a stable release yet, and is under active development.
> Code may change in backwards incompatible ways.

Cactus provides following packages:
- [`cactus-cli`](./cactus-cli/README.md) enables stress-testing of chess engines, offering multiple tournament formats and easy export of match results.
- [`cactus-gui`](./cactus-gui/README.md) allows you to play PvP, Bot vs Player, or Bot vs Bot matches, and provides tools for analyzing games.
- [`libcactus`](./libcactus/README.md) serves as the core library, powering both the CLI and GUI applications.  

## Installation Guide

### Using `cargo`
To directly install packages provided by `cactus` using `cargo` from Github run:
```
cargo install --git https://github.com/water-engine/cactus --path <package>
```

### Using `nix` package manager
`nix` users can follow the instructions below:
1. Add the project as a flake input to your system/home-manager flake:
```nix
# in flake.nix
{
  # other inputs ...
  inputs.cactus.url = "github:water-engine/cactus";
}
```
2. After passing your inputs parameters, you can install `cactus` by adding the following to your `environment.systemPackages` or `home.packages`:
```nix
# in your configuration.nix or home.nix
inputs.cactus.packages.${system}.default # Provides both the cli and gui
inputs.cactus.packages.${system}.cli # Provides the cli
inputs.cactus.packages.${system}.gui # Provides the gui
```

### Building from source
Check [Contributing.md](/.github/CONTRIBUTING.md#building-cactus-from-source) for a detailed guide on this.

## License
Distributed under AGPL-3.0-or-later - See [LICENSE](./LICENSE) and [ATTRIBUTIONS.md](./.github/ATTRIBUTIONS.md)
