const std = @import("std");
const log = std.log;
const Cursor = @import("cursor.zig").Cursor;
const Vector2 = @import("../util.zig").Vector2;
const r = @cImport(@cInclude("raylib.h"));
const config = @import("../config.zig");
const status = @import("../status.zig");

const InputTextField = @This();

const MAX_TEXT_LEN = 255;
const SPACING_RATIO: f16 = 0.1; // spacing = text_size * spacing_ratio

text: [MAX_TEXT_LEN: '\x00']u8 = [_: '\x00']u8{'\x00'} ** MAX_TEXT_LEN,
_text_index: u8 = 0,
font: r.Font,
font_size: u16,
box_size: Vector2,
offset: Vector2,
color: r.Color,
cursor: Cursor,
cursor_offset: Vector2,
_key_down_frame_counter: u8 = 0,

/// box_size: the size of the box that the input text field is in
/// this function must be called after raylib window initialization (to get
/// default font)
pub fn new(box_size: Vector2, cursor: Cursor) !InputTextField {
    if (!r.IsWindowReady()) return error.WindowNotInitialized;
    var input_text_field = InputTextField {
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
    const text = &self.text;
    const font_size = getPreferredFontSize(self.box_size, self.font, text, &self.cursor);
    self.font_size = font_size;
    
    const text_size = measureInputTextFieldSize(text, &self.cursor, self.font, font_size);
    
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
    const spacing = font_size_f16 * SPACING_RATIO;
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

/// return whether push success (the reason to fail: size full)
pub fn push(self: *InputTextField, char: u8) bool {
    if (self._text_index >= self.text.len) {
        return false;
    } 
    self.text[self._text_index] = char;
    self._text_index += 1;
    self.autoSetFontSize();
    return true;
}

/// return whether pop success (the reason to fail: size empty)
pub fn pop(self: *InputTextField) bool {
    if (self._text_index == 0) {
        return false;
    }
    self._text_index -= 1;
    self.text[self._text_index] = '\x00';
    self.autoSetFontSize();
    return true;
}

// TODO current only support US keymap.
// note that the left character is mapped from scan code to US keymap.
// see: https://github.com/raysan5/raylib/discussions/3773
fn upperCaseChar(char: u8) u8 {
    return switch (char) {
        'a'...'z' => char - 32,
        '`' => '~',
        '1' => '!',
        '2' => '@',
        '3' => '#',
        '4' => '$',
        '5' => '%',
        '6' => '^',
        '7' => '&',
        '8' => '*',
        '9' => '(',
        '0' => ')',
        '-' => '_',
        '=' => '+',
        '[' => '{',
        ']' => '}',
        '\\' => '|',
        ';' => ':',
        '\'' => '"',
        ',' => '<',
        '.' => '>',
        '/' => '?',
        else => char
    };
}

fn handleInput(self: *InputTextField) void {
    const CONFIG = config.get_config();
    const char = r.GetCharPressed();
    
    switch (char) {
        32...126 => {
            var c: u8 = @intCast(char);

            if (r.IsKeyDown(r.KEY_LEFT_SHIFT) or r.IsKeyDown(r.KEY_RIGHT_SHIFT)
                    or (status.capsLockOn and c >= 'a' and c <= 'z')) {
                c = upperCaseChar(c);
            }

            _ = self.push(c);
        },
        else => {}
    }
    if (r.IsKeyDown(r.KEY_BACKSPACE)) {
        if (self._key_down_frame_counter == 0) {
            _ = self.pop();
        }
        self._key_down_frame_counter = (self._key_down_frame_counter + 1) % CONFIG._frames_per_key_down;
    } else {
        self._key_down_frame_counter = 0;
    }
}

/// outer_offset: position of the box that Input Text Filed is in
pub fn draw(self: *InputTextField, outer_offset: Vector2) void {
    self.handleInput();
    
    const text = &self.text;
    // std.debug.print("{s}\n", .{text});
    const position = outer_offset.add(&self.offset);
    const position_r = r.Vector2 {
        .x = position.x,
        .y = position.y
    };
    const cursor_position = outer_offset.add(&self.cursor_offset);

    // std.debug.print(">{}\n", .{cursor_position});
    
    r.DrawTextEx(
        self.font,
        @ptrCast(text),
        position_r,
        @floatFromInt(self.font_size),
        @as(f16, @floatFromInt(self.font_size)) * SPACING_RATIO,
        self.color
    );

    self.cursor.draw(&cursor_position);
}
