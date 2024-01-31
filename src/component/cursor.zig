const r = @cImport(@cInclude("raylib.h"));
const Vector2 = @import("../util.zig").Vector2;

pub const Cursor = struct {
    _show: bool = true,
    _frame_counter: u8 = 0,
    color: r.Color,
    /// per num frame changes hide/show status (0 means no blink)
    blink: u8 = 0,
    size: Vector2 = .{.x = 1.0, .y = 1.0},
    type: CursorType = CursorType.Bar,

    pub fn setSize(self: *Cursor, font_size: u16) Vector2 {
        const size: Vector2 = self.calculateSize(font_size);
        self.size = size;
        return size;
    }

    pub fn calculateSize(self: *const Cursor, font_size: u16) Vector2 {
        const fz: f16 = @floatFromInt(font_size);
        return switch (self.type) {
            .Box => .{.x = fz * 0.75, .y = @floatFromInt(font_size)},
            .Bar => .{.x = fz * 0.1, .y = @floatFromInt(font_size)},
            .Hbar => .{.x = @floatFromInt(font_size), .y = fz * 0.1 }
        };
    }

    pub fn draw(self: *Cursor, position: *const Vector2) void {
        if (self.blink != 0) {
            self._frame_counter = (self._frame_counter + 1) % self.blink;
            if (self._frame_counter == 0) {
                self._show = !self._show;
            }
            if (!self._show) {
                return;
            }
        }
        r.DrawRectangle(
            @intFromFloat(position.x),
            @intFromFloat(position.y),
            @intFromFloat(self.size.x),
            @intFromFloat(self.size.y),
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


