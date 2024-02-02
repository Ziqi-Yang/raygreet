const r = @cImport(@cInclude("raylib.h"));
const Vector2 = @import("../util.zig").Vector2;
const status = @import("../status.zig");

pub const Cursor = struct {
    _show: bool = true,
    _frame_counter: u8 = 0,
    /// don't directly set size
    size: Vector2 = .{ 10.0, 10.0},
    color: r.Color,
    /// per num frame changes hide/show status (0 means no blink)
    blink: u8 = 0,
    type: CursorType = CursorType.Bar,

    pub fn setSize(self: *Cursor, font_size: u16) Vector2 {
        const size: Vector2 = self.calculateSize(font_size);
        self.size = size;
        return size;
    }

    pub fn calculateSize(self: *const Cursor, font_size: u16) Vector2 {
        const fz: f16 = @floatFromInt(font_size);
        return switch (self.type) {
            .Box => .{ fz * 0.75, @floatFromInt(font_size)},
            .Bar => .{ fz * 0.1, @floatFromInt(font_size)},
            .Hbar => .{ @floatFromInt(font_size), fz * 0.1 }
        };
    }

    pub fn resetBlinkFrameCounter(self: *Cursor) void {
        self._frame_counter = 0;
    }

    pub fn draw(self: *Cursor, position: *const Vector2) void {
        if (status.pressedKey != null) {
            self._show = true;
            self._frame_counter = 0;
       } else {
            if (self.blink != 0) {
                self._frame_counter = (self._frame_counter + 1) % self.blink;
                if (self._frame_counter == 0) {
                    self._show = !self._show;
                }
                if (!self._show) {
                    return;
                }
            }
        }
        
        r.DrawRectangle(
            @intFromFloat(position[0]),
            @intFromFloat(position[1]),
            @intFromFloat(self.size[0]),
            @intFromFloat(self.size[1]),
            self.color
        );
    } 
};

pub const CursorType = enum {
    // see emacs
    Box,
    Bar,
    Hbar,
};


