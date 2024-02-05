const std = @import("std");
const status = @import("status.zig");
pub const InputUserScreen = @import("screen/input_user.zig").InputUserScreen;

pub var input_user_screen: InputUserScreen = undefined;

pub const RayGreetScreen = union(enum) {
    input_user_screen: *InputUserScreen,

    pub fn draw(self: RayGreetScreen) !void {
        try switch (self) {
            inline else => |scn| scn.draw()
        };
    }
};
