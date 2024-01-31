// /// width, height
// pub const Size = struct {u16, u16};

// I don't use Vector2 in raylib since Vector2 struct defined in raymath cannot
// be used with Vector2 struct in raylib(Zig seems them as different struct,
// so no operation can do with Vector2 in raylib/raymath)
pub const Vector2 = struct {
    x: f16,
    y: f16,

    pub fn add(self: *const Vector2, other: *const Vector2) Vector2 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }
};
