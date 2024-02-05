// TODO, disable esc key (at the very end)
const std = @import("std");
const log = std.log;
const builtin = @import("builtin");
const r = @cImport(@cInclude("raylib.h"));
const cova = @import("cova");
const config = @import("config.zig");
const screen = @import("screen.zig");
const RayGreetScreen = screen.RayGreetScreen;
const Vector2 = @import("util.zig").Vector2;
const status = @import("status.zig");

const greetd_ipc = @import("greetd_ipc"); // TODO
const GreetdIPC = greetd_ipc.GreetdIPC;

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
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa_impl.deinit() == .leak) @panic("MEMORY LEAK");
    var arena_impl = std.heap.ArenaAllocator.init(gpa_impl.allocator());
    defer arena_impl.deinit();
    const arena = arena_impl.allocator();
    
    const stdout = std.io.getStdOut().writer();

    // parse arguments
    const main_cmd = try setup_cmd.init(arena, .{});
    defer main_cmd.deinit();

    var args_iter = try cova.ArgIteratorGeneric.init(arena);
    defer args_iter.deinit();
    cova.parseArgs(&args_iter, CommandT, &main_cmd, stdout, .{}) catch |err| switch (err) {
        error.UsageHelpCalled => {},
        else => return err,
    };
    
    // if (builtin.mode == .Debug) try cova.utils.displayCmdInfo(CommandT, &main_cmd, allocator, &stdout);
    log.info("Reading configuration at {s}", .{config.CONFIG_FILE_PATH});
    const CONFIG = try config.parse_config(arena);

    // initialize screen
    
    // std.debug.print("{}", .{@TypeOf(.{WINDOW_WIDTH, WINDOW_HEIGHT})});
    r.InitWindow(0, 0, @ptrCast(CONFIG.window_name));
    defer r.CloseWindow();
    r.SetTargetFPS(CONFIG.fps);
    
    screen.input_user_screen = try screen.InputUserScreen.new();
    screen.input_user_screen.init();

    status.current_screen = RayGreetScreen {
        .input_user_screen = &screen.input_user_screen,
    };

    while (!r.WindowShouldClose()) {
        handleKey();
        r.BeginDrawing();
        try status.current_screen.draw();
        r.EndDrawing();
    }
}

fn handleKey() void {
    const key = r.GetKeyPressed();
    // note: most condition pass, however, when you press 'a' and then 'alt', then
    // release 'alt' key, you still see the blink cursor.
    status.pressedKey = if (key != 0)  @intCast(key) else key: {
        if (status.pressedKey == null
                or (r.IsKeyUp(@intCast(status.pressedKey.?)))) {
            break :key null;
        } else {
            break :key status.pressedKey;
        }
    };
    switch (key) {
        // Raylib Bug: IsKeyPressed(r.KEY_CAPS_LOCK) doesn't work properly, so
        // handle keys using `r.GetKeyPressed`
        r.KEY_CAPS_LOCK => {
            status.capsLockOn = !status.capsLockOn;
            log.info("status.capsLockOn: {}\n", .{status.capsLockOn});
        },
        else => {}
    }
}

test {
    const _config = @import("config.zig");
    _ = _config;
    std.testing.refAllDecls(@This());
}

