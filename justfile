run:
    zig build run

doc:
    pandoc -o ./README.md ./README.typ 
    
drm:
    zig build -Dplatform_drm
    sudo ./zig-out/bin/raygreet
