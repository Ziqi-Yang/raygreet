run: debug-drm
    zig build
    fakegreet "zig-out/bin/raygreet"

run-release:
    zig build -Doptimize=ReleaseSafe
    fakegreet "zig-out/bin/raygreet"

run-drm: debug-drm
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

install-debug: debug-drm
    sudo cp ./zig-out/bin/raygreet /usr/bin/raygreet
    # since cp to /usr/bin changes permission, we need to re-chmod
    sudo chmod a+s /usr/bin/raygreet
    ls -l /usr/bin/raygreet

doc:
    pandoc -o ./README.md ./README.typ 
    
