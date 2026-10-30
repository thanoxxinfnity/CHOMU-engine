# Chomu City v0.1 (CHoMU Engine / Godot 4.7.2)

Open-world city demo for Android. Open this folder in CHoMU Engine (Import -> project.godot).

* Main scene: `scenes/Main.tscn` -> Main Menu -> Loading (threaded) -> `scenes/World.tscn`
* Renderer: Mobile (Vulkan). Graphics presets Low / Medium / High / Ultra in Settings.
* Keyboard (desktop testing): WASD move, Shift run, Space jump, F enter/exit car, H horn, Ctrl drift, Esc pause, right-mouse drag = camera.
* Gameplay demo/autopilot: run with `-- --demo` (used to record the trailer video).

## Scripts
| Script | What it does |
|---|---|
| Game.gd (autoload) | settings, virtual input shared by touch controls / keyboard |
| City.gd | procedural 400x400 m city: road grid shader, sidewalks, buildings, lights, trees, collision |
| DayNight.gd | sun/moon, HDRI sky shader, fog, glow, quality presets |
| Player.gd | third-person character, AnimationTree state machine |
| Car.gd | VehicleBody3D car built from Kenney GLB, sounds, lights |
| Traffic.gd / Pedestrians.gd | AI cars on lane loops, NPC walkers |
| CameraRig.gd | SpringArm3D orbit/chase camera |
| HUD.gd, TouchControls.gd, Minimap.gd | UI |
| MainMenu.gd, Loading.gd, SettingsPanel.gd | menus |
