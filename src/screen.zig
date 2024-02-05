const std = @import("std");
const status = @import("status.zig");
pub const InputUserScreen = @import("screen/input_user.zig");
pub const InputPasswordScreen = @import("screen/input_password.zig");

pub var input_user_screen: InputUserScreen = undefined;
pub var input_password_screen: InputPasswordScreen = undefined;

pub const RayGreetScreen = union(enum) {
    input_user_screen: *InputUserScreen,
    input_password_screen: *InputPasswordScreen,

    pub fn draw(self: RayGreetScreen) !void {
        try switch (self) {
            inline else => |scn| scn.draw()
        };
    }
};


pub const InputUserScreenEnterKeyFunction = struct {
    pub fn press_key(_: *const InputUserScreenEnterKeyFunction) void {
        status.current_screen = RayGreetScreen {
            .input_password_screen = &input_password_screen
        };
    }
};

pub const InputPasswordScreenEnterKeyFunction = struct {
    pub fn press_key(_: *const InputPasswordScreenEnterKeyFunction) void {
        std.debug.print("{s}\n", .{"El Psy Kongaroo"});
    }
};
