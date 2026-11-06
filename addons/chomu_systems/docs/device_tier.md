# ChomuDeviceTier (autoload) - F-1, F-3, F-4, F-5

Autoload name `ChomuDeviceTier` (added by the plugin). File: `core/device_tier.gd`.

- **First launch**: `run_benchmark()` runs ~2 s, time-sliced so frames keep coming: a CPU maths loop (40%) and render frame times (60%; headless spends it all on CPU). Score = CPU + GPU fps + cores + RAM -> `Tier.LOW/MID/HIGH/ULTRA`, then `device_db` (substring of `vendor:adapter:model`) caps weak chips / lifts strong ones. Result cached in `user://chomu_device_tier.cfg` (re-runs if the device key changes). `clear_cache()` forces a new run.
- **apply_tier(t)**: sets root viewport MSAA, FXAA (Forward+/Mobile only), shadow atlas sizes, mesh LOD threshold, FSR1 (Forward+ only, else bilinear), 3D resolution scale. `apply_to_environment(env)` sets SSAO/SSIL/SDFGI/glow/volumetric fog. Signal `tier_applied(tier, settings)`.
- **Power profiles**: `set_power_profile(PERFORMANCE|BALANCED|SAVER)` -> fps cap 0/60/30 and DRS target. `auto_power_profile()` reads `/sys/class/power_supply/*/status` (plugged -> Performance, battery -> Balanced).
- **DRS** (`drs_step(ms)`): blueprint formula. `y = EWMA(ms, 0.2) + k*sigma`, `scale' = clamp(scale*sqrt(target/y), s_min, 1)`, hysteresis 0.03, max step 0.1. Frame time is the viewport's measured GPU/CPU render time when the driver reports it, else frame delta. Turned off when headless.
- **Thermal governor**: reads battery temperature from sysfs (`/sys/class/power_supply/battery/temp`; Android 10+ often blocks it). When it can't, it uses the frame-time trend (linear slope over 30 s, while DRS is pinned at its minimum). Stages: 1 = DRS at minimum, 2-3 = tier -1 (effects), and the signal `thermal_stage_changed` lets your game lower sim LOD at stage 3.
