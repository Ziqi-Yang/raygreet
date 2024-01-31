const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const Cursor = @import("cursor.zig").Cursor;
const CursorType = @import("cursor.zig").CursorType;
const util = @import("../util.zig");
const Size = @import("../util.zig").Size;

const TextInputField = @This();

text: []const u8,
text_size: u16,
screen_size: Size,
cursor: Cursor,
position: r.Vector2,

const spacing_ratio: f16 = 0.1; // spacing = text_size * spacing_ratio

pub fn New(screen_size: Size, cursor_type: CursorType) TextInputField {
    _ = cursor_type;
    const screen_width = screen_size[0];
    _ = screen_width;
    const screen_height = screen_size[1];
    _ = screen_height;
    const text_size = text_size: {
        break :text_size 100; // TODO
    };
    _ = text_size;
    
    return .{
        .text = "",
        .screen_size = screen_size,
        .cursor = .{
            
        },
    };
}

pub fn getPreferredFontSize(screen_size: Size, text: []const u8, cursor: *Cursor) u16 {
    _ = cursor;
    _ = text;
    const screen_width = screen_size[0];
    const screen_height = screen_size[1];
    const width_limit: u16 = @intFromFloat(screen_width * 0.7);
    _ = width_limit;
    // According to my observation(default font)
    // In Raylib, font size is equal to the font's actual display height
    const font_size = screen_height / 2;

    return font_size;
}

pub fn getMaxFontSizeWithWidthLimit(width_limit: u16, text: []const u8, cursor: *Cursor) u16 {
    var fz: u16 = 0;
    var left: u16 = 0;
    var right: u16 = width_limit;
    while (left < right) {
        fz = left + (right - left) / 2;
        const text_width = r.MeasureText(@ptrCast(text), fz)
            + @as(u16, @intFromFloat(@as(f16, @floatFromInt(fz)) * spacing_ratio))
            + cursor.getCursorSize(fz)[0];
        if (text_width < width_limit) {
            left = fz + 1;
        } else {
            right = fz;
        }
    }
    return fz;
}

pub fn draw(self: *TextInputField) !void {
    _ = self;
}

test "Get Max Font Size With Width Limit" {
    const cursor: Cursor = .{
        .color = r.GRAY,
    };
    const fz = getMaxFontSizeWithWidthLimit(3200, "Hello", &cursor);
    std.debug.print("{d}\n", .{fz});
}

