const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const Vector2 = @import("../util.zig").Vector2;
const Cursor = @import("../component/cursor.zig").Cursor;
const CursorOption = @import("../config.zig").CursorOption;
const InputTextField = @import("../component/input_text_field.zig").InputTextField;

const greetd_ipc = @import("greetd_ipc");
const GreetdIPC = greetd_ipc.GreetdIPC;
const Request = greetd_ipc.Request;
const Response = greetd_ipc.Response;

pub const MainScreen = struct {
    pub const State = union(enum) {
        input_user: ?Response, 
        input_password: ?Response,
        answer_question: ?Response,
    };

    const Self = @This();

    state: State = .{ .input_user = null },
    screen_size: Vector2,
    input_text_field: InputTextField,
    allocator: std.mem.Allocator,
    gipc: GreetdIPC,

    pub fn new(allocator: std.mem.Allocator) !Self {
        if (!r.IsWindowReady()) return error.WindowNotInitialized;
        
        const SCREEN_WIDTH: f16 = @floatFromInt(@as(u16, @intCast(r.GetScreenWidth())));
        const SCREEN_HEIGHT: f16 = @floatFromInt(@as(u16, @intCast(r.GetScreenHeight())));
        const box_size: Vector2 = .{ SCREEN_WIDTH * 0.7, SCREEN_HEIGHT / 2};
        return .{
            .screen_size = .{ SCREEN_WIDTH, SCREEN_HEIGHT },
            // we don't pass enter_key_press_func() in `InputTextField.new` since the function
            // pointer it returned points to the old `screen` (if we define a var), not the one copied
            // in the `return` caluse. (stack lifetime issue)
            .input_text_field = try InputTextField.new(box_size, null),
            .allocator = allocator,
            .gipc = try GreetdIPC.new(null, allocator)
        };
    }

    pub fn init(self: *Self) void {
        self.input_text_field.func_enter_key_down = self.enter_key_press_func();
    }

    pub fn deinit(self: *Self) void {
        self.gipc.deinit();
    }

    pub fn draw(self: *Self) !void {
        r.ClearBackground(r.RAYWHITE);
        const response: ?Response = switch (self.state) {
            inline else => |*v| blk: {
                const old = v.*;
                v.* = null;
                break :blk old;
            }
        };
        _ = response;
        self.input_text_field.draw(Vector2 { self.screen_size[0] * 0.15 , self.screen_size[1] / 4 });
    }

    pub fn _authenticate(self: *Self, req: Request) !void {
        try self.gipc.sendMsg(req);
        const resp = try self.gipc.readMsg();
        switch (resp) {
            .success => {
                switch (req) {
                    .create_session => {
                        // TODO test a user without password
                    },
                    .post_auth_message_response => {
                        // start session
                        // TODO 
                    },
                    .start_session,
                    .cancel_session => {
                        // exit
                        r.CloseWindow();
                    },
                }
            },
            .err => {
                // handle error
            },
            .auth_message => |auth_msg| {
                switch (auth_msg.auth_message_type) {
                    .visible => {
                        self.state = .{ .answer_question = resp };
                        self.input_text_field.reset();
                    },
                    .secret => {
                        self.state = .{ .input_password = resp };
                        self.input_text_field.reset();
                    },
                    else => {
                        switch (self.state) {
                            inline else => |*v| v.* = resp,
                        }
                    }
                }
            }
        }
    } 

    pub fn authenticate(self: *Self) !void {
        switch (self.state) {
            .input_user => {
                const text = try self.input_text_field.getTextAlloc(self.allocator);
                errdefer self.allocator.free(text);
                defer self.allocator.free(text);

                const req: Request = .{ .create_session = .{ .username = text }};
                try self._authenticate(req);
            },
            .input_password,
            .answer_question => {
                const text = try self.input_text_field.getTextAlloc(self.allocator);
                errdefer self.allocator.free(text);
                defer self.allocator.free(text);

                const req: Request = .{ .post_auth_message_response = .{ .response = text} };
                try self._authenticate(req);
            },
        }
    }

    pub inline fn enter_key_press_func(self: *Self) *const fn () void {
        return (struct {
            var screen: *Self = undefined;
            
            pub fn init(itf: *Self) *const @TypeOf(run) {
                screen = itf;
                return &run;
            }

            fn run() void {
                screen.authenticate() catch {
                    // TODO
                    std.debug.print("{s}\n", .{"Error Occurs"});
                };
            }
        }).init(self);
    }
};

