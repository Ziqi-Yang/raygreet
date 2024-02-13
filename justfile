run:
    fakegreet "zig build run"

run-drm:
    zig build -Dplatform_drm
    sudo fakegreet "zig-out/bin/raygreet"

debug-drm:
    sudo zig build -Dplatform_drm
    sudo chmod a+s ./zig-out/bin/raygreet

release-drm:
    sudo zig build -Doptimize=ReleaseSafe -Dplatform_drm
    sudo chmod a+s ./zig-out/bin/raygreet

install: release-drm
    sudo cp ./zig-out/bin/raygreet /usr/bin/raygreet
    # since cp to /usr/bin changes permission, we need to re-chmod
    sudo chmod a+s /usr/bin/raygreet
    ls -l /usr/bin/raygreet

doc:
    pandoc -o ./README.md ./README.typ 
    
