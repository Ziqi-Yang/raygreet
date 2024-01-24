// src/main.zig
const std = @import("std");
const log = std.log;
const builtin = @import("builtin");
const r = @cImport(@cInclude("raylib.h"));
const cova = @import("cova");

const WINDOW_NAME = "RayGreet";
const FPS = 60;

// override default log settings
pub const std_options = struct {
    pub const log_level = .debug;
};

// custom command line argument struct
const CommandT = cova.Command.Custom(.{ 
    .global_help_prefix = "RayGreet",
});

// command line arguments
const setup_cmd: CommandT = .{
    .name = "raygreet",
    .description = "A raylib greeter for greetd.",
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("MEMORY LEAK");
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const stdout = std.io.getStdOut().writer();

    const main_cmd = try setup_cmd.init(allocator, .{});
    defer main_cmd.deinit();
    
    var args_iter = try cova.ArgIteratorGeneric.init(allocator);
    defer args_iter.deinit();
    cova.parseArgs(&args_iter, CommandT, &main_cmd, stdout, .{}) catch |err| switch (err) {
        error.UsageHelpCalled => {},
        else => return err,
    };
    
    // if (builtin.mode == .Debug) try cova.utils.displayCmdInfo(CommandT, &main_cmd, allocator, &stdout);

    // initialize screen
    r.InitWindow(r.GetScreenWidth(), r.GetScreenHeight(), WINDOW_NAME);
    r.SetTargetFPS(60);
    defer r.CloseWindow();

    while (!r.WindowShouldClose()) {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        {
            r.DrawText("El Psy Kongaroo", 40, 40, 40, r.GRAY);
        }
        r.EndDrawing();
    }
}
