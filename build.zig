const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const urn_text =
        \\     ______
        \\    (%%%%%%%%%%%%)
        \\      )%%%%(
        \\    ,'<\\o=`.
        \\   (%%%%<_\\)%%%%)
        \\    `."/|%%.'
        \\      )\\\\(
        \\     /%%%%%%%%\\
        \\
    ;

    const urn = b.addSystemCommand(&.{"printf"});
    urn.addArgs(&.{
        b.fmt("{s}", .{urn_text}),
    });
    const urn_step = b.step("urn", "You made a typo");
    urn_step.dependOn(&urn.step);

    const clean = b.addSystemCommand(&.{"rm"});
    clean.addArgs(&.{ "-rf", "zig-out", "zig-cache" });
    const clean_step = b.step(
        "clean",
        "Remove output and cache (shouldn't be required, just to save space)",
    );
    clean_step.dependOn(&clean.step);

    const llvm = !(b.host.result.cpu.arch == .x86_64);

    const exe = b.addExecutable(.{
        .name = "nabu",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .use_llvm = llvm,
        .use_lld = llvm,
    });

    const pretty = b.dependency("pretty", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("pretty", pretty.module("pretty"));

    const ziglyph = b.dependency("ziglyph", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("ziglyph", ziglyph.module("ziglyph"));

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .use_llvm = llvm,
        .use_lld = llvm,
    });
    exe_unit_tests.root_module.addImport("pretty", pretty.module("pretty"));

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
