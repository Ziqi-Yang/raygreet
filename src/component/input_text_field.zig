const std = @import("std");
const Cursor = @import("cursor.zig").Cursor;
const util = @import("../util.zig");
const Vector2 = @import("../util.zig").Vector2;
const r = @cImport(@cInclude("raylib.h"));

const InputTextField = @This();

_previous_text: []const u8,
text: []const u8,
font: r.Font,
font_size: u16,
box_size: Vector2,
offset: Vector2,
color: r.Color,
cursor: Cursor,
cursor_offset: Vector2,

const spacing_ratio: f16 = 0.1; // spacing = text_size * spacing_ratio

/// box_size: the size of the box that the input text field is in
/// this function must be called after raylib window initialization (to get
/// default font)
pub fn new(box_size: Vector2, cursor: Cursor) !InputTextField {
    if (!r.IsWindowReady()) return error.WindowNotInitialized;
    const initial_text = "";
    var input_text_field = InputTextField {
        ._previous_text = initial_text,
        .text = initial_text,
        .font = r.GetFontDefault(),
        .font_size = undefined,
        .box_size = box_size,
        .offset = Vector2 {.x = 0, .y = 0},
        .color = r.DARKGRAY,
        .cursor = cursor,
        .cursor_offset = Vector2 {.x = 0, .y = 0}
    };
    input_text_field.autoSetFontSize();

    return input_text_field;
}

fn autoSetFontSize(self: *InputTextField) void {
    const font_size = getPreferredFontSize(self.box_size, self.font, self.text, &self.cursor);
    self.font_size = font_size;
    
    const text_size = measureInputTextFieldSize(self.text, &self.cursor, self.font, font_size);
    
    const offset_x = (self.box_size.x - text_size.x) / 2;
    const offset_y = (self.box_size.y - text_size.y) / 2;
    self.offset.x = offset_x;
    self.offset.y = offset_y;
    
    const cursor_size = self.cursor.setSize(font_size);
    // std.debug.print("{} # {} # {}\n", .{text_size, cursor_size, @as(f16, @floatFromInt(r.MeasureText(@ptrCast(self.text), font_size)))});
    const cursor_offset_x = (offset_x + text_size.x - cursor_size.x);
    const cursor_offset_y = (offset_y + text_size.y - cursor_size.y);
    self.cursor_offset.x = cursor_offset_x;
    self.cursor_offset.y = cursor_offset_y;
}


/// box_size: the size of the box that the input text field is in
fn getPreferredFontSize(box_size: Vector2, font: r.Font, text: []const u8, cursor: *const Cursor) u16 {
    const width_limit: f16 = box_size.x * 0.7;
    // According to my observation(default font)
    // In Raylib, font size is equal to the font's actual display height
    const font_size = @min(
        @as(u16, @intFromFloat(box_size.y / 2)),
        getMaxFontSizeWithWidthLimit(width_limit, font, text, cursor)
    );

    return font_size;
}

// note: this function cannot be tested using a unit test, since `r.MeasureText` only
// works after initializing window.
fn getMaxFontSizeWithWidthLimit(width_limit: f16, font: r.Font, text: []const u8, cursor: *const Cursor) u16 {
    var left: u16 = 0;
    var fz: u16 = undefined;
    var right: u16 = @intFromFloat(width_limit);
    var res: u16 = left;
    while (left <= right) {
        fz = left + (right - left) / 2;
        const text_width = measureInputTextFieldSize(text, cursor, font, fz).x;
        
        // std.debug.print(">{} {} {}\n", .{fz, text_width, width_limit});
        
        if (text_width <= width_limit) {
            res = fz;
            left = fz + 1;
        } else {
            right = fz - 1;
        }
    }
    // std.debug.print("{}\n", .{res});
    return res;
}

fn measureInputTextFieldSize(text: []const u8, cursor: *const Cursor, font: r.Font, font_size: u16) Vector2 {
    const font_size_f16: f16 = @floatFromInt(font_size);
    const spacing = font_size_f16 * spacing_ratio;
    const width = width: {
        var width: f32 = cursor.calculateSize(font_size).x;
        if (!std.mem.eql(u8, text, "")) {
            width +=
                r.MeasureTextEx(
                    font,
                    @ptrCast(text),
                    font_size_f16,
                    spacing).x
                + spacing;
        }
        break :width width;
    };

    return .{
        .x = @floatCast(width),
        .y = font_size_f16
    };
}

/// outer_offset: position of the box that Input Text Filed is in
pub fn draw(self: *InputTextField, outer_offset: Vector2) void {
    const position = outer_offset.add(&self.offset);
    const position_r = r.Vector2 {
        .x = position.x,
        .y = position.y
    };
    const cursor_position = outer_offset.add(&self.cursor_offset);
    
    // if text changed, set font size
    if (!std.mem.eql(u8, self.text, self._previous_text)) {
        self.autoSetFontSize();
        self._previous_text = self.text;
    }
    
    r.DrawTextEx(
        self.font,
        @ptrCast(self.text),
        position_r,
        @floatFromInt(self.font_size),
        @as(f16, @floatFromInt(self.font_size)) * spacing_ratio,
        self.color
    );

    self.cursor.draw(&cursor_position);
}
