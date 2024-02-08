const std = @import("std");
const status = @import("status.zig");
pub const MainScreen = @import("screen/main.zig").MainScreen;

pub var main_screen: MainScreen = undefined;

pub const RayGreetScreen = union(enum) {
    main_screen: *MainScreen,

    pub fn draw(self: RayGreetScreen) !void {
        try switch (self) {
            inline else => |scn| scn.draw()
        };
    }
};
