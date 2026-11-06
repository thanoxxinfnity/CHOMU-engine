# Atmosphere - F-44, F-42, F-43, F-46

All read `ChomuSettings.photosensitivity_safe` and `ChomuSettings.effects_intensity`.

## ChomuTensionDirector (Node)
`tension` 0..1 = weights x (threat proximity, line of sight, darkness, recent damage, time since last scare), with attack/release smoothing. Threats come from `threats` or group `chomu_threat`. Darkness comes from `ChomuLightProbe` at the player, or `darkness_override`. Hysteretic states: BUILD_UP -> PEAK (tension >= 0.75 for 0.5 s) -> RELAX (after `peak_min` and below 0.55, or `peak_max`) -> BUILD_UP (after `relax_min` and below 0.3). Signals `state_changed` and `scare_window_opened` (rate-limited by `min_scare_interval`). Call `register_scare()` and `register_damage(x)`.

## ChomuFlickerCircuit (Node, child of a Light3D)
One `RandomNumberGenerator` seed drives both the light-energy dips and a procedural mains buzz (AudioStreamGenerator, 100 Hz + harmonic + crackle). The buzz drops out when the bulb dips. Same seed + same deltas = same flicker. Safe mode keeps it to 3 dips per second or fewer, makes dips shallow (depth 0.35 max) and fades them slowly.

## ChomuFearExposure (Node, child of a Camera3D)
Simulated eye adaptation on `CameraAttributesPractical.exposure_multiplier`: fast toward bright, slow toward dark, worked out in log space. `hold_darkness(seconds)` stops adaptation along `hold_curve`, so a dark room stays dark. Optional extra darkening from the tension value.

## ChomuStressPostFX (CanvasLayer)
Full-screen shader (`shaders/stress_postfx.gdshader`): black vignette, radial chromatic aberration, grain, desaturation, plus camera FOV breathing, all scaled by stress (usually `tension`). Safe mode caps aberration at 0.002, turns grain off, keeps breathing under 0.4 Hz and 0.8 degrees, and slew-limits the stress value.
