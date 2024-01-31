const std = @import("std");
const log = std.log;
const builtin = @import("builtin");
const r = @cImport(@cInclude("raylib.h"));
const cova = @import("cova");
const config = @import("config.zig");
const screen = @import("screen.zig");
const RayGreetScreen = screen.RayGreetScreen;
const Vector2 = @import("util.zig").Vector2;

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

    // parse arguments
    const main_cmd = try setup_cmd.init(allocator, .{});
    defer main_cmd.deinit();

    var args_iter = try cova.ArgIteratorGeneric.init(allocator);
    defer args_iter.deinit();
    cova.parseArgs(&args_iter, CommandT, &main_cmd, stdout, .{}) catch |err| switch (err) {
        error.UsageHelpCalled => {},
        else => return err,
    };
    
    // if (builtin.mode == .Debug) try cova.utils.displayCmdInfo(CommandT, &main_cmd, allocator, &stdout);

    log.info("Reading configuration at {s}", .{config.CONFIG_FILE_PATH});
    const CONFIG = try config.parse_config(allocator);

    // initialize screen
    
    // std.debug.print("{}", .{@TypeOf(.{WINDOW_WIDTH, WINDOW_HEIGHT})});
    r.InitWindow(0, 0, @ptrCast(CONFIG.window_name));
    defer r.CloseWindow();
    r.SetTargetFPS(CONFIG.fps);
    const SCREEN_WIDTH = r.GetScreenWidth();
    const SCREEN_HEIGHT = r.GetScreenHeight();
    
    const screen_size: Vector2 = .{
        .x = @floatFromInt(SCREEN_WIDTH),
        .y = @floatFromInt(SCREEN_HEIGHT)
    };

    var input_user_screen = try screen.InputUserScreen.new(screen_size);

    const current_screen = RayGreetScreen{
        .input_user_screen = &input_user_screen,
    };

    while (!r.WindowShouldClose()) {
        r.BeginDrawing();
        try current_screen.draw();
        r.EndDrawing();
    }
}

test {
    const _config = @import("config.zig");
    _ = _config;
    std.testing.refAllDecls(@This());
}

