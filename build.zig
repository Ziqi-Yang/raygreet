const std = @import("std");
const raySdk = @import("lib/raylib/src/build.zig");

fn addDependencyModules(
    comp: *std.Build.Step.Compile,
    b: *std.Build,
    dep_name: []const u8,
    modules: []const []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    const dep = b.dependency(dep_name, .{ .target = target, .optimize = optimize });
    for (modules) |module_name| {
        const module = dep.module(module_name);
        comp.root_module.addImport(module_name, module);
    }
}

fn addDependencies(
    comp: *std.Build.Step.Compile,
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    raylib: *std.Build.Step.Compile
) !void {
    // raylib
    comp.addIncludePath(.{ .path = "lib/raylib/src" });
    comp.linkLibrary(raylib);

    try addDependencyModules(comp, b, "cova", &.{"cova"}, target, optimize);
    try addDependencyModules(comp, b, "greetd_ipc", &.{"greetd_ipc"}, target, optimize);
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "raygreet",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (exe.root_module.optimize != .Debug) {
        exe.root_module.strip = true;
    }

    b.installArtifact(exe);

    // dependencies ========================================
    // raylib: ff1eeafb950b5d7b8e5b25aa2ac1e8e87e353d1b
    const raylib = try raySdk.addRaylib(b, target, optimize, .{
        .platform_drm = b.option(bool, "platform_drm", "Compile raylib in DRM mode") orelse false,
    });
    
    try addDependencies(exe, b, target, optimize, raylib);

    // run command ========================================
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // test command ========================================
    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    try addDependencies(exe_unit_tests, b, target, optimize, raylib);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
