const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const InputTextField = @import("../component/input_text_field.zig");
const Vector2 = @import("../util.zig").Vector2;
const Cursor = @import("../component/cursor.zig").Cursor;
const CursorOption = @import("../config.zig").CursorOption;
const screen = @import("../screen.zig");

const InputPasswordScreen = @This();

screen_size: Vector2,
input_text_field: InputTextField,

pub fn new(screen_size: Vector2, cursor_option: CursorOption) !InputPasswordScreen {
    const cursor: Cursor = .{
        .color = r.GRAY,
        .blink = cursor_option._blink,
        .type = cursor_option.type
    };
    const box_size: Vector2 = .{ screen_size[0] * 0.7, screen_size[1] / 2};
    return .{
        .screen_size = screen_size,
        .input_text_field = try InputTextField.new(
            box_size, cursor, .{
                .input_password_screen_enter_key_function = screen.InputPasswordScreenEnterKeyFunction {}
            }
        )
    };
}

pub fn draw(self: *InputPasswordScreen) !void {
    r.ClearBackground(r.RAYWHITE);
    self.input_text_field.draw(Vector2 { self.screen_size[0] * 0.15 , self.screen_size[1] / 4 });
}

