const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const InputTextField = @import("../component/input_text_field.zig");
const Vector2 = @import("../util.zig").Vector2;
const Cursor = @import("../component/cursor.zig").Cursor;
const CursorOption = @import("../config.zig").CursorOption;
const ArenaAllocator = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;

const InputUserScreen = @This();

input_text_field: InputTextField = undefined,

// keydown_speed: time per key down event
pub fn new(screen_size: Vector2, cursor_option: CursorOption) !InputUserScreen {
    const cursor: Cursor = .{
        .color = r.GRAY,
        .blink = cursor_option._blink,
        .type = cursor_option.type
    };
    return .{
        .input_text_field = try InputTextField.new(screen_size, cursor)
    };
}

pub fn draw(self: *InputUserScreen) !void {
    r.ClearBackground(r.RAYWHITE);
    self.input_text_field.draw(Vector2 {.x = 0, .y = 0});
}
