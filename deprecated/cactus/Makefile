RUST_OUT := target

# ================ BUILD TARGETS ================

default: release
install: release
all: debug release

debug:
	@cargo build

release:
	@cargo build --release

# ================ RUN TARGETS ================

run: run-release
run-debug:
	@cargo run

run-release:
	@cargo run --release

clean:
ifeq ($(OS),Windows_NT)
	@if exist "$(RUST_OUT)" rmdir /S /Q "$(RUST_OUT)"
else
	@rm -rf $(RUST_OUT)
endif

# ================ FORMATTING / QOL ================

fmt: fmt
fmt-check: fmt-check

fmt:
	@cargo fmt

fmt-check:
	@cargo fmt -- --check

cloc:
	@cloc Makefile src


# ================ HELP ME ================

help: 
	@printf "\
\n\
To build and run the project, type:\n\
\n\
make [target] [options]\n\
\n\
Build Specific Targets:\n\
\n\
default           > Builds the release configuration (default)\n\
install           > Alias for release (to be updated)\n\
all               > Builds all optimization configurations (release, debug)\n\
release           > All optimizations enabled\n\
debug             > No optimization and enabled debug symbols\n\
run               > Alias for run-release\n\
run-release       > Build and run the release binary\n\
run-debug         > Build and run the debug binary\n\
fmt               > Format all Rust source and header files with cargo\n\
fmt-check         > Check formatting rules without modifying files\n\
clean             > Remove object files, dependency files, and binaries\n\
\n\
General Targets:\n\
\n\
cloc              > Count lines of code in relevant directories\n\
help              > Print this help menu\n\
"

.PHONY: default install all release debug run run-release run-debug \
		clean fmt fmt-check cloc help
