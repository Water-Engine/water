#List justfile commands
list:
    @just --list

# =====> Aliases <===== #
alias bc := build-cli
alias bg := build-gui
alias bl := build-lib
alias ba := build-all
alias rc := run-cli
alias rg := run-gui
alias cln := clean
alias fc := fmt-check

# =====> Package Builders <===== #
#Build cactus cli
build-cli +args='':
    cargo build --package cactus-cli {{args}}
#Build cactus gui
build-gui +args='':
    cargo build --package cactus-gui {{args}}
#Build libcactus
build-lib +args='':
    cargo build --package libcactus {{args}}
#Build all packages
build-all +args='':
    cargo build {{args}}

# =====> Program Runners <===== #
# Run CLI with arguments
run-cli +args='':
    mkdir -p test/cli && cd test/cli && cargo run --package cactus-cli --release -- {{args}}
# Run GUI
run-gui:
    cargo run --package cactus-gui --release

# =====> Utilities <===== #
#Clean all build artifacts
clean:
    cargo clean
# Check formatting
fmt-check:
    cargo fmt --all --check
# Apply formatting
fmt:
    cargo fmt --all

