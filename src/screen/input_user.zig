const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const InputTextField = @import("../component/input_text_field.zig");
const Vector2 = @import("../util.zig").Vector2;
const Cursor = @import("../component/cursor.zig").Cursor;
const CursorOption = @import("../config.zig").CursorOption;
const ArenaAllocator = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;

const InputUserScreen = @This();

screen_size: Vector2,
input_text_field: InputTextField,

// keydown_speed: time per key down event
pub fn new(screen_size: Vector2, cursor_option: CursorOption) !InputUserScreen {
    const cursor: Cursor = .{
        .color = r.GRAY,
        .blink = cursor_option._blink,
        .type = cursor_option.type
    };
    const box_size: Vector2 = .{ screen_size[0] * 0.7, screen_size[1] / 2};
    return .{
        .screen_size = screen_size,
        .input_text_field = try InputTextField.new(
            box_size, cursor)
    };
}

pub fn draw(self: *InputUserScreen) !void {
    r.ClearBackground(r.RAYWHITE);
    self.input_text_field.draw(Vector2 { self.screen_size[0] * 0.15 , self.screen_size[1] / 4 });
}
