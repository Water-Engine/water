const std = @import("std");
const builtin = @import("builtin");

const bingshan = @embedFile("assets/nnue/bingshan.nnue");

const version: []const u8 = "1.0.0";

comptime {
    const current_zig = builtin.zig_version;
    const required_zig = std.SemanticVersion.parse("0.15.2") catch unreachable;

    if (current_zig.order(required_zig) != .eq) {
        const error_message =
            \\Sorry, it looks like your version of Zig isn't right. :-(
            \\
            \\Water requires zig version {f}
            \\
            \\https://ziglang.org/download/
            \\
        ;
        @compileError(std.fmt.comptimePrint(error_message, .{required_zig}));
    }
}

/// Little endian, 64-bit systems are required
const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },

    .{ .cpu_arch = .x86_64, .os_tag = .linux },
    .{ .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .cpu_arch = .riscv64, .os_tag = .linux },
    .{ .cpu_arch = .powerpc64le, .os_tag = .linux },
    .{ .cpu_arch = .loongarch64, .os_tag = .linux },

    .{ .cpu_arch = .aarch64, .os_tag = .freebsd },
    .{ .cpu_arch = .powerpc64le, .os_tag = .freebsd },
    .{ .cpu_arch = .riscv64, .os_tag = .freebsd },
    .{ .cpu_arch = .x86_64, .os_tag = .freebsd },

    .{ .cpu_arch = .aarch64, .os_tag = .netbsd },
    .{ .cpu_arch = .x86_64, .os_tag = .netbsd },

    .{ .cpu_arch = .x86_64, .os_tag = .windows },
    .{ .cpu_arch = .aarch64, .os_tag = .windows },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    const engine, const mod = artifacts(
        b,
        target,
        optimize,
    );

    // Neural nets will be comptime only, and are restricted to the executables
    const nets = b.addOptions();
    nets.addOption([]const u8, "bingshan", bingshan);
    engine.root_module.addOptions("nets", nets);
    b.installArtifact(engine);

    // Artifacts
    addRunStep(b, engine, "run", "Run the engine");
    addPerftStep(b, mod);
    addBenchStep(b, mod);
    addSearchStep(b, mod, nets);

    // Utils
    addFmtStep(b);
    addLintStep(b);
    addClocStep(b);
    addDocsStep(b, mod);
    addCleanStep(b);

    // Testing
    const test_step = b.step("test", "Run tests");
    addToTestStep(b, engine.root_module, test_step);
    addToTestStep(b, mod, test_step);

    // Packaging
    const package_step = b.step("package", "Build the artifacts for packaging");
    package_step.dependOn(test_step);

    const legal = b.option(
        bool,
        "legal",
        "Copy core project information into package directories",
    ) orelse false;

    for (targets) |t| {
        const pack_engine, _ = artifacts(
            b,
            b.resolveTargetQuery(t),
            .ReleaseFast,
        );

        pack_engine.root_module.addOptions("nets", nets);
        pack_engine.root_module.strip = true;
        pack_engine.out_filename = blk: {
            if (target.result.os.tag == .windows) {
                break :blk try std.fmt.allocPrint(
                    b.allocator,
                    "{s}-{s}.exe",
                    .{ pack_engine.name, version },
                );
            } else {
                break :blk try std.fmt.allocPrint(
                    b.allocator,
                    "{s}-{s}",
                    .{ pack_engine.name, version },
                );
            }
        };

        const package_options: std.Build.Step.InstallArtifact.Options = .{
            .dest_dir = .{
                .override = .{
                    .custom = try t.zigTriple(b.allocator),
                },
            },
        };

        package_step.dependOn(&b.addInstallArtifact(
            pack_engine,
            package_options,
        ).step);

        if (legal) {
            const out_dirname = try std.fmt.allocPrint(
                b.allocator,
                "zig-out/{s}",
                .{package_options.dest_dir.override.custom},
            );
            try std.fs.cwd().makePath(out_dirname);
            var out_dir = try std.fs.cwd().openDir(out_dirname, .{});
            defer out_dir.close();

            try std.fs.cwd().copyFile("LICENSE", out_dir, "LICENSE", .{});
            try std.fs.cwd().copyFile("README.md", out_dir, "README.md", .{});
            try std.fs.cwd().copyFile(".github/AUTHORS.md", out_dir, "AUTHORS.md", .{});
            try std.fs.cwd().copyFile(".github/CHANGELOG.md", out_dir, "CHANGELOG.md", .{});
        }
    }
}

