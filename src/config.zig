// current use json standard library instead, since zig toml parsers are not mature
// or not following the master branch of zig
const std = @import("std");
const json = std.json;
const fs = std.fs;

const Config = @This();

window_name: []const u8 = "RayGreet",
fps: u8 = 60,
input_text_size_base: u8 = 100,

pub const CONFIG_FILE_PATH = "/etc/greetd/raygreet.json";

pub fn parse_config(allocator: std.mem.Allocator) !Config {
    return parse_config_file(allocator, CONFIG_FILE_PATH);
}

fn parse_config_file(allocator: std.mem.Allocator, path: []const u8) !Config {
    const file = fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
        error.FileNotFound => unreachable,
        else => return err
    };
    const config_json = try file.readToEndAlloc(allocator, 1 << 10);
    defer allocator.free(config_json);
    
    return try json.parseFromSliceLeaky(Config, allocator, config_json, .{
        .ignore_unknown_fields = true
    });
}

test "parse config" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const path = try std.fs.path.join(
        allocator,
        &.{
            try std.fs.cwd().realpathAlloc(allocator, "."),
            "../test/config.json"
        }
    );
    const my_json = try parse_config_file(
        allocator,
        path
    );

    try std.testing.expectEqualStrings("RayGreet", my_json.window_name);
    try std.testing.expectEqual(30, my_json.fps);
}

