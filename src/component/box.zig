const std = @import("std");
const util = @import("../util.zig");
const Vector2 = util.Vector2;
const r = @cImport(@cInclude("raylib.h"));

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

    pub inline fn getOffset(self: Self) Vector2 {
        return self.box.offset;
    }

    pub inline fn getSize(self: Self) Vector2 {
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