fn artifacts(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) struct {
    *std.Build.Step.Compile,
    *std.Build.Module,
} {
    const water = b.addModule("water", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const engine = b.addExecutable(.{
        .name = "water",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "water", .module = water },
            },
        }),
    });

    return .{ engine, water };
}

fn addRunStep(b: *std.Build, exe: *std.Build.Step.Compile, name: []const u8, desc: []const u8) void {
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(name, desc);
    run_step.dependOn(&run_cmd.step);
}

fn addPerftStep(b: *std.Build, module: *std.Build.Module) void {
    const perft_exe = b.addExecutable(.{
        .name = "perft",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/water/perft.zig"),
            .target = module.resolved_target,
            .optimize = module.optimize,
            .imports = &.{
                .{ .name = "water", .module = module },
            },
        }),
    });

    const run_perft = b.addRunArtifact(perft_exe);
    run_perft.step.dependOn(b.getInstallStep());

    const perft_step = b.step("perft", "Run the comprehensive perft suite");
    perft_step.dependOn(&run_perft.step);
    perft_step.dependOn(&b.addInstallArtifact(perft_exe, .{}).step);
}

fn addBenchStep(b: *std.Build, module: *std.Build.Module) void {
    const bench_exe = b.addExecutable(.{
        .name = "bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/water/bench.zig"),
            .target = module.resolved_target,
            .optimize = module.optimize,
            .imports = &.{
                .{ .name = "water", .module = module },
            },
        }),
    });

    const run_bench = b.addRunArtifact(bench_exe);
    run_bench.step.dependOn(b.getInstallStep());

    const bench_step = b.step("bench", "Run the movegen benchmarking suite");
    bench_step.dependOn(&run_bench.step);
    bench_step.dependOn(&b.addInstallArtifact(bench_exe, .{}).step);
}

fn addSearchStep(b: *std.Build, module: *std.Build.Module, nets: *std.Build.Step.Options) void {
    const bench_exe = b.addExecutable(.{
        .name = "search",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/engine/bench.zig"),
            .target = module.resolved_target,
            .optimize = module.optimize,
            .imports = &.{
                .{ .name = "water", .module = module },
            },
        }),
    });
    bench_exe.root_module.addOptions("nets", nets);

    const run_bench = b.addRunArtifact(bench_exe);
    run_bench.step.dependOn(b.getInstallStep());

    const bench_step = b.step("search", "Run the search benchmarking suite");
    bench_step.dependOn(&run_bench.step);
    bench_step.dependOn(&b.addInstallArtifact(bench_exe, .{}).step);
}

fn addToTestStep(b: *std.Build, module: *std.Build.Module, step: *std.Build.Step) void {
    const tests = b.addTest(.{
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);
    step.dependOn(&run_tests.step);
}

fn addLintStep(b: *std.Build) void {
    const lint_files = b.addFmt(.{ .paths = &.{"src"}, .check = true });
    const lint_step = b.step("lint", "Check formatting in all Zig source files");
    lint_step.dependOn(&lint_files.step);
}

fn addFmtStep(b: *std.Build) void {
    const fmt_files = b.addFmt(.{ .paths = &.{"src"} });
    const fmt_step = b.step("fmt", "Format all Zig source files");
    fmt_step.dependOn(&fmt_files.step);
}

fn addClocStep(b: *std.Build) void {
    const cloc_src = b.addSystemCommand(&.{
        "cloc",
        "build.zig",
        "src",
        "--not-match-f=(slider_bbs.zig)",
    });

    const cloc_step = b.step("cloc", "Count total lines of Zig source code");
    cloc_step.dependOn(&cloc_src.step);
}

fn addDocsStep(b: *std.Build, module: *std.Build.Module) void {
    const lib = b.addObject(.{
        .name = "water",
        .root_module = module,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);
}

fn addCleanStep(b: *std.Build) void {
    const clean_step = b.step("clean", "Clean up emitted artifacts");
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
}
