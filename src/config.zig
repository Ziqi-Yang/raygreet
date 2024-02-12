// current use json standard library instead, since zig toml parsers are not mature
// or not following the master branch of zig
const std = @import("std");
const json = std.json;
const fs = std.fs;
const CursorType = @import("component/cursor.zig").CursorType;

/// First you need to use `parse_config()` function to parse the configuration file
/// Then you can `get_config` anywhere to get the configuration.

var _config: ?Config = null;

pub const Config = struct {
    _frames_per_key_down: u8 = undefined,
    window_name: []const u8 = "RayGreet",
    fps: u8 = 60,
    // the command to run after a successful authentication
    cmd: []const u8 = "/bin/sh",  // default is to enter into a terminal session
    /// seconds
    keydown_speed: f16 = 0.1,
    cursor: CursorOption = CursorOption {},

    /// calculate indirect fields
    pub fn calculateFields(self: *Config) *Config {
        const fps: f16 = @floatFromInt(self.fps);
        self._frames_per_key_down = @intFromFloat(fps * self.keydown_speed);
        self.cursor._blink = @intFromFloat(fps * self.cursor.blink_speed);
        return self;
    }
};

pub const CursorOption = struct {
    _blink: u8 = undefined,
    /// seconds 
    blink_speed: f16 = 0.6,
    type: CursorType = CursorType.Bar
};


pub const CONFIG_FILE_PATH = "/etc/greetd/raygreet.json";

pub fn get_config() *Config {
    if (_config == null) {
        @panic("You should parse configuration by using `parse_config` function first!");
    }
    return &_config.?;
}

pub fn parse_config(allocator: std.mem.Allocator) !*Config {
    _config = try parse_config_file(allocator, CONFIG_FILE_PATH);
    return &_config.?;
}

fn parse_config_file(allocator: std.mem.Allocator, path: []const u8) !Config {
    const file = fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return config: {
            var config = Config {};
            break :config config.calculateFields().*;
        },
        else => return err
    };
    const config_json = try file.readToEndAlloc(allocator, 1 << 10);
    defer allocator.free(config_json);
    
    var config = try json.parseFromSliceLeaky(Config, allocator, config_json, .{
        .ignore_unknown_fields = true
    });
    return config.calculateFields().*;
}

// NOTE: test it with `pwd` == project root
test "parse config" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const path = try std.fs.path.join(
        allocator,
        &.{
            try std.fs.cwd().realpathAlloc(allocator, "."),
            "test/config.json"
        }
    );
    const my_json = try parse_config_file(
        allocator,
        path
    );

    try std.testing.expectEqualStrings("RayGreet", my_json.window_name);
    try std.testing.expectEqual(30, my_json.fps);
    try std.testing.expectEqual(0, my_json.cursor.blink);
    try std.testing.expectEqual(CursorType.Hbar, my_json.cursor.type);
    try std.testing.expectEqual(3, my_json._frames_per_key_down);
}

