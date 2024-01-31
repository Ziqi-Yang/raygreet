const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const text_input_field = @import("../component/text_input_field.zig");

const InputUserScreen = @This();

pub fn draw(self: *InputUserScreen) !void {
    _ = self;
    r.ClearBackground(r.RAYWHITE);
    const font = r.GetFontDefault();
    _ = font;
    r.DrawText("Input User Screen", 100, 40, 100, r.GRAY);
    
    // const res = r.MeasureTextEx(font, "W", 100, 0);
    // std.debug.print("{any}\n", .{res});
    // std.debug.print("{any}\n", .{r.MeasureText("Input User Screen", 50)});

    // var cursor: @import("../component/cursor.zig").Cursor = .{
    //     .color = r.GRAY,
    // };
    // const fz = text_input_field.getMaxFontSizeWithWidthLimit(3200, "Hello", &cursor);
    // std.debug.print("{d}\n", .{fz});

}
