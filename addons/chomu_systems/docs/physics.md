# Physics helpers - F-54, F-57

## ChomuActiveRagdoll (Node)
Wraps a `PhysicalBoneSimulator3D`. `start()` snapshots the current pose (or follows `target_skeleton`, e.g. a hidden animated copy) and starts simulation. Each tick, PD-style velocity steering pulls every PhysicalBone3D toward its target transform (`strength` 0 = limp, 1 = stiff). `hit(pos, impulse, limp_seconds)` knocks the nearest bone and goes limp for a while, then recovers. `unpowered_bones` lets e.g. the hips fall freely. `pose_error()` measures the result. Godot exposes no per-joint motors on PhysicalBone3D, so this approximates Jolt motor constraints with velocity steering. `demo/ragdoll_builder.gd` builds a 7-bone test dummy.

## ChomuWind (Node)
CPU wind field: direction * strength + FastNoiseLite gusts + spatial turbulence. `sample(pos)` returns m/s. Pushes RigidBody3Ds in group `chomu_wind` with quadratic drag (`wind_area` meta), and sets global shader parameter `chomu_wind` (vec4) if your project declares it.

## ChomuWater (Node3D) + ChomuBuoyancy (child of a RigidBody3D)
`ChomuWater.height_at(x, z)` is a sum of directional sine waves using the deep-water speed formula, with an optional preview plane. `ChomuBuoyancy` probe points apply Archimedes force per probe (with a submerged fraction), plus linear and angular water drag so bodies settle.
