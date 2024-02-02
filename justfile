run:
    zig build run
    
drm:
    zig build -Dplatform_drm
    sudo ./zig-out/bin/raygreet
