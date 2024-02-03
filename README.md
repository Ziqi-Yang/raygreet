# RayGreet

This document is generated by `README.typ` using
[pandoc](https://pandoc.org/).

## Develop

### Test in TTY

Change to `TTY<number>` using key `Ctrl + Alt + F<number>`, then run

``` bash
zig build -Dplatform_drm
sudo ./zig-out/bin/raygreet
```

## Current Issues

1.  Only officially support US keyboards. Other keyboards may have wrong
    mappings for some keys.

It is due to that Raylib currently uses a US keymap to map
[scancode](https://en.wikipedia.org/wiki/Scancode) to key code. See
[raylib
source](https://github.com/raysan5/raylib/blob/7ec43022c177cbf00b27c9e9ab067bd6889957a4/src/platforms/rcore_drm.c#L145).
You can use `localectl status` to view the current keyboard
configuration, and you can check `upperCaseChar` function in
`src/component/input_text_field.zig` to verify whether shift character
function suits for you.

Here is the
[discussion](https://github.com/raysan5/raylib/discussions/3773).

Developer notes:\

1.  evdev key code: /usr/share/X11/xkb/keycodes/evdev

2.  scancode: /usr/include/linux/input-event-codes.h
