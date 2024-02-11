const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const box = @import("box.zig");
const ColorBox = box.ColorBox;
const util = @import("../util.zig");
const Vector2 = util.Vector2;
const Cursor = @import("cursor.zig").Cursor;
const constants = @import("../constants.zig");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

/// test script: 
/// var label = try @import("component/text.zig").Label.newFixedSize(
///     gpa,
///     .{ 400, 0 }, // .{0, 80}, .{400, 80}
///     r.DARKGRAY,
///     r.LIGHTGRAY,
///     "El Psy Kongaroo El Psy Kongaroo El Psy Kongaroo El Psy Kongaroo El Psy Kongaroo",
///     r.GetFontDefault(),
///     70,
///     true
/// );
/// defer label.deinit();
/// // inside draw: 
/// label.draw(.{0.0, 0.0});
pub const Label = struct {
    const Self = @This();

    box: ColorBox,
    fg_color: r.Color,
    _text: []const u8, // original text
    text: []const u8, // display text (may be modified)
    font_size: u16 = undefined,
    font: r.Font,
    wrap: bool = false,
    compact: bool = false,
    arena_impl: *ArenaAllocator,

    pub fn new(
        /// If one field (x, y) of it is 0.0, then don't limit that field.
        allocator: Allocator,
        size: Vector2,
        bg_color: r.Color,
        fg_color: r.Color,
        text: []const u8,
        font: r.Font,
    ) !Self {
        var label: Self = .{
            .box = ColorBox.new(.{0.0, 0.0}, size, bg_color),
            .fg_color = fg_color,
            ._text = text,
            .text = text,
            .font_size = undefined,
            .font = font,
            .arena_impl = try allocator.create(ArenaAllocator)
        };
        label.arena_impl.* = ArenaAllocator.init(allocator);
        try label.updateText(text);            

        return label;
    }

    /// in wrap text mode
    pub fn newFixedSize(
        allocator: Allocator,
        size: Vector2,
        bg_color: r.Color,
        fg_color: r.Color,
        text: []const u8,
        font: r.Font,
        font_size: u16,
        compact: bool, // TODO
    ) !Self {
        var label: Self = .{
            .box = ColorBox.new(.{0.0, 0.0}, size, bg_color),
            .fg_color = fg_color,
            ._text = text,
            .text = text,
            .font_size = font_size,
            .font = font,
            .wrap = true,
            .compact = compact,
            .arena_impl = try allocator.create(ArenaAllocator)
        };
        label.arena_impl.* = ArenaAllocator.init(allocator);
        try label.updateText(text);
        return label;
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.arena_impl.child_allocator;
        self.arena_impl.deinit();
        allocator.destroy(self.arena_impl);
    }

    pub fn updateText(self: *Self, text: []const u8) !void {
        const allocator = self.arena_impl.allocator();
        self._text = text;
        var font_size: f16 = @floatFromInt(self.font_size);
        if (!self.wrap) {
            font_size = @floatFromInt(getPreferredFontSize(
                self.box.getSize(),
                text,
                self.font,
                constants.TEXT_SPACING_RATIO,
                null
            ));
            font_size *= 0.9;
            self.font_size = @intFromFloat(font_size);
        }

        // update box size
        const box_size = self.box.getSize();
        var m_size = measureTextBoxSize(
            text,
            self.font,
            @intFromFloat(font_size),
            constants.TEXT_SPACING_RATIO,
            null
        );
        var res_size = m_size + @as(Vector2, @splat(font_size * 0.11));
        if (!self.wrap or @reduce(.And, box_size == Vector2 {0.0, 0.0})) {
            self.box.setSize(res_size);
            self.text = text;
            return;
        }

        // wrap mode with at least one field of box_size is 0.0
        var adjusted_text = try allocator.alloc(u8, text.len + 1);
        @memset(adjusted_text, 0);
        @memcpy(adjusted_text[0..text.len], text);
        
        if (box_size[0] == 0) { // height check for wrap mode
            while (res_size[1] > box_size[1]) {
                trimLastLineC(&adjusted_text, null);
                m_size = measureTextBoxSize(
                    adjusted_text,
                    self.font,
                    @intFromFloat(font_size),
                    constants.TEXT_SPACING_RATIO,
                    null
                );
                res_size = m_size + @as(Vector2, @splat(font_size * 0.1));
            }
            if (self.compact) {
                self.box.setSize(res_size);
            } else {
                self.box.setSize(.{res_size[0], box_size[1]});
            }
            self.text = adjusted_text;
            return;
        }

        adjusted_text = try self._wrapText(text);
        if (self.compact) {
            m_size = measureTextBoxSize(
                adjusted_text,
                self.font,
                @intFromFloat(font_size),
                constants.TEXT_SPACING_RATIO,
                null
            );
            res_size = m_size + @as(Vector2, @splat(font_size * 0.1));
            self.box.setSize(res_size);
        }
        // self.arena_impl.reset(.retain_capacity);
        self.text = adjusted_text;
    }

    /// wrap text according to box width (return a new string)
    /// box width should be set before calling this method
    /// if the height exceeding the box height, then the trailing characters
    /// won't be included
    pub fn _wrapText(self: *Self, text: []const u8) ![]u8 {
        const allocator = self.arena_impl.allocator();
        const font = self.font;
        const font_size: f32 = @floatFromInt(self.font_size);
        const line_height = font_size;
        const spacing = font_size * constants.TEXT_SPACING_RATIO;
        
        var res_text = try allocator.alloc(u8, text.len * 2 + 1);
        @memset(res_text, 0);
        
        const box_size = self.box.getSize();
        const width = box_size[0];
        const height = box_size[1];
        if (width == 0) {
            @memcpy(res_text[0..text.len], text);
            return res_text;   
        }

        const length = r.TextLength(@ptrCast(text)); // Total length in bytes of the text
        var offset_x: f32 = 0;
        var offset_y: f32 = line_height; // line bottom offset
        // Character rectangle scaling factor
        const scaleFactor = font_size / @as(f32, @floatFromInt(font.baseSize));

        var i: usize = 0; var k: usize = 0;
        while (i < length) {
            if (height != 0 and offset_y > height) {
                trimLastLineC(&res_text, k - 1);
                break;
            }
            // Normally CJK characters have two bytes. Also we need to consider Unicode symbols.
            var codepointByteCount: usize = 0;
            const codepoint = r.GetCodepoint(@ptrCast(text[i..]), @ptrCast(&codepointByteCount));
            const index: usize = @intCast(r.GetGlyphIndex(font, codepoint));
            
            var glyphWidth: f32 = 0;
            if (codepoint != '\n') {
                glyphWidth = // don't blame me, Emacs zig-mode formatting works not very well
                    if (font.glyphs[index].advanceX == 0)
                    font.recs[index].width * scaleFactor else
                    @as(f32, @floatFromInt(font.glyphs[index].advanceX)) * scaleFactor;
                if (i + 1 < length) glyphWidth = glyphWidth + spacing;
            }

            if (glyphWidth > width) break; // width is too narrow
            
            if ((offset_x + glyphWidth) > width) {
                res_text[k] += '\n';
                k += 1;
                offset_x = 0;
                offset_y += line_height;
            }
            if (codepoint == '\n') offset_y += line_height;

            offset_x += glyphWidth;
            
            // encounter error
            if (codepoint == 0x3f) codepointByteCount = 1;
            for (0..codepointByteCount) |_| {
                res_text[k] = text[i];
                k += 1; i += 1;
            }
        }

        return res_text;
    }

    pub fn draw(self: *Self, outer_offset: Vector2) void {
        r.SetTextLineSpacing(self.font_size);
        self.box.draw(outer_offset);
        const offset = outer_offset + self.box.getOffset();
        const spacing = @as(f16, @floatFromInt(self.font_size)) * constants.TEXT_SPACING_RATIO;
        r.DrawTextEx(
            self.font,
            @ptrCast(self.text),
            util.V2toRV2(offset +
                    @as(Vector2, @splat(@as(f16, @floatFromInt(self.font_size))))
                    * Vector2 { 0.05, 0.05 }),
            @floatFromInt(self.font_size),
            spacing,
            self.fg_color
        );
    }
};

/// Can only trim ascii trailing spaces
// pub fn trimTrailingSpacesC(text: *[]u8, end_pos: ?usize) void {
//     var index: usize = text.len;
//     if (end_pos) |pos| index = pos;
//     while (index >= 0) {
//         switch (text.*[index]) {
//             ' ', '\t', '\n' => {
//                 text.*[index] = 0;
//             },
//             0 => {},
//             else => break
//         }
//         if (index == 0) break;
//         index -= 1;
//     }
// }

pub fn trimLastLineC(text: *[]u8, end_pos: ?usize) void {
    if (text.len == 0) return;
    var index: usize = 0;
    // find the c-string ending
    if (end_pos) |pos| {
        index = pos;
    } else {
        while (index < text.len) : (index += 1) {
            if (text.*[index] == 0) break;
        }
        index -= 1;
    }
    var shouldBreak = false;
    while (index > 0) : (index -= 1) {
        if (text.*[index] == '\n') {
            shouldBreak = true;
        }
        text.*[index] = 0;
        if (shouldBreak) break;
    }
}

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
