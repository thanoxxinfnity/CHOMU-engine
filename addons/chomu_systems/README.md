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
`tests/self_test.tscn` has 853 checks across all systems and exits with code 0 when all pass:
`godot --headless --path <project> res://addons/chomu_systems/tests/self_test.tscn`

## Blueprint coverage (honest)
The GPU and engine-core items (bindless RHI, meshlets, virtual texturing, Wasm plugin isolation, CRDT collaboration, double-precision worlds, Tracy, HDR output) are **not feasible in a GDScript addon**. They need changes inside the engine or renderer. "Done (engine)" means Godot already provides the feature and the addon only switches it per tier. "Not built" means it could be done but is outside this addon's scope.

Summary: Done: 22, Done (engine): 4, Not built: 14, Not feasible: 25, Partial: 17.

| ID | Feature | Status | Notes |
|---|---|---|---|
| F-1 | Capability probe + tier classifier | Done | ~2 s time-sliced CPU+frame-time benchmark, cores/RAM, small substring device DB, cached per device key (`core/device_tier.gd`). |
| F-2 | Fallback graph | Done | Implemented a recursive fallback graph for feature resolution based on hardware capabilities with cycle detection and explanation support. (`core/fallback_graph.gd`, 23 headless checks in `tests/items/test_f_02.gd`; written by nemotron-3-ultra-550b-a55b, reviewed by gemma-4-31b-it.) |
| F-3 | Thermal governor | Partial | Thermal PID controller with anti-windup and hysteresis implemented; platform thermal APIs (AThermal/thermalState) not yet integrated. (`core/thermal_pid.gd`, 8 headless checks in `tests/items/test_f_03.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-4 | Power profiles | Done | Performance / Balanced / Saver (fps cap + DRS target); auto from the sysfs battery status. |
| F-5 | GPU-timestamp DRS | Done | Blueprint formula (EWMA + k*sigma, sqrt mapping, clamp, hysteresis 0.03, max step 0.1). Uses the viewport's measured GPU/CPU render time when available, else frame delta. FSR1 upscale on Forward+. |
| F-6 | Per-pass resolution | Not feasible | Godot does not expose per-pass render targets to GDScript. |
| F-7 | Native-res UI | Done (engine) | Godot's `scaling_3d_scale` already leaves 2D/UI at native resolution; the addon relies on that. |
| F-8 | Budgeted residency | Partial | Budgeted residency planner implemented; plans mip levels but cannot stream due to Godot 4.7 limitations. (`core/residency_budget.gd`, 5 headless checks in `tests/items/test_f_08.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-9 | Virtual texturing fallback | Not feasible | Renderer-level. |
| F-10 | Memoryless attachments | Not feasible | RHI-level (Metal/Vulkan memory flags). |
| F-11 | Zero-alloc frame CI gate | Not feasible | Needs an allocator hook in the engine. |
| F-12 | Script heap budgets | Not feasible | Luau/Wasm VM caps; no such VM in Godot. |
| F-13 | Meshlet continuous LOD | Not feasible | Needs mesh shaders / a renderer change. |
| F-14 | Universal textures | Done (engine) | Godot's importer already does ETC2/ASTC/BC; nothing added. |
| F-15 | Bandwidth-first G-buffer | Not feasible | Renderer-level. |
| F-16 | Impostors / HLOD | Partial | Implements HLOD proxy merging and billboard switching with hysteresis; octahedral baking is omitted as per scope constraints. (`rendering/hlod.gd`, 9 headless checks in `tests/items/test_f_16.gd`; written by nemotron-3-ultra-550b-a55b, reviewed by gemma-4-31b-it.) |
| F-17 | Precision tiers (fp16) | Not feasible | Shader-compiler-level. |
| F-18 | Shadow scheduler | Not feasible | Godot owns cascade scheduling (only atlas sizes are set per tier). |
| F-19 | Generator plugin interface | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-20 | Provenance manifest | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-21 | Post-gen cook chain | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-22 | Material inference | Done | F-22 Material inference implemented and verified: height, normal, roughness inference plus StandardMaterial3D generation all pass headless tests. (`tools/material_infer.gd`, 18 headless checks in `tests/items/test_f_22.gd`; written by nemotron-3-ultra-550b-a55b, reviewed by nemotron-3.5-super-vl-120b-a12b.) |
| F-23 | Text-to-behavior | Done | Text-to-behavior schema validates and builds behavior trees from JSON with registered actions/conditions; all required tests pass. (`ai/behavior_schema.gd`, 7 headless checks in `tests/items/test_f_23.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-24 | ECS scene query console | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-25 | Embedding search | Partial | Working embedding search with trigram hashing and graph-based ANN, but HNSW implementation incomplete (missing neighbor pruning and proper EF-bounded search). (`tools/embedding_search.gd`, 13 headless checks in `tests/items/test_f_25.gd`; written by laguna-xs-2.1, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-26 | Semantic volumes | Partial | Implements semantic volume tagging and occlusion-based auto-tagging for cover and hiding spots using candidate points. (`ai/semantic_volumes.gd`, 11 headless checks in `tests/items/test_f_26.gd`; written by nemotron-3-ultra-550b-a55b, reviewed by gemma-4-31b-it.) |
| F-27 | Agent-safe editor API | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-28 | One-click LOD/cluster build | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-29 | Texture budget optimizer | Partial | Implements SSIM-based texture budget optimization with degrade levels; ASTC block size selection not possible in GDScript so scope is Partial by design. (`tools/texture_budget.gd`, 7 headless checks in `tests/items/test_f_29.gd`; written by laguna-xs-2.1, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-30 | Shader variant pruner | Partial | Traces used materials and shader parameter signatures during playtests, saves/loads/merges JSON traces, and reports unused material paths for manual export exclusion. (`tools/variant_tracer.gd`, 4 headless checks in `tests/items/test_f_30.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-31 | Perf regression bot | Partial | Implements a performance regression bot with fly-through sampling, baseline comparison, and markdown report generation. (`tools/perf_regression.gd`, 28 headless checks in `tests/items/test_f_31.gd`; written by nemotron-3-ultra-550b-a55b, reviewed by gemma-4-31b-it.) |
| F-32 | Attribute-driven replication | Done | Implements attribute-driven replication with priority, quantization, and hermite interpolation; all tests pass. (`net/replication_schema.gd`, 11 headless checks in `tests/items/test_f_32.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-33 | Dual-model netcode | Not built | Workflow/AI-tooling/netcode item, outside this addon's scope. |
| F-34 | Transport abstraction | Done | Implemented a transport abstraction layer with a functional loopback pair for in-process network testing. (`net/transport.gd`, 15 headless checks in `tests/items/test_f_34.gd`; written by nemotron-3-ultra-550b-a55b, reviewed by gemma-4-31b-it.) |
| F-35 | Interest management | Done | F-35 interest management fully implemented with spatial hash grid, correct enter/leave events, and efficient cell scanning verified by tests. (`net/interest_grid.gd`, 6 headless checks in `tests/items/test_f_35.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-36 | Lag compensation | Done | Implements a ring-buffer based lag compensation system with sphere-based raycasting and linear interpolation for missing ticks. (`net/lag_compensation.gd`, 33 headless checks in `tests/items/test_f_36.gd`; written by nemotron-3-ultra-550b-a55b, reviewed by gemma-4-31b-it.) |
| F-37 | Network conditioner + desync forensics | Done | F-37 network conditioner with deterministic latency/jitter/loss/duplication and recursive state diff/dump fully implemented and tested. (`net/net_conditioner.gd`, 10 headless checks in `tests/items/test_f_37.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-38 | Multiplayer play mode | Not built | Out of scope. |
| F-39 | Volumetric froxel fog | Done (engine) | Godot has volumetric fog; DeviceTier only turns it on/off per tier. |
| F-40 | Shadow streaming / VSM | Not feasible | Renderer-level. |
| F-41 | Light-as-gameplay | Partial | Implements round-robin light sampling at bone/marker points with CPU-based luminance estimation, simulating async GPU readback lag; exposure and visibility functions work as specified. (`ai/light_exposure.gd`, 5 headless checks in `tests/items/test_f_41.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-42 | Flicker circuits | Done | Light flicker + procedural buzz share one seed (`atmosphere/flicker_circuit.gd`). |
| F-43 | Fear exposure | Done | Asymmetric eye adaptation + `hold_darkness()` curve on CameraAttributesPractical. |
| F-44 | Tension director | Done | Proximity, LOS, darkness, damage, time since scare; hysteretic Build-up/Peak/Relax. |
| F-45 | Procedural audio graph | Done | Procedural audio graph with heartbeat, granular, and filter sweep nodes driven by tension; offline rendering and real-time playback supported. (`atmosphere/proc_audio.gd`, 4 headless checks in `tests/items/test_f_45.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-46 | Stress post-FX | Done | Vignette, chromatic aberration, grain, desaturation, FOV breathing, photosensitivity-safe mode. |
| F-47 | Diegetic physics scares | Not built | The director's `scare_window_opened` signal is the hook; the demo uses it to stutter lights. |
| F-48 | Biometric hooks | Done | F-48 Biometric hooks implemented with opt-in local-only providers, EMA smoothing, arousal calculation, and consent revocation; all tests pass. (`atmosphere/biometric_hooks.gd`, 7 headless checks in `tests/items/test_f_48.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-49 | HFSM + utility + BT hybrid | Done | `ai/hfsm.gd` + `ai/behavior_tree.gd` (utility selector). Behaviour data is code, not hot-reloadable files. |
| F-50 | GOAP planner | Done | A* over a Dictionary world state (not a bitset), time-sliced `step(budget)`. |
| F-51 | ECS-native AI | Not feasible | Godot is node-based; there is no ECS to batch over. |
| F-52 | Perception | Partial | Sight cone + LOS + light check, hearing by distance with a ray-occlusion penalty, memory decay. Hearing does not propagate over the navmesh. |
| F-53 | AI decision timeline | Done | F-53 AI decision timeline fully implemented with per-agent ring buffer, scrubbable replay, HFSM integration, JSON serialization, and UI scrubber; all tests pass. (`ai/decision_timeline.gd`, 7 headless checks in `tests/items/test_f_53.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-54 | Active ragdolls | Partial | PhysicalBoneSimulator3D + PD velocity steering toward a pose; not Jolt joint motors (not exposed). |
| F-55 | Cloth/hair tiers | Partial | F-55 ChomuBoneChain implements T0 verlet spring bone chain with distance constraints and sphere colliders; T2+ soft body/GPU hair is out of scope, hence Partial. (`physics/bone_chain.gd`, 8 headless checks in `tests/items/test_f_55.gd`; written by nemotron-3-ultra-550b-a55b, reviewed by nemotron-3.5-super-vl-120b-a12b.) |
| F-56 | Stress destruction | Partial | Implements local bond graph stress destruction and propagation; networked chunks not implemented. (`physics/bond_graph.gd`, 21 headless checks in `tests/items/test_f_56.gd`; written by nemotron-3-ultra-550b-a55b, reviewed by gemma-4-31b-it.) |
| F-57 | Wind and buoyancy | Partial | Implements CPU 3D wind grid with time-sliced updates, trilinear sampling, decaying impulses, and Gerstner wave displacement/height; lacks 64^3 GPU wind field and FFT ocean simulation. (`physics/wind_grid.gd`, 7 headless checks in `tests/items/test_f_57.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-58 | Thin-client deploy | Not feasible | Engine/tooling-level. |
| F-59 | Host asset streaming | Not feasible | Engine VFS-level. |
| F-60 | Incremental native builds | Not feasible | Build-system item, not an addon. |
| F-61 | Two-tier plugin isolation (Wasm) | Not feasible | Wasm in-process sandboxing and child-process natives need engine support. |
| F-62 | Capability manifest | Not feasible | Depends on F-61. |
| F-63 | Transactional edits | Not built | Godot's UndoRedo exists; no plugin-sandbox layer. |
| F-64 | Watchdogs | Not feasible | Depends on F-61. |
| F-65 | Diagnostics panel | Partial | Implements per-plugin diagnostics with CPU timing, restarts, error traps, and a UI panel; memory is global due to GDScript limitations. (`debug/diagnostics.gd`, 7 headless checks in `tests/items/test_f_65.gd`; written by gemma-4-31b-it, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-66 | ABI versioning | Not feasible | Native ABI item. |
| F-67 | Always-on Tracy | Not feasible | Needs a native profiler integration. |
| F-68 | Deterministic replay | Done | Input states + RNG seed per physics tick, checksum compare, save/load (`replay/replay.gd`). |
| F-69 | GPU crash breadcrumbs | Not feasible | RHI-level. |
| F-70 | Golden images per tier | Partial | Implements golden image comparison with luminance-only FLIP approximation; capture untested in headless. (`debug/golden_image.gd`, 11 headless checks in `tests/items/test_f_70.gd`; written by laguna-xs-2.1, reviewed by nemotron-3-ultra-550b-a55b.) |
| F-71 | World partition | Done | Grid cells, async ResourceLoader load/unload with hysteresis (`streaming/world_streamer.gd`). No per-cell LevelArena. |
| F-72 | Large worlds (double precision) | Not feasible | Needs a `precision=double` engine build. |
| F-73 | Terrain clipmaps + VT | Not built | Out of scope. |
| F-74 | GPU particles | Done (engine) | Godot GPUParticles3D; nothing added. |
| F-75 | Animation (motion matching, IK) | Partial | Motion matching search and analytic two-bone IK implemented; normalization, weighted queries, and transition bias work, but unreachable-target IK extension is incorrect. (`anim/motion_matching.gd`, 16 headless checks in `tests/items/test_f_75.gd`; written by nemotron-3-ultra-550b-a55b, reviewed by nemotron-3.5-super-vl-120b-a12b.) |
| F-76 | HDR output | Not feasible | Display-pipeline-level. |
| F-77 | Neural materials | Not feasible | Needs Slang autodiff / compute in the renderer. |
| F-78 | Live collaboration (CRDT) | Not feasible | Editor/networking-level. |
| F-79 | Remote ECS inspector | Not feasible | No ECS (Godot's remote scene tree covers part of this). |
| F-80 | Physics debugger | Not built | Out of scope. |
| F-81 | HTN planner | Not built | GOAP only. |
| F-82 | Bitmask delta replication | Not built | Netcode, out of scope. |

<!-- SWARM-SHEET -->
## Extra systems from the full feature sheet (CHoMU Swarm)

Built by free models, each one headless-tested and reviewed before merge. Each row is one sheet work unit (subsystem x 'Core implementation'), verified on headless Linux only.

| Unit | Subsystem | File | Checks |
|---|---|---|---|
| S-06 | Utility AI Scoring Engine | `sheet/utility_ai_scoring_engine.gd` | 14 |
| S-07 | Boid Flocking & Steering Behavior | `sheet/boid_flocking_steering_behavior.gd` | 11 |
| S-09 | Memory & Suspicion State Tracker | `sheet/memory_suspicion_state_tracker.gd` | 8 |
| S-10 | Dynamic Patrol Route Generator | `sheet/dynamic_patrol_route_generator.gd` | 11 |
| S-11 | Squad Formation Manager | `sheet/squad_formation_manager.gd` | 28 |
| S-14 | Cover System for AI | `sheet/cover_system_for_ai.gd` | 5 |
| S-15 | Grid-based navmesh / pathfinding (ghost chase) | `sheet/grid_based_navmesh_pathfinding.gd` | 19 |
| S-17 | Sparse Set Data Structure | `sheet/sparse_set_data_structure.gd` | 27 |
| S-18 | Generational handles | `sheet/generational_handles.gd` | 17 |
| S-21 | Macro Recorder & Playback Utility | `sheet/macro_recorder_playback_utility.gd` | 5 |
| S-23 | Procedural Camera Shake | `sheet/procedural_camera_shake.gd` | 10 |
| S-29 | Vehicle Tire Friction & Slip Model | `sheet/vehicle_tire_friction_slip_model.gd` | 25 |
| S-32 | Audio Pitch & Volume Randomization | `sheet/audio_pitch_volume_randomization.gd` | 6 |
| S-36 | Game State Machine | `sheet/game_state_machine.gd` | 13 |
| S-38 | Component Schema Migration Versioning | `sheet/component_schema_migration_versioning.gd` | 7 |
| S-40 | Non-Volatile Local Storage Manager | `sheet/non_volatile_local_storage_manager.gd` | 11 |
| S-42 | Cross-Fade Transition Interpolation | `sheet/cross_fade_transition_interpolation.gd` | 8 |
| S-43 | Dependency Graph Resolver | `sheet/dependency_graph_resolver.gd` | 6 |
| S-46 | Performance Telemetry Logger | `sheet/performance_telemetry_logger.gd` | 8 |
| S-48 | Raycast Character Step-Up Calculator | `sheet/raycast_character_step_up_calculator.gd` | 6 |
| S-52 | Animation Masking | `sheet/animation_masking.gd` | 7 |
| S-54 | Anti-Cheat Validation Checks | `sheet/anti_cheat_validation_checks.gd` | 19 |
| S-55 | Asset Cooker & Dependency Tracker | `sheet/asset_cooker_dependency_tracker.gd` | 11 |
| S-56 | Asset Handle / UUID Resolver | `sheet/asset_handle_uuid_resolver.gd` | 12 |
| S-57 | Asset Metadata Validator | `sheet/asset_metadata_validator.gd` | 5 |
| S-61 | Audio profiling | `sheet/audio_profiling.gd` | 18 |
| S-64 | Bullet Penetration Depth Tracker | `sheet/bullet_penetration_depth_tracker.gd` | 22 |
| S-66 | Character Controller Slope Sliding | `sheet/character_controller_slope_sliding.gd` | 10 |
| S-73 | Coroutine State Serialization | `sheet/coroutine_state_serialization.gd` | 16 |
| S-77 | Custom Bézier Curve Editor Widget | `sheet/custom_b_zier_curve_editor_widget.gd` | 6 |
| S-78 | Debug Draw Gizmo Pipeline | `sheet/debug_draw_gizmo_pipeline.gd` | 17 |
| S-82 | Distance attenuation | `sheet/distance_attenuation.gd` | 15 |
| S-94 | Fluid / Particle Collision Dynamics | `sheet/fluid_particle_collision_dynamics.gd` | 10 |
| S-95 | Global Variable & Property Registry | `sheet/global_variable_property_registry.gd` | 11 |
| S-96 | Gradient Color Picker Tool | `sheet/gradient_color_picker_tool.gd` | 17 |
| S-107 | Material Property Block System | `sheet/material_property_block_system.gd` | 10 |
| S-108 | Multi-Select Transform Gizmo Handler | `sheet/multi_select_transform_gizmo_handler.gd` | 8 |
<!-- /SWARM-SHEET -->

## License
MIT, see `LICENSE`.
