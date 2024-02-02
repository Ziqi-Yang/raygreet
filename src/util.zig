// I don't use Vector2 in raylib since Vector2 struct defined in raymath cannot
// be used with Vector2 struct in raylib(Zig seems them as different struct,
// so no operation can do with Vector2 in raylib/raymath)
pub const Vector2 = @Vector(2, f16);
