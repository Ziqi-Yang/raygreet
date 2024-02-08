const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const Vector2 = @import("../util.zig").Vector2;
const Cursor = @import("../component/cursor.zig").Cursor;
const CursorOption = @import("../config.zig").CursorOption;
const InputTextField = @import("../component/input_text_field.zig").InputTextField;

pub const MainScreen = struct {
    const Self = @This();
    
    screen_size: Vector2,
    input_text_field: InputTextField,

    pub fn new() !Self {
        if (!r.IsWindowReady()) return error.WindowNotInitialized;
        
        const SCREEN_WIDTH: f16 = @floatFromInt(@as(u16, @intCast(r.GetScreenWidth())));
        const SCREEN_HEIGHT: f16 = @floatFromInt(@as(u16, @intCast(r.GetScreenHeight())));
        const box_size: Vector2 = .{ SCREEN_WIDTH * 0.7, SCREEN_HEIGHT / 2};
        return .{
            .screen_size = .{ SCREEN_WIDTH, SCREEN_HEIGHT },
            // we don't pass enter_key_press_func() in `InputTextField.new` since the function
            // pointer it returned points to the old `screen` (if we define a var), not the one copied
            // in the `return` caluse. (stack lifetime issue)
            .input_text_field = try InputTextField.new(box_size, null)
        };
    }

    pub fn init(self: *Self) void {
        self.input_text_field.func_enter_key_down = self.enter_key_press_func();
    }

    pub fn draw(self: *Self) !void {
        r.ClearBackground(r.RAYWHITE);
        self.input_text_field.draw(Vector2 { self.screen_size[0] * 0.15 , self.screen_size[1] / 4 });
    }

    pub inline fn enter_key_press_func(self: *Self) *const fn () void {
        return (struct {
            var screen: *Self = undefined;
            
            pub fn init(itf: *Self) *const @TypeOf(run) {
                screen = itf;
                return &run;
            }

            fn run() void {
                std.debug.print("ENTER: {any}\n", .{screen});
            }
        }).init(self);
    }
};