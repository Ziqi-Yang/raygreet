run:
    fakegreet "zig build run"

release-drm:
    zig build -Doptimize=ReleaseSafe -Dplatform_drm

release:
    zig build -Doptimize=ReleaseSafe

doc:
    pandoc -o ./README.md ./README.typ 
    
drm:
    zig build -Dplatform_drm
    sudo fakegreet "zig-out/bin/raygreet"
