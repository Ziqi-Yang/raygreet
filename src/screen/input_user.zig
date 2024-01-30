const r = @cImport(@cInclude("raylib.h"));

const InputUserScreen = @This();

pub fn draw(self: *InputUserScreen) !void {
    _ = self;
    r.ClearBackground(r.RAYWHITE);
    r.DrawText("Input User Screen", 40, 40, 40, r.GRAY);
}
