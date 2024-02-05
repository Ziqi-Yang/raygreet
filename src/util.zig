// I don't use Vector2 in raylib since Vector2 struct defined in raymath cannot
// be used with Vector2 struct in raylib(Zig seems them as different struct,
// so no operation can do with Vector2 in raylib/raymath)
pub const Vector2 = @Vector(2, f16);



// TODO current only support US keymap.
// note that the left character is mapped from scan code to US keymap.
// see: https://github.com/raysan5/raylib/discussions/3773
pub fn upperCaseChar(char: u8) u8 {
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

