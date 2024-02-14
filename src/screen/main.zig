const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const Vector2 = @import("../util.zig").Vector2;
const config = @import("../config.zig");
const i_text = @import("../component/text.zig");
const InputTextField = i_text.InputTextField;
const Label = i_text.Label;
const ArenaAllocator = std.heap.ArenaAllocator;
const status = @import("../status.zig");

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
    cmd: []const u8, // corresponding to config.Config.cmd field

    _user_name: []const u8, // entered user name

    input_text_field: InputTextField,
    // this is added mostly because the confusion when error ( password red with log message "nope")
    user_name_indicator: Label,
    title: Label,
    log: Label, // error log

    const user_name_indicator_offset = Vector2 { 0.05, 0.075 * 2.5 / 4.0 };
    const title_offset = Vector2 { 0.05, 0.075 };
    const input_text_field_offset = Vector2 { 0.15, 0.25 };

    pub fn new(allocator: std.mem.Allocator) !Self {
        if (!r.IsWindowReady()) return error.WindowNotInitialized;
        
        const SCREEN_WIDTH: f16 = @floatFromInt(@as(u16, @intCast(r.GetScreenWidth())));
        const SCREEN_HEIGHT: f16 = @floatFromInt(@as(u16, @intCast(r.GetScreenHeight())));
        const input_text_field_box_size: Vector2 = .{ SCREEN_WIDTH * 0.7, SCREEN_HEIGHT / 2};

        const CONFIG = config.get_config();
        
        const title_box_size: Vector2 = .{ 0.0, SCREEN_HEIGHT * 0.1 }; // don't limit the width
        var title = try Label.new(
            allocator,
            title_box_size,
            r.DARKGRAY,
            r.LIGHTGRAY,
            "Username:",
            r.GetFontDefault()
        );
        var user_name_indicator = try Label.new(
            allocator,
            title_box_size / Vector2 {4, 4},
            r.BLANK,
            r.DARKGRAY,
            "",
            r.GetFontDefault()
        );
        var log = try Label.newFixedSize(
            allocator,
            .{ SCREEN_WIDTH * 0.9 - title.box.getSize()[0], title.box.getSize()[1] },
            r.BLANK,
            r.MAROON,
            "",
            r.GetFontDefault(),
            title.font_size / 4,
            true
        );
        var main_screen: Self = .{
            .screen_size = .{ SCREEN_WIDTH, SCREEN_HEIGHT },
            .input_text_field = try InputTextField.new(input_text_field_box_size, .visible, null),
            .user_name_indicator = user_name_indicator,
            .title = title,
            .log = log,
            .arena_impl = try allocator.create(ArenaAllocator),
            .gipc = undefined,
            .cmd = CONFIG.cmd,
            ._user_name = undefined,
        };
        errdefer {
            title.deinit();
            user_name_indicator.deinit();
            log.deinit();
            allocator.destroy(main_screen.arena_impl);
        }
        main_screen.gipc = try GreetdIPC.new(null, allocator);
        main_screen.arena_impl.* = ArenaAllocator.init(allocator);
        return main_screen;
    }

    pub fn init(self: *Self) void {
        // we don't pass enter_key_press_func() in `InputTextField.new` in `init`
        // function since the function pointer it returned points to the old
        // `screen` (if we define a var), not the one copied in the `return`
        // clause. (stack lifetime issue)
        self.input_text_field.func_enter_key_down = self.enter_key_press_func();
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.arena_impl.child_allocator;
        self.arena_impl.deinit();
        allocator.destroy(self.arena_impl);
        self.gipc.deinit();
        self.user_name_indicator.deinit();
        self.title.deinit();
        self.log.deinit();
    }

    fn recalculateLogSizeOffset(self: *Self) !void {
        const title_size = self.title.box.getSize();
        const size = .{self.screen_size[0] * 0.9 - title_size[0], title_size[1]};
        try self.log.updateBox(null, size);
    }

    /// update the title text, also recalculate the log box size & offset
    fn updateTitle(self: *Self, title: []const u8) !void {
        try self.title.updateText(title);
        try self.recalculateLogSizeOffset();
    }

    fn updateLog(self: *Self, log: []const u8) !void {
        if (log.len == 0 or log[0] == 0) { // clear log (we also need to clean color)
            self.title.setBgColor(r.DARKGRAY);
            self.user_name_indicator.fg_color = r.DARKGRAY;
        } else {
            self.title.setBgColor(r.MAROON);
            self.user_name_indicator.fg_color = r.MAROON;
        }
        
        try self.log.updateText(log);
        // since log is in compact mode, we also need to update the log offset
        try self.recalculateLogSizeOffset();
    }

    pub fn handleInput(self: *Self) !void {
        if (r.IsKeyPressed(r.KEY_ESCAPE)) {
            try self.updateLog("");
            try self.update_user_name("");
            
            const request: Request = .{ .cancel_session = .{} };
            try self._authenticate(request);
            
            const state = .{ .input_user = null };
            try self.updateState(state);
        }
    }

    pub fn draw(self: *Self) !void {
        r.ClearBackground(r.RAYWHITE);
        try self.handleInput();
        const response: ?Response = switch (self.state) {
            inline else => |*v| blk: {
                const old = v.*;
                v.* = null;
                break :blk old;
            }
        };
        _ = response;
        const user_name_indicator_position = self.screen_size * user_name_indicator_offset;
        self.user_name_indicator.draw(user_name_indicator_position);

        const title_position = self.screen_size * title_offset;
        self.title.draw(title_position);
        
        const title_size = self.title.box.getSize();
        const log_size = self.log.box.getSize();
        const t_btm_r = title_position + title_size;
        self.log.draw(t_btm_r - Vector2 { 0.0, log_size[1]});
        
        self.input_text_field.draw( self.screen_size * input_text_field_offset );
    }

    fn updateState(self: *Self, state: State) !void {
        const arena = self.arena_impl.allocator();
        switch (state) {
            .input_user => {
                try self.updateTitle("Username:");
            },
            .answer_question => | resp | {
                switch (resp.?.auth_message.auth_message_type) {
                    .visible => self.input_text_field.setMode(.visible),
                    .secret => self.input_text_field.setMode(.invisible),
                    else => {}
                }
                const text = try arena.dupeZ(u8, resp.?.auth_message.auth_message);
                try self.updateTitle(text);
            }
        }
        self.input_text_field.reset();
        self.state = state;
    }

    fn _authenticate(self: *Self, req: Request) !void {
        const allocator = self.arena_impl.allocator();
        try self.gipc.sendMsg(req);
        const resp = try self.gipc.readMsg();
        switch (resp) {
            .success => {
                switch (req) {
                    .create_session => {
                        // normally greetd won't return a success message for this type of request
                        // TODO test a user without password
                    },
                    .post_auth_message_response => {
                        // start session
                        const request = .{ .start_session = .{
                            .cmd = &.{ self.cmd },
                            .env = &.{}
                        }};
                        try self._authenticate(request);
                    },
                    .start_session => {
                        // exit
                        status.should_close_window = true;
                    },
                    .cancel_session => {
                        if (self._user_name.len != 0) { // not empty, important for `handleInput` function
                            const request: Request = .{ .create_session = .{ .username = self._user_name }};
                            try self._authenticate(request);
                        }
                    },
                }
            },
            .err => |err| {
                // don't care about err_type
                try self.updateLog(try allocator.dupeZ(u8, err.description));
                // cancel session
                const request: Request = .{ .cancel_session = .{} };
                try self._authenticate(request);
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

    fn update_user_name(self: *Self, name: []const u8) !void {
        const allocator = self.arena_impl.allocator();
        self._user_name = name;
        if (name.len != 0 and name[0] != 0) {
            const text = try std.mem.concat(allocator, u8, &.{"Username: ", name});
            try self.user_name_indicator.updateText(text);
            return;
        }
        try self.user_name_indicator.updateText(name);
    } 

    pub fn authenticate(self: *Self) !void {
        const arena = self.arena_impl.allocator();
        try self.updateLog(""); // clean log
        switch (self.state) {
            .input_user => {
                const text = try self.input_text_field.getTextAlloc(arena);
                try self.update_user_name(text);

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

