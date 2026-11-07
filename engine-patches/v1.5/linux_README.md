# CHoMU Engine 1.5 — Linux editor (aarch64)

## Contents
- `chomu-engine` — the editor binary (Linux, ARM64 / aarch64, production build, LLVM/lld)
- `chomu_assets/` — bundled content the editor reads from next to the binary:
  - `addons/` — CHoMU Character Studio, CHoMU Systems and CHoMU Ultra. Copied into every new project (turn them on in Project Settings > Plugins).
  - `templates/` — the Ultra Graphics Demo template. The other seven templates (FPS, Third-Person, Car, Horror, Open World, Anime VFX Arena, AI NPC Chat) ship in the Android build only, to keep this zip small.
- `chomu.desktop`, `chomu.png`, `chomu.svg` — desktop entry and icon
- `LICENSE.txt` — MIT licence for the engine core (applies to this build)

Keep `chomu_assets/` in the same folder as `chomu-engine`.

## Requirements
- 64-bit ARM Linux (aarch64): e.g. Raspberry Pi 5, ARM laptops/servers, Asahi Linux
- X11 session (Wayland support is not compiled in; XWayland works)
- GPU with Vulkan 1.0, or OpenGL 3.3 / OpenGL ES 3.0 (use `--rendering-driver opengl3`)

## Run
```sh
unzip CHoMU_Engine_v1.5_linux_aarch64.zip
cd CHoMU_Engine_v1.5_linux_aarch64
chmod +x chomu-engine
./chomu-engine                 # opens the Project Manager
./chomu-engine --rendering-driver opengl3   # if Vulkan is unavailable
```

## Optional: install to your menu
```sh
mkdir -p ~/.local/bin ~/.local/share/applications ~/.local/share/icons/hicolor/128x128/apps
cp -r chomu-engine chomu_assets ~/.local/bin/
cp chomu.desktop ~/.local/share/applications/
cp chomu.png ~/.local/share/icons/hicolor/128x128/apps/chomu.png
```
Make sure `~/.local/bin` is on your `PATH`.

## Notes
- This is the editor build only; export templates are not included.
- Settings and projects live in `~/.config/godot` and `~/.local/share/godot` (the engine core's standard folders).

## Changes in 1.5
- New: CHoMU Ultra graphics addon (Low / Medium / Mobile Ultra / PC Cinematic presets, device-tier auto pick, adaptive resolution, PBR / foliage / water / terrain / sky / post shaders) and the Ultra Graphics Demo template.
- Updated: CHoMU Systems addon (many more systems; its 853 headless self-tests pass).
- Version now shows 1.5 in the startup banner and About.
- Visuals of the new shaders are not yet checked on a real GPU or phone.

## Credits
Built on the open-source Godot Engine (MIT License). Not affiliated with the Godot Foundation.
