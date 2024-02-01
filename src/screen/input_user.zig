const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const InputTextField = @import("../component/input_text_field.zig");
const Vector2 = @import("../util.zig").Vector2;
const Cursor = @import("../component/cursor.zig").Cursor;
const CursorOption = @import("../config.zig").CursorOption;
const ArenaAllocator = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;

const InputUserScreen = @This();

_key_down_frame_counter: u8 = 0,
frames_per_key_down: u8 = 1,
input_text_field: InputTextField = undefined,

// keydown_speed: time per key down event
pub fn new(screen_size: Vector2, cursor_option: CursorOption, target_fps: u8, keydown_speed: f16) !InputUserScreen {
    const fps: f16 = @floatFromInt(target_fps);
    const cursor: Cursor = .{
        .color = r.GRAY,
        .blink = cursor_option.blink,
        .type = cursor_option.type
    };
    std.debug.print("{}\n", .{@as(u8, @intFromFloat(fps * keydown_speed))});
    return .{
        .frames_per_key_down = @intFromFloat(fps * keydown_speed),
        .input_text_field = try InputTextField.new(screen_size, cursor)
    };
}

pub fn draw(self: *InputUserScreen) !void {
    r.ClearBackground(r.RAYWHITE);
    // handle input
    const char: u8 = @intCast(r.GetCharPressed());
    switch (char) {
        32...126 => {
            // text = try std.fmt.allocPrintZ(self.arena, "{s}{c}", .{text, char});
            _ = self.input_text_field.push(char);
        },
        else => {}
    }
    if (r.IsKeyDown(r.KEY_BACKSPACE)) {
        if (self._key_down_frame_counter == 0) {
            _ = self.input_text_field.pop();
        }
        self._key_down_frame_counter = (self._key_down_frame_counter + 1) % self.frames_per_key_down;
    } else {
        self._key_down_frame_counter = 0;
    }
    self.input_text_field.draw(Vector2 {.x = 0, .y = 0});
}
