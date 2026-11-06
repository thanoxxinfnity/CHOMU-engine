# AI - F-49, F-50, F-52

## ChomuHFSM (Node)
`add_state(name, parent, on_enter, on_exit, on_update)`, `add_transition(from, to, cond)`, `start(name)`. Transitions are checked from the outermost active state inward, so a parent's transition overrides its children. Entering a parent drops into its first child. `set_behavior(state, ChomuBT)` ticks a behaviour tree while that state is the leaf, which gives the HFSM (mode) + BT/utility (action) hybrid. `history` keeps the last 64 leaf paths.

## ChomuBT (RefCounted)
Builders: `sequence`, `selector`, `utility(kids, score_callables)`, `invert`, `condition(fn(bb))`, `action(fn(bb, dt) -> SUCCESS/FAILURE/RUNNING)`, `cooldown(child, s)`.

## ChomuGOAP (RefCounted)
`add_action(name, pre, eff, cost, cost_fn)`. `plan(state, goal)` runs A* over Dictionary world states (heuristic = count of unmet goal keys; a missing bool key counts as false). Time-sliced: `start()` then `step(budget)` per frame until it returns FOUND/FAILED. `max_expansions` guards the search.

## ChomuPerception (Node3D on the agent's head)
- **Sight**: range + FOV cone + raycast line of sight + light check. A target whose `ChomuLightProbe` luminance is too low is only seen inside `close_range`, and the luminance needed grows with distance.
- **Hearing**: `ChomuPerception.emit_noise(tree, pos, loudness)`. Heard within `hearing_range * loudness`, halved when a raycast is blocked.
- **Memory**: confidence 1 when seen, then decays at `memory_decay` per second and is forgotten below `forget_below`.
- Signals: `target_spotted`, `target_lost`, `noise_heard`. Targets are in group `chomu_perceivable`.

`ChomuLightProbe` (core) is a CPU estimate: Omni/Spot/Directional lights, range falloff, spot cone, optional occlusion ray, plus ambient.
