const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const Vector2 = @import("../util.zig").Vector2;
const Cursor = @import("../component/cursor.zig").Cursor;
const CursorOption = @import("../config.zig").CursorOption;
const InputTextField = @import("../component/input_text_field.zig").InputTextField;
const Label = @import("../component/box.zig").Label;

const ArenaAllocator = std.heap.ArenaAllocator;

const greetd_ipc = @import("greetd_ipc");
const GreetdIPC = greetd_ipc.GreetdIPC;
const Request = greetd_ipc.Request;
const Response = greetd_ipc.Response;

pub const MainScreen = struct {
    pub const State = union(enum) {
        input_user: ?Response, 
        answer_question: ?Response,
    };

    const Self = @This();

    state: State = .{ .input_user = null },
    screen_size: Vector2,
    arena_impl: *ArenaAllocator,
    gipc: GreetdIPC,
    input_text_field: InputTextField,
    title: Label,

    pub fn new(allocator: std.mem.Allocator) !Self {
        if (!r.IsWindowReady()) return error.WindowNotInitialized;
        
        const SCREEN_WIDTH: f16 = @floatFromInt(@as(u16, @intCast(r.GetScreenWidth())));
        const SCREEN_HEIGHT: f16 = @floatFromInt(@as(u16, @intCast(r.GetScreenHeight())));
        const input_text_field_box_size: Vector2 = .{ SCREEN_WIDTH * 0.7, SCREEN_HEIGHT / 2};
        
        const title_box_size: Vector2 = .{ 0.0, SCREEN_HEIGHT * 0.1 }; // don't limit the width
        const main_screen = .{
            .screen_size = .{ SCREEN_WIDTH, SCREEN_HEIGHT },
            // we don't pass enter_key_press_func() in `InputTextField.new` since the function
            // pointer it returned points to the old `screen` (if we define a var), not the one copied
            // in the `return` caluse. (stack lifetime issue)
            .title = Label.new(
                title_box_size,
                r.DARKGRAY,
                r.LIGHTGRAY,
                "Username:",
                r.GetFontDefault()
            ),
            .input_text_field = try InputTextField.new(input_text_field_box_size, null),
            .arena_impl = try allocator.create(ArenaAllocator),
            .gipc = try GreetdIPC.new(null, allocator)
        };
        main_screen.arena_impl.* = ArenaAllocator.init(allocator);
        return main_screen;
    }

    pub fn init(self: *Self) void {
        self.input_text_field.func_enter_key_down = self.enter_key_press_func();
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.arena_impl.child_allocator;
        self.arena_impl.deinit();
        allocator.destroy(self.arena_impl);
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
        self.title.draw( self.screen_size * Vector2 { 0.05, 0.075 } );
        self.input_text_field.draw( self.screen_size * Vector2 { 0.15, 0.25 } );
    }

    fn updateState(self: *Self, state: State) !void {
        const arena = self.arena_impl.allocator();
        switch (state) {
            .input_user => {
                self.title.updateText("USERNAME");
            },
            .answer_question => | resp | {
                const text = try arena.dupeZ(u8, resp.?.auth_message.auth_message);
                self.title.updateText(text);
            }
        }
        self.input_text_field.reset();
        self.state = state;
    }

    fn _authenticate(self: *Self, req: Request) !void {
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
            .err => |err| {
                // handle error
                _ = err;
                // switch (err.err_type) {
                //     .auth_error => {
                //         res = LoginResult.failure;
                //     },
                //     .@"error" => {
                //         try stderr.print("login error: {s}", .{err.description});
                //     }
                // }
            },
            .auth_message => |auth_msg| {
                switch (auth_msg.auth_message_type) {
                    .visible,
                    .secret => {
                        const state = .{ .answer_question = resp };
                        try self.updateState(state);
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
        const arena = self.arena_impl.allocator();
        switch (self.state) {
            .input_user => {
                const text = try self.input_text_field.getTextAlloc(arena);

                const req: Request = .{ .create_session = .{ .username = text }};
                try self._authenticate(req);
            },
            .answer_question => {
                const text = try self.input_text_field.getTextAlloc(arena);

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

