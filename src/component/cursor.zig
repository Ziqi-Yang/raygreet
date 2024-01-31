const r = @cImport(@cInclude("raylib.h"));
const Size = @import("../util.zig").Size;

pub const Cursor = struct {
    color: r.Color,
    blink: bool = true,
    cursor_type: CursorType = CursorType.Bar,

    pub fn getCursorSize(self: *Cursor, font_size: u16) Size {
        const fz: f16 = @floatFromInt(font_size);
        return switch (self.cursor_type) {
            .Box => .{@intFromFloat(fz * 0.75), font_size},
            .Bar => .{@intFromFloat(fz * 0.1), font_size},
            .Hbar => .{font_size, @intFromFloat(fz * 0.1) }
        };
    }
};

pub const CursorType = enum {
    // see emacs
    Box,
    Bar,
    Hbar,
};

