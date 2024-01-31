const std = @import("std");
pub const InputUserScreen = @import("screen/input_user.zig");
pub const InputPasswordScreen = @import("screen/input_password.zig");

pub const RayGreetScreen = union(enum) {
    input_user_screen: *InputUserScreen,
    input_password_screen: *InputPasswordScreen,

    pub fn draw(self: RayGreetScreen) !void {
        try switch (self) {
            inline else => |scn| scn.draw()
        };
    }
};
