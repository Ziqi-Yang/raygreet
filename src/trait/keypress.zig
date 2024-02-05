const screen = @import("../screen.zig");

pub const KeyPress = union(enum) {
    input_user_screen_enter_key_function: screen.InputUserScreenEnterKeyFunction,

    pub fn press_key(self: KeyPress) void {
        switch (self) {
            inline else => |func| func.press_key(),
        }
    }
};
