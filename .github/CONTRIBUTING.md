# Contributing Overview
Zig makes it easy to cross-compile code. The main requirement for any submitted code is that it must fully pass the os matrix CI tests. Code that is written such that it specifically targets or excludes a specific operating system or architecture will be rejected unless it is the only way to clear a hurdle or specific performance issue.

# Formatting
Please ensure all code is formatted according to zig's builtin formatter. PRs containing code that is not formatted will be sent back for changes until `zig build lint` runs without error. You can format the relevant code with `zig build fmt`.

# Testing
Tests should be written for anything that has considerable weight. This is a subjective measurement. If you believe that something is volatile (changes to a related system will break behavior) then a test should be written. That being said, if a block of code is tested by another test in the codebase, you need to not worry about writing a specific test for it. You also need not concern yourself with code that is practically infallible due to compiler intrinsics, dead-simple functions, etc.

# Benchmarking
If you would like to submit benchmark information for perft or the engine itself, please be as specific as possible regarding your findings. This should include, but not be limited to: hardware/architecture, os, multi-threadedness, and the followed benchmarking procedure.

As the project progresses, I hope to conjure up a standard benchmarking procedure, but until then, use your best judgement.

# Updating Dependencies
As zig progresses, dependencies may require updates. When needed, you can update the dependency hashes by running the following:

```sh
zig fetch --save=sokol git+https://github.com/floooh/sokol-zig.git
```