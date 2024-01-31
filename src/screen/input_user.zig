const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const InputTextField = @import("../component/input_text_field.zig");
const Vector2 = @import("../util.zig").Vector2;
const Cursor = @import("../component/cursor.zig").Cursor;

const InputUserScreen = @This();

input_text_field: InputTextField = undefined,

pub fn new(screen_size: Vector2) !InputUserScreen {
    const cursor: Cursor = .{
        .color = r.GRAY,
    };
    return .{
        .input_text_field = try InputTextField.new(screen_size, cursor)
    };
}

pub fn draw(self: *InputUserScreen) !void {
    r.ClearBackground(r.RAYWHITE);
    self.input_text_field.draw(Vector2 {.x = 0, .y = 0});
}
