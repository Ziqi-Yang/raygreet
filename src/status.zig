const RayGreetScreen = @import("screen.zig").RayGreetScreen;

pub const MAX_KEY_PRESSED = 16; // raylib, maximum number of pressed keys in current frame

pub var current_screen: RayGreetScreen = undefined;

/// Not actual caps lock's status, it only stands for caps lock's status in this application
pub var caps_lock_on = false;

/// Currently pressed keys. (Can be seemed as pressed simultaneously)
pub var cur_pressed_keys: [MAX_KEY_PRESSED]?u16 = [_]?u16{null} ** MAX_KEY_PRESSED;
    
/// Currently pressed chars. (Can be seemed as pressed simultaneously)
pub var cur_pressed_chars: [MAX_KEY_PRESSED]?u8 = [_]?u8{null} ** MAX_KEY_PRESSED;

