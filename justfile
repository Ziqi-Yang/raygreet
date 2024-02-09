run:
    fakegreet "zig build run"

doc:
    pandoc -o ./README.md ./README.typ 
    
drm:
    zig build -Dplatform_drm
    sudo fakegreet "zig-out/bin/raygreet"
