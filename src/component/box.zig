const std = @import("std");
const util = @import("../util.zig");
const Vector2 = util.Vector2;
const r = @cImport(@cInclude("raylib.h"));
const Cursor = @import("cursor.zig").Cursor;
const constants = @import("../constants.zig");

const LABEL_MAX_TEXT_LEN: u8 = 255;

pub const Box = struct {
    const Self = @This();

    offset: Vector2 = .{0.0, 0.0},
    size: Vector2 = .{0.0, 0.0},
    
    /// Any type extends Box type should also have this function
    pub inline fn getOffset(self: Self) Vector2 {
        return self.offset;
    }
    
    /// Any type extends Box type should also have this function
    pub inline fn getSize(self: Self) Vector2 {
        return self.size;
    }

    /// Any type extends Box type should also have this function
    pub inline fn setOffset(self: *Self, offset: Vector2) void {
        self.offset = offset;
    }

    /// Any type extends Box type should also have this function
    pub inline fn setSize(self: *Self, size: Vector2) void {
        self.size = size;
    }
};

pub const ColorBox = struct {
    const Self = @This();

    box: Box,
    bg_color: r.Color,

    pub fn new(
        offset: Vector2,
        size: Vector2,
        bg_color: r.Color,
    ) Self {
        return .{
            .box = .{
                .offset = offset,
                .size = size,
            },
            .bg_color = bg_color
        };
    }

    pub inline fn getOffset(self: *Self) Vector2 {
        return self.box.offset;
    }

    pub inline fn getSize(self: *Self) Vector2 {
        return self.box.size;
    }

    pub inline fn setOffset(self: *Self, offset: Vector2) void {
        self.box.offset = offset;
    }

    pub inline fn setSize(self: *Self, size: Vector2) void {
        self.box.size = size;
    }

    pub fn draw(self: *Self, outer_offset: Vector2) void {
        const offset = outer_offset + self.box.offset;
        r.DrawRectangleV(util.V2toRV2(offset), util.V2toRV2(self.box.size), self.bg_color);
    }
};

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
        const font_size = getPreferredFontSize(
            size * Vector2 { 0.9, 0.9 },
            text,
            font,
            constants.TEXT_SPACING_RATIO,
            null
        );
        var calculated_size = size;
        if (calculated_size[0] == 0.0 or calculated_size[1] == 0.0) {
            const m_size = measureTextBoxSize(text, font, font_size, constants.TEXT_SPACING_RATIO, null);
            if (calculated_size[0] == 0.0) calculated_size[0] = m_size[0] * 1.1;
            if (calculated_size[1] == 0.0) calculated_size[1] = m_size[1] * 1.1;
        }

        return .{
            .box = ColorBox.new(.{0.0, 0.0}, calculated_size, bg_color),
            .fg_color = fg_color,
            .text = text,
            .font_size = font_size,
            .font = font
        };
    }

    pub fn draw(self: *Self, outer_offset: Vector2) void {
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
    if (box_size[0] == 0.0 and box_size[1] == 0.0) {
        @panic("box_size passed in couldn't be .{0.0, 0.0}!");
    } else if (box_size[0] == 0.0) {
        return @as(u16, @intFromFloat(box_size[1]));
    } else if (box_size[1] == 0.0) {
        return getMaxFontSizeWithWidthLimit(box_size[0], text, font, spacing_ratio, cursor);
    }
    const font_size = @min(
        @as(u16, @intFromFloat(box_size[1])),
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
    const font_size_f16: f16 = @floatFromInt(font_size);
    const spacing = font_size_f16 * spacing_ratio;
    const width = width: {
        if (cursor) |csr| {
            var width: f32 = csr.calculateSize(font_size)[0];
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
        } else {
            break :width
                r.MeasureTextEx(
                    font,
                    @ptrCast(text),
                    font_size_f16,
                    spacing).x;

        }
    };

    return .{ @floatCast(width), font_size_f16};
}

