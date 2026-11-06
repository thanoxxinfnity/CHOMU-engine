# CHoMU Systems (Godot 4.7 addon, MIT)

Practical runtime systems from the CHoMU Engine blueprint (F-1..F-82), written in plain GDScript for Godot 4.7. There are no native code, GDExtension or external services.

## Install
1. Copy `addons/chomu_systems/` into your project.
2. Project > Project Settings > Plugins > enable **CHoMU Systems**. This registers the autoloads `ChomuDeviceTier` and `ChomuReplay`.
3. Everything else is a `class_name` node or helper you add yourself: `ChomuTensionDirector`, `ChomuFlickerCircuit`, `ChomuFearExposure`, `ChomuStressPostFX`, `ChomuHFSM`, `ChomuBT`, `ChomuGOAP`, `ChomuPerception`, `ChomuWorldStreamer`, `ChomuActiveRagdoll`, `ChomuWind`, `ChomuWater`, `ChomuBuoyancy`, `ChomuLightProbe`, `ChomuSettings`.

## Systems
| Area | Files | Doc |
|---|---|---|
| Device tier, power, DRS, thermal | `core/device_tier.gd` (autoload) | `docs/device_tier.md` |
| Tension, flicker, fear exposure, stress FX | `atmosphere/*.gd`, `shaders/stress_postfx.gdshader` | `docs/atmosphere.md` |
| HFSM, behaviour tree, GOAP, perception | `ai/*.gd`, `core/light_probe.gd` | `docs/ai.md` |
| Deterministic replay | `replay/replay.gd` (autoload) | `docs/replay.md` |
| World streaming | `streaming/world_streamer.gd` | `docs/streaming.md` |
| Active ragdoll, wind, water, buoyancy | `physics/*.gd` | `docs/physics.md` |

