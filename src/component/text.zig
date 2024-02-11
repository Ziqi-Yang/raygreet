const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const box = @import("box.zig");
const ColorBox = box.ColorBox;
const util = @import("../util.zig");
const Vector2 = util.Vector2;
const Cursor = @import("cursor.zig").Cursor;
const constants = @import("../constants.zig");


pub const Label = struct {
    const Self = @This();

    box: ColorBox,
    fg_color: r.Color,
    text: []const u8,
    font_size: u16 = undefined,
    font: r.Font,

    pub fn new(
        /// If one field (x, y) of it is 0.0, then don't limit that field.
        size: Vector2,
        bg_color: r.Color,
        fg_color: r.Color,
        text: []const u8,
        font: r.Font,
    ) Self {
        var label: Self = .{
            .box = ColorBox.new(.{0.0, 0.0}, size, bg_color),
            .fg_color = fg_color,
            .text = text,
            .font_size = undefined,
            .font = font
        };
        label.updateText(text);
        return label;
    }

    pub fn updateText(self: *Self, text: []const u8) void {
        const font_size = getPreferredFontSize(
            self.box.getSize() * Vector2 { 0.9, 0.9 },
            text,
            self.font,
            constants.TEXT_SPACING_RATIO,
            null
        );
        self.font_size = font_size;
        
        const m_size = measureTextBoxSize(text, self.font, font_size, constants.TEXT_SPACING_RATIO, null);
        const calculated_size = m_size * Vector2 { 1.1, 1.1 };
        self.box.setSize(calculated_size);

        self.text = text;
    }

    pub fn draw(self: *Self, outer_offset: Vector2) void {
        r.SetTextLineSpacing(self.font_size);
        self.box.draw(outer_offset);
        const offset = outer_offset + self.box.getOffset();
        const spacing = @as(f16, @floatFromInt(self.font_size)) * constants.TEXT_SPACING_RATIO;
        r.DrawTextEx(
            self.font,
            @ptrCast(self.text),
            util.V2toRV2(offset + self.box.getSize() * Vector2 { 0.05, 0.05 }),
            @floatFromInt(self.font_size),
            spacing,
            self.fg_color
        );
    }
};

/// box_size: the size of the box that the input text field is in
/// If one field of it is 0.0, then don't limit the font size in that field.
pub fn getPreferredFontSize(box_size: Vector2, text: []const u8, font: r.Font, spacing_ratio: f16, cursor: ?Cursor) u16 {
    // According to my observation
    // In Raylib, font size is equal to the font's actual display height
    const total_lines = countLineC(text);
    if (box_size[0] == 0.0 and box_size[1] == 0.0) {
        @panic("box_size passed in couldn't be .{0.0, 0.0}!");
    } else if (box_size[0] == 0.0) {
        return @as(u16, @intFromFloat(box_size[1] / @as(f16, @floatFromInt(total_lines))));
    } else if (box_size[1] == 0.0) {
        return getMaxFontSizeWithWidthLimit(box_size[0], text, font, spacing_ratio, cursor);
    }
    const font_size = @min(
        @as(u16, @intFromFloat(box_size[1] / @as(f16, @floatFromInt(total_lines)))),
        getMaxFontSizeWithWidthLimit(box_size[0], text, font, spacing_ratio, cursor)
    );

    return font_size;
}

// note: this function cannot be tested using a unit test, since `r.MeasureText` only
// works after initializing window.
pub fn getMaxFontSizeWithWidthLimit(width_limit: f16, text: []const u8, font: r.Font, spacing_ratio: f16, cursor: ?Cursor) u16 {
    var left: u16 = 0;
    var fz: u16 = undefined;
    var right: u16 = @intFromFloat(width_limit);
    var res: u16 = left;
    while (left <= right) {
        fz = left + (right - left) / 2;
        const text_width = measureTextBoxSize(text, font, fz, spacing_ratio, cursor)[0];
        
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


/// measure text box size
/// spacing_ratio: sapcing = font_size * spacing_ratio
pub fn measureTextBoxSize(text: []const u8, font: r.Font, font_size: u16, spacing_ratio: f16, cursor: ?Cursor) Vector2 {
    r.SetTextLineSpacing(font_size);
    const font_size_f16: f16 = @floatFromInt(font_size);
    const spacing = font_size_f16 * spacing_ratio;
    const text_size =
        r.MeasureTextEx(
            font,
            @ptrCast(text),
            font_size_f16,
            spacing);
    var width = text_size.x;
    if (cursor) |csr| {
        width += csr.calculateSize(font_size)[0];
        if (!std.mem.eql(u8, text, "")) width += spacing;
    }

    return .{ @floatCast(width), @floatCast(text_size.y)};
}


/// count line number using C style (i.e. end when meeting '\x00` character)
pub fn countLineC(text: []const u8) u16 {
    var res: u16 = 1;
    for (text) |char| {
        if (char == 0) break;
        if (char == '\n') res += 1;
    }
    return res;
}
