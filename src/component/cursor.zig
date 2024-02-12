const r = @cImport(@cInclude("raylib.h"));
const Vector2 = @import("../util.zig").Vector2;
const status = @import("../status.zig");
const Box = @import("box.zig").Box;

pub const Cursor = struct {
    _show: bool = true,
    _frame_counter: u8 = 0,
    /// don't directly set size
    box: Box,
    color: r.Color,
    /// per num frame changes hide/show status (0 means no blink)
    blink: u8 = 0,
    type: CursorType = CursorType.Bar,

    pub fn setSize(self: *Cursor, font_size: f16) Vector2 {
        const size: Vector2 = self.calculateSize(font_size);
        self.box.size = size;
        return size;
    }

    pub fn calculateSize(self: *const Cursor, font_size: f16) Vector2 {
        return switch (self.type) {
            .Box => .{ font_size * 0.75, font_size},
            .Bar => .{ font_size * 0.1, font_size},
            .Hbar => .{ font_size, font_size * 0.1 }
        };
    }

    pub fn resetBlinkFrameCounter(self: *Cursor) void {
        self._frame_counter = 0;
    }

    pub fn resetBlink(self: *Cursor) void {
        if (self.blink != 0) {
            self._show = true;
            self._frame_counter = 0;
        }
    }

    pub fn draw(self: *Cursor, outer_offset: Vector2) void {
        // blink
        if (self.blink != 0) {
            self._frame_counter = (self._frame_counter + 1) % self.blink;
            if (self._frame_counter == 0) {
                self._show = !self._show;
            }
            if (!self._show) {
                return;
            }
        }

        const offset = outer_offset + self.box.offset;
        const box_size = self.box.getSize();
        
        r.DrawRectangle(
            @intFromFloat(offset[0]),
            @intFromFloat(offset[1]),
            @intFromFloat(box_size[0]),
            @intFromFloat(box_size[1]),
            self.color
        );
    } 
};

pub const CursorType = enum {
    // Emacs
    Box,
    Bar,
    Hbar,
};


