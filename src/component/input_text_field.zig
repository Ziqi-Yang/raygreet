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

func_pop_char: PopChar,
func_pop_all: PopAll,

/// box_size: the size of the box that the input text field is in
/// this function must be called after raylib window initialization (to get
/// default font)
pub fn new(box_size: Vector2, cursor: Cursor) !InputTextField {
    const CONFIG = config.get_config();
    if (!r.IsWindowReady()) return error.WindowNotInitialized;
    
    var input_text_field = InputTextField {
        .font = r.GetFontDefault(),
        .font_size = undefined,
        .box_size = box_size,
        .offset = Vector2 { 0, 0},
        .color = r.DARKGRAY,
        .cursor = cursor,
        .cursor_offset = Vector2 {0, 0},
        .func_pop_char = PopChar {
            .frames_per_key_down = CONFIG._frames_per_key_down
        },
        .func_pop_all = PopAll {}
    };
    input_text_field.autoSetFontSize();

    return input_text_field;
}

fn autoSetFontSize(self: *InputTextField) void {
    const text = &self.text;
    const font_size = getPreferredFontSize(self.box_size, self.font, text, &self.cursor);
    self.font_size = font_size;
    
    const text_size = measureInputTextFieldSize(text, &self.cursor, self.font, font_size);
    
    const offset_x = (self.box_size[0] - text_size[0]) / 2;
    const offset_y = (self.box_size[1] - text_size[1]) / 2;
    self.offset[0] = offset_x;
    self.offset[1] = offset_y;
    
    const cursor_size = self.cursor.setSize(font_size);
    // std.debug.print("{} # {} # {}\n", .{text_size, cursor_size, @as(f16, @floatFromInt(r.MeasureText(@ptrCast(self.text), font_size)))});
    const cursor_offset_x = (offset_x + text_size[0] - cursor_size[0]);
    const cursor_offset_y = (offset_y + text_size[1] - cursor_size[1]);
    self.cursor_offset[0] = cursor_offset_x;
    self.cursor_offset[1] = cursor_offset_y;
}


/// box_size: the size of the box that the input text field is in
fn getPreferredFontSize(box_size: Vector2, font: r.Font, text: []const u8, cursor: *const Cursor) u16 {
    // According to my observation
    // In Raylib, font size is equal to the font's actual display height
    const font_size = @min(
        @as(u16, @intFromFloat(box_size[1])),
        getMaxFontSizeWithWidthLimit(box_size[0], font, text, cursor)
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
        const text_width = measureInputTextFieldSize(text, cursor, font, fz)[0];
        
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
        var width: f32 = cursor.calculateSize(font_size)[0];
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

    return .{ @floatCast(width), font_size_f16};
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

pub fn pop(self: *InputTextField) ?u8 {
    if (self._text_index == 0) {
        return null;
    }
    self._text_index -= 1;
    const old_char = self.text[self._text_index];
    self.text[self._text_index] = '\x00';
    self.autoSetFontSize();
    return old_char;
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

const PopChar = struct {
    frames_per_key_down: u8,
    
    var key_down_counter: u8 = 0;
    
    pub fn keydown(self: *const PopChar, inputTextField: *InputTextField, should_key_down: bool) void {
        if (should_key_down) {
            if (key_down_counter == 0) {
                _ = inputTextField.pop();
            }
            key_down_counter = (key_down_counter + 1) % self.frames_per_key_down;
        } else {
            key_down_counter = 0;
        }
    }
};

const PopAll = struct {
    pub fn keydown(_: *const PopAll, inputTextField: *InputTextField, should_key_down: bool) void {
        if (!should_key_down) {
            return;
        }
        var char: ?u8 = 0;
        while (char != null) {
            char = inputTextField.pop();
        }
    }
};


fn handleAllKeysDown(self: *InputTextField, keys: []const c_int, keydown_func: anytype) void {
    var are_all_keys_down = true;
    for (keys) |key| {
        if (!r.IsKeyDown(key)) {
            are_all_keys_down = false;
            break;
        }
    }
    keydown_func.keydown(self, are_all_keys_down);
}

fn handleOneKeyDown(self: *InputTextField, keys: []const c_int, keydown_func: anytype) void {
    var has_one_key_down = false;
    for (keys) |key| {
        if (r.IsKeyDown(key)) {
            has_one_key_down = true;
            break;
        }
    }
    keydown_func.keydown(self, has_one_key_down);
}

fn handleInput(self: *InputTextField) void {
    if (r.IsKeyDown(r.KEY_ENTER) or r.IsKeyDown(r.KEY_KP_ENTER)) {
        // status.current_screen = 
    }
    
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

    if ((r.IsKeyDown(r.KEY_LEFT_CONTROL) or r.IsKeyDown(r.KEY_RIGHT_CONTROL))) {
        // batch delete
        self.handleOneKeyDown(&.{r.KEY_W, r.KEY_BACKSPACE}, self.func_pop_all);
    } else {
        self.handleAllKeysDown(&.{r.KEY_BACKSPACE}, self.func_pop_char);
    }
}

/// outer_offset: position of the box that Input Text Filed is in
pub fn draw(self: *InputTextField, outer_offset: Vector2) void {
    self.handleInput();
    
    const text = &self.text;
    // std.debug.print("{s}\n", .{text});
    const position = outer_offset + self.offset;
    const position_r = r.Vector2 {
        .x = position[0],
        .y = position[1]
    };
    const cursor_position = outer_offset + self.cursor_offset;

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