Accessibility: set `ChomuSettings.photosensitivity_safe = true` (the demo's **P** key). Flicker is then capped at 3 dips per second with shallow, faded dips. Chromatic aberration and grain are cut, FOV breathing slows below 0.4 Hz, and stress changes are slew-limited. The UI uses neutral greys with cyan, amber and white accents.

## Demo
`demo/systems_demo.tscn` builds one scene that runs everything at once:
- A Wraith whose HFSM goes Patrol, then Hunt{Chase, Search}. Its BT utility picks stalk or lunge, a GOAP plan runs when it starts searching, and its perception has a light check and hearing.
- Three flickering lamps, a tension director driving the stress FX and fear exposure.
- A 5x5 grid of streamed cells.
- An active ragdoll that gets hit at 3 s.
- Wind and three floating crates.
- A replay: autopilot input is recorded for 6 s, then played back and the checksums compared.

Keys: WASD (T turns the autopilot off), 1/2/3 power profile, P safe mode. Headless run with auto-quit and a summary: `godot --headless --path <project> -- --chomu-demo-seconds=14`.

## Self-test
`tests/self_test.tscn` has 80 checks across all systems and exits with code 0 when all pass:
`godot --headless --path <project> res://addons/chomu_systems/tests/self_test.tscn`

## Blueprint coverage (honest)
The GPU and engine-core items (bindless RHI, meshlets, virtual texturing, Wasm plugin isolation, CRDT collaboration, double-precision worlds, Tracy, HDR output) are **not feasible in a GDScript addon**. They need changes inside the engine or renderer. "Done (engine)" means Godot already provides the feature and the addon only switches it per tier. "Not built" means it could be done but is outside this addon's scope.

Summary: Done: 11, Done (engine): 4, Not built: 34, Not feasible: 25, Partial: 8.

| ID | Feature | Status | Notes |
|---|---|---|---|
| F-1 | Capability probe + tier classifier | Done | ~2 s time-sliced CPU+frame-time benchmark, cores/RAM, small substring device DB, cached per device key (`core/device_tier.gd`). |
| F-2 | Fallback graph | Partial | Per-tier settings table plus renderer checks (FSR1 only on Forward+, FXAA not on Compatibility). No per-feature `requires:{...}` graph. |
| F-3 | Thermal governor | Partial | Reads battery/thermal-zone temperature from sysfs, else falls back to the frame-time trend. Escalates DRS, then effects (tier -1), then a sim-LOD signal. No `AThermal_getThermalHeadroom` / iOS `thermalState` (needs a native plugin). |
| F-4 | Power profiles | Done | Performance / Balanced / Saver (fps cap + DRS target); auto from the sysfs battery status. |
| F-5 | GPU-timestamp DRS | Done | Blueprint formula (EWMA + k*sigma, sqrt mapping, clamp, hysteresis 0.03, max step 0.1). Uses the viewport's measured GPU/CPU render time when available, else frame delta. FSR1 upscale on Forward+. |
| F-6 | Per-pass resolution | Not feasible | Godot does not expose per-pass render targets to GDScript. |
| F-7 | Native-res UI | Done (engine) | Godot's `scaling_3d_scale` already leaves 2D/UI at native resolution; the addon relies on that. |
| F-8 | Budgeted residency | Not built | Would need texture streaming hooks that Godot 4.7 does not expose. |
| F-9 | Virtual texturing fallback | Not feasible | Renderer-level. |
| F-10 | Memoryless attachments | Not feasible | RHI-level (Metal/Vulkan memory flags). |
| F-11 | Zero-alloc frame CI gate | Not feasible | Needs an allocator hook in the engine. |
| F-12 | Script heap budgets | Not feasible | Luau/Wasm VM caps; no such VM in Godot. |
| F-13 | Meshlet continuous LOD | Not feasible | Needs mesh shaders / a renderer change. |
| F-14 | Universal textures | Done (engine) | Godot's importer already does ETC2/ASTC/BC; nothing added. |
| F-15 | Bandwidth-first G-buffer | Not feasible | Renderer-level. |
| F-16 | Impostors / HLOD | Not built | Possible in an addon later; out of scope. |
| F-17 | Precision tiers (fp16) | Not feasible | Shader-compiler-level. |
| F-18 | Shadow scheduler | Not feasible | Godot owns cascade scheduling (only atlas sizes are set per tier). |
| F-19 | Generator plugin interface | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-20 | Provenance manifest | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-21 | Post-gen cook chain | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-22 | Material inference | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-23 | Text-to-behavior | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-24 | ECS scene query console | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-25 | Embedding search | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-26 | Semantic volumes | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-27 | Agent-safe editor API | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-28 | One-click LOD/cluster build | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-29 | Texture budget optimizer | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-30 | Shader variant pruner | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-31 | Perf regression bot | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-32 | Attribute-driven replication | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-33 | Dual-model netcode | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-34 | Transport abstraction | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-35 | Interest management | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-36 | Lag compensation | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-37 | Network conditioner + desync forensics | Partial | Only the per-tick checksum + first-divergent-tick report in ChomuReplay; no network conditioner. |
| F-38 | Multiplayer play mode | Not built | Out of scope. |
| F-39 | Volumetric froxel fog | Done (engine) | Godot has volumetric fog; DeviceTier only turns it on/off per tier. |
| F-40 | Shadow streaming / VSM | Not feasible | Renderer-level. |
| F-41 | Light-as-gameplay | Partial | CPU `ChomuLightProbe` (light falloff, cone, occlusion ray) instead of a GPU luminance readback. |
| F-42 | Flicker circuits | Done | Light flicker + procedural buzz share one seed (`atmosphere/flicker_circuit.gd`). |
| F-43 | Fear exposure | Done | Asymmetric eye adaptation + `hold_darkness()` curve on CameraAttributesPractical. |
| F-44 | Tension director | Done | Proximity, LOS, darkness, damage, time since scare; hysteretic Build-up/Peak/Relax. |
| F-45 | Procedural audio graph | Not built | Only the flicker buzz generator; no tension-driven audio graph. |
| F-46 | Stress post-FX | Done | Vignette, chromatic aberration, grain, desaturation, FOV breathing, photosensitivity-safe mode. |
| F-47 | Diegetic physics scares | Not built | The director's `scare_window_opened` signal is the hook; the demo uses it to stutter lights. |
| F-48 | Biometric hooks | Not built | Out of scope. |
| F-49 | HFSM + utility + BT hybrid | Done | `ai/hfsm.gd` + `ai/behavior_tree.gd` (utility selector). Behaviour data is code, not hot-reloadable files. |
| F-50 | GOAP planner | Done | A* over a Dictionary world state (not a bitset), time-sliced `step(budget)`. |
| F-51 | ECS-native AI | Not feasible | Godot is node-based; there is no ECS to batch over. |
| F-52 | Perception | Partial | Sight cone + LOS + light check, hearing by distance with a ray-occlusion penalty, memory decay. Hearing does not propagate over the navmesh. |
| F-53 | AI decision timeline | Partial | HFSM keeps the last 64 leaf paths; no scrubbable UI. |
| F-54 | Active ragdolls | Partial | PhysicalBoneSimulator3D + PD velocity steering toward a pose; not Jolt joint motors (not exposed). |
| F-55 | Cloth/hair tiers | Not built | Out of scope. |
| F-56 | Stress destruction | Not built | Out of scope. |
| F-57 | Wind and buoyancy | Partial | CPU wind field (noise gusts) + sum-of-sines water with probe buoyancy; not a 64^3 GPU field or FFT ocean. |
| F-58 | Thin-client deploy | Not feasible | Engine/tooling-level. |
| F-59 | Host asset streaming | Not feasible | Engine VFS-level. |
| F-60 | Incremental native builds | Not feasible | Build-system item, not an addon. |
| F-61 | Two-tier plugin isolation (Wasm) | Not feasible | Wasm in-process sandboxing and child-process natives need engine support. |
| F-62 | Capability manifest | Not feasible | Depends on F-61. |
| F-63 | Transactional edits | Not built | Godot's UndoRedo exists; no plugin-sandbox layer. |
| F-64 | Watchdogs | Not feasible | Depends on F-61. |
| F-65 | Diagnostics panel | Not built | Out of scope. |
| F-66 | ABI versioning | Not feasible | Native ABI item. |
| F-67 | Always-on Tracy | Not feasible | Needs a native profiler integration. |
| F-68 | Deterministic replay | Done | Input states + RNG seed per physics tick, checksum compare, save/load (`replay/replay.gd`). |
| F-69 | GPU crash breadcrumbs | Not feasible | RHI-level. |
| F-70 | Golden images per tier | Not built | Possible with screenshots + CI; not built here. |
| F-71 | World partition | Done | Grid cells, async ResourceLoader load/unload with hysteresis (`streaming/world_streamer.gd`). No per-cell LevelArena. |
| F-72 | Large worlds (double precision) | Not feasible | Needs a `precision=double` engine build. |
| F-73 | Terrain clipmaps + VT | Not built | Out of scope. |
| F-74 | GPU particles | Done (engine) | Godot GPUParticles3D; nothing added. |
| F-75 | Animation (motion matching, IK) | Not built | Out of scope. |
| F-76 | HDR output | Not feasible | Display-pipeline-level. |
| F-77 | Neural materials | Not feasible | Needs Slang autodiff / compute in the renderer. |
| F-78 | Live collaboration (CRDT) | Not feasible | Editor/networking-level. |
| F-79 | Remote ECS inspector | Not feasible | No ECS (Godot's remote scene tree covers part of this). |
| F-80 | Physics debugger | Not built | Out of scope. |
| F-81 | HTN planner | Not built | GOAP only. |
| F-82 | Bitmask delta replication | Not built | Netcode, out of scope. |

## License
MIT, see `LICENSE`.
