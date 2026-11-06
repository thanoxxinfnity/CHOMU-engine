# ChomuReplay (autoload) - F-68

`start_recording(seed, actions)` records every tracked InputMap action's pressed state and strength once per physics tick, plus anything passed through `custom(key, live_value)` (mouse delta, sticks). `start_playback()` re-seeds `seed()` and `ChomuReplay.rng`, then injects the recorded states with `Input.action_press/release` at physics priority -1000, before gameplay runs. Gameplay calls `checksum(state)` every tick. During playback each value is compared to the recording, and the first mismatch fires `desync(frame, expected, got)` (simple desync forensics). `save_to(path)` / `load_from(path)` store the replay.

Determinism rules: put gameplay in `_physics_process`, take randomness only from `ChomuReplay.rng`, read analog input through `custom()`, keep the tick rate fixed. Rigid-body physics is not guaranteed bit-exact across machines or engine versions. Real keyboard input still reaches `Input` during playback, so ignore it while `is_playing()`.
