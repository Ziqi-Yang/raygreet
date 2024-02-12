const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));

const box = @import("box.zig");
const Box = @import("box.zig").Box;
const ColorBox = box.ColorBox;

const util = @import("../util.zig");
const Vector2 = util.Vector2;
const Cursor = @import("cursor.zig").Cursor;
const constants = @import("../constants.zig");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const config = @import("../config.zig");
const status = @import("../status.zig");

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

    _box: ColorBox, // original box
    box: ColorBox, // calculated box
    fg_color: r.Color,
    _text: []const u8, // original text
    text: []const u8, // display text (may be modified)
    font_size: f16 = undefined,
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
            ._box = ColorBox.new(.{0.0, 0.0}, size, bg_color),
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
        font_size: f16,
        compact: bool, // TODO
    ) !Self {
        var label: Self = .{
            ._box = ColorBox.new(.{0.0, 0.0}, size, bg_color),
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
        const box_size = self._box.getSize();
        var font_size = self.font_size;
        if (!self.wrap) {
            font_size = @floatFromInt(getPreferredFontSize(
                box_size,
                text,
                self.font,
                constants.TEXT_SPACING_RATIO,
                null
            ));
            font_size *= 0.9;
            self.font_size = font_size;
        }

        // update box size
        var m_size = measureTextBoxSize(
            text,
            self.font,
            font_size,
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
                    font_size,
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
                font_size,
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
        const font_size = self.font_size;
        const line_height = font_size;
        const spacing = font_size * constants.TEXT_SPACING_RATIO;
        
        var res_text = try allocator.alloc(u8, text.len * 2 + 1);
        @memset(res_text, 0);
        
        const box_size = self._box.getSize();
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
        r.SetTextLineSpacing((@intFromFloat(self.font_size)));
        self.box.draw(outer_offset);
        const offset = outer_offset + self.box.getOffset();
        const spacing = self.font_size * constants.TEXT_SPACING_RATIO;
        r.DrawTextEx(
            self.font,
            @ptrCast(self.text),
            util.V2toRV2(
                offset + @as(Vector2, @splat(self.font_size))
                    * Vector2 { 0.05, 0.05 }),
            self.font_size,
            spacing,
            self.fg_color
        );
    }
};


pub const InputTextField = struct {
    const Self = @This();
    const MAX_TEXT_LEN = 255;

    const PopChar = struct {
        var key_down_counter: u8 = 0;
        
        pub fn keydown(_: @This(), input_text_field: *Self, should_key_down: bool) void {
            if (should_key_down) {
                if (key_down_counter == 0) {
                    _ = input_text_field.pop();
                }
                key_down_counter = (key_down_counter + 1) % input_text_field.frames_per_key_down;
            } else {
                key_down_counter = 0;
            }
        }
    };

    const PopAll = struct {
        pub fn keydown(_: @This(), input_text_field: *Self, should_key_down: bool) void {
            if (!should_key_down) {
                return;
            }
            input_text_field.reset();
        }
    };

    const POP_ALL = PopAll {};
    const KEY_BACKSPACE_POP_CHAR = PopChar {};

    text: [MAX_TEXT_LEN: 0]u8 = [_: 0]u8{0} ** MAX_TEXT_LEN,
    _text_index: u8 = 0,
    box: Box,
    cursor: Cursor,
    font: r.Font,
    font_size: f16,
    color: r.Color = r.DARKGRAY,
    frames_per_key_down: u8,
    func_enter_key_down: ?*const fn () void,
    
    /// box_size: the size of the box that the input text field is in
    /// this function must be called after raylib window initialization (to get
    /// default font)
    pub fn new(
        box_size: Vector2,
        func_enter_key_down: ?*const fn () void
    ) !Self {
        if (!r.IsWindowReady()) return error.WindowNotInitialized;
        const CONFIG = config.get_config();

        const font = r.GetFontDefault();
        const cursor: Cursor = .{
            .color = r.GRAY,
            .blink = CONFIG.cursor._blink,
            .type = CONFIG.cursor.type,
            .box = .{}
        };

        var res: Self = .{
            .font = font,
            .font_size = undefined,
            .box = .{
                .size = box_size
            },
            .cursor = cursor,
            .frames_per_key_down = CONFIG._frames_per_key_down,
            .func_enter_key_down = func_enter_key_down
        };
        res.update();
        return res;
    }

    /// update font_size, offset, cursor field
    pub fn update(self: *Self) void {
        const text = &self.text;
        const font_size: f16 = @floatFromInt(getPreferredFontSize(
            self.box.getSize(),
            text,
            self.font,
            constants.TEXT_SPACING_RATIO,
            self.cursor
        ));
        self.font_size = font_size;
        
        const text_size = measureTextBoxSize(
            text,
            self.font,
            font_size,
            constants.TEXT_SPACING_RATIO,
            self.cursor
        );

        const box_size = self.box.getSize();
        const offset = (box_size - text_size) / Vector2 {2, 2};
        self.box.setOffset(offset);
        
        const cursor_size = self.cursor.setSize(font_size);
        const cursor_offset = offset + text_size - cursor_size;
        self.cursor.box.setOffset(cursor_offset);
    }

    pub fn getTextAlloc(self: *Self, allocator: std.mem.Allocator) ![]u8 {
        return allocator.dupe(u8, self.text[0..self._text_index]);
    }

    /// return whether push success (the reason to fail: size full) and update
    /// the input text field
    pub fn push(self: *Self, char: u8) bool {
        if (self._text_index >= self.text.len) {
            return false;
        } 
        self.text[self._text_index] = char;
        self._text_index += 1;
        self.update();
        self.cursor.resetBlink();
        return true;
    }

    /// Return the old character and update the input text field.
    pub fn pop(self: *Self) ?u8 {
        if (self._text_index == 0) {
            return null;
        }
        self._text_index -= 1;
        const old_char = self.text[self._text_index];
        self.text[self._text_index] = '\x00';
        self.update();
        self.cursor.resetBlink();
        return old_char;
    }

    pub fn reset(self: *Self) void {
        while (self._text_index > 0) : (self._text_index -= 1) {
            self.text[self._text_index - 1] = '\x00';
        }
        self.update();
    }

    fn handleAllKeysDown(self: *Self, keys: []const c_int, keydown_func: anytype) void {
        var are_all_keys_down = true;
        for (keys) |key| {
            if (!r.IsKeyDown(key)) {
                are_all_keys_down = false;
                break;
            }
        }
        keydown_func.keydown(self, are_all_keys_down);
    }

    fn handleOneKeyDown(self: *Self, keys: []const c_int, keydown_func: anytype) void {
        var has_one_key_down = false;
        for (keys) |key| {
            if (r.IsKeyDown(key)) {
                has_one_key_down = true;
                break;
            }
        }
        keydown_func.keydown(self, has_one_key_down);
    }

    fn handleInput(self: *Self) void {
        if (r.IsKeyPressed(r.KEY_ENTER) or r.IsKeyPressed(r.KEY_KP_ENTER)) {
            if (self.func_enter_key_down) | func | {
                func();
                return;
            }
        }

        for (status.cur_pressed_chars) | char | {
            if (char == null) break;
            switch (char.?) {
                32...126 => {
                    var c: u8 = char.?;

                    if (r.IsKeyDown(r.KEY_LEFT_SHIFT) or r.IsKeyDown(r.KEY_RIGHT_SHIFT)
                            or (status.caps_lock_on and c >= 'a' and c <= 'z')) {
                        c = util.upperCaseChar(c);
                    }

                    _ = self.push(c);
                },
                else => {}
            }
        }
        if ((r.IsKeyDown(r.KEY_LEFT_CONTROL) or r.IsKeyDown(r.KEY_RIGHT_CONTROL))) {
            // batch delete
            self.handleOneKeyDown(&.{r.KEY_W, r.KEY_BACKSPACE}, POP_ALL);
        } else {
            self.handleAllKeysDown(&.{r.KEY_BACKSPACE}, KEY_BACKSPACE_POP_CHAR);
        }
    }

    /// outer_offset: position of the box that Input Text Filed is in
    pub fn draw(self: *Self, outer_offset: Vector2) void {
        self.handleInput();
        
        const text = &self.text;
        // std.debug.print("{s}\n", .{text});
        const position = outer_offset + self.box.getOffset();
        const position_r = r.Vector2 {
            .x = position[0],
            .y = position[1]
        };
        
        r.DrawTextEx(
            self.font,
            @ptrCast(text),
            position_r,
            self.font_size,
            self.font_size * constants.TEXT_SPACING_RATIO,
            self.color
        );

        self.cursor.draw(outer_offset);
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
        const text_width = measureTextBoxSize(text, font, @floatFromInt(fz), spacing_ratio, cursor)[0];
        
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
pub fn measureTextBoxSize(text: []const u8, font: r.Font, font_size: f16, spacing_ratio: f16, cursor: ?Cursor) Vector2 {
    r.SetTextLineSpacing(@intFromFloat(font_size));
    const spacing = font_size * spacing_ratio;
    const text_size =
        r.MeasureTextEx(
            font,
            @ptrCast(text),
            font_size,
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
