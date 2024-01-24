const std = @import("std");
const raySdk = @import("lib/raylib/src/build.zig");

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
    {
        // raylib: ff1eeafb950b5d7b8e5b25aa2ac1e8e87e353d1b
        {
            const raylib = try raySdk.addRaylib(b, target, optimize, .{
                .platform_drm = b.option(bool, "platform_drm", "Compile raylib in DRM mode") orelse false,
            });
	          exe.addIncludePath(.{ .path = "lib/raylib/src" });
	          exe.linkLibrary(raylib);
        }

        // cova
        {
            const cova_dep = b.dependency("cova", .{ .target = target });
            const cova_mod = cova_dep.module("cova");
            exe.root_module.addImport("cova", cova_mod);
        }
    }
    
    // run command ========================================
    {
        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }


    // test command ========================================
    {
        const exe_unit_tests = b.addTest(.{
            .root_source_file = .{ .path = "src/main.zig" },
            .target = target,
            .optimize = optimize,
        });

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_exe_unit_tests.step);
    }
}
