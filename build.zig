const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    const mod = b.addModule("water", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "water",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "water", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    addRunStep(b, exe);
    addFmtStep(b);
    addLintStep(b);
    addClocStep(b);

    const test_step = b.step("test", "Run tests");
    addToTestStep(b, exe.root_module, test_step);
    addToTestStep(b, mod, test_step);
}

fn addRunStep(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn addToTestStep(b: *std.Build, module: *std.Build.Module, step: *std.Build.Step) void {
    const tests = b.addTest(.{
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);
    step.dependOn(&run_tests.step);
}

fn addLintStep(b: *std.Build) void {
    const lint_files = b.addSystemCommand(&[_][]const u8{
        "zig", "fmt", "--check", "src",
    });

    const lint_step = b.step(
        "lint",
        "Check formatting in all Zig source files",
    );
    lint_step.dependOn(&lint_files.step);
}

fn addFmtStep(b: *std.Build) void {
    const fmt_files = b.addSystemCommand(&[_][]const u8{
        "zig", "fmt", "src",
    });

    const fmt_step = b.step(
        "fmt",
        "Format all Zig source files",
    );
    fmt_step.dependOn(&fmt_files.step);
}

fn addClocStep(b: *std.Build) void {
    const cloc_src = b.addSystemCommand(&[_][]const u8{
        "cloc",
        "build.zig",
        "src",
        "scripts",
        "--not-match-f=(slider_bbs.zig|pretty_print.py)",
    });

    const cloc_step = b.step(
        "cloc",
        "Use cloc to count lines of code",
    );
    cloc_step.dependOn(&cloc_src.step);
}
