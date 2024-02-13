run:
    fakegreet "zig build run"

run-drm:
    sudo zig build -Dplatform_drm
    sudo chmod a+s ./zig-out/bin/raygreet
    fakegreet "zig-out/bin/raygreet"

debug-drm:
    sudo zig build -Dplatform_drm
    sudo chmod a+s ./zig-out/bin/raygreet

release-drm:
    sudo zig build -Doptimize=ReleaseSafe -Dplatform_drm
    sudo chmod a+s ./zig-out/bin/raygreet

doc:
    pandoc -o ./README.md ./README.typ 
    
