const r = @cImport(@cInclude("raylib.h"));

const InputPasswordScreen = @This();

pub fn draw(self: *InputPasswordScreen) !void {
    _ = self;
    r.ClearBackground(r.RAYWHITE);
    r.DrawText("Input Password Screen", 40, 40, 40, r.GRAY);
}
