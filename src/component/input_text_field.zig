const std = @import("std");
const log = std.log;
const Cursor = @import("cursor.zig").Cursor;
const Vector2 = @import("../util.zig").Vector2;
const r = @cImport(@cInclude("raylib.h"));
const config = @import("../config.zig");
const status = @import("../status.zig");
const util = @import("../util.zig");
const i_box = @import("box.zig");
const Box = i_box.Box;
const constants = @import("../constants.zig");

const MAX_TEXT_LEN = 255;
const SPACING_RATIO: f16 = 0.1; // spacing = text_size * spacing_ratio

pub const InputTextField = struct {
    const Self = @This();

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
    font_size: u16 = undefined,
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
            // font_size
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
        const font_size = i_box.getPreferredFontSize(
            self.box.getSize(),
            text,
            self.font,
            constants.TEXT_SPACING_RATIO,
            self.cursor
        );
        self.font_size = font_size;
        
        const text_size = i_box.measureTextBoxSize(
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
        // std.debug.print("{} # {} # {}\n", .{text_size, cursor_size, @as(f16, @floatFromInt(r.MeasureText(@ptrCast(self.text), font_size)))});
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
            @floatFromInt(self.font_size),
            @as(f16, @floatFromInt(self.font_size)) * SPACING_RATIO,
            self.color
        );

        self.cursor.draw(outer_offset);
    }
};

