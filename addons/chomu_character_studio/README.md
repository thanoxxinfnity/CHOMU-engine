# CHoMU Character Studio (v0.14, starter studio)

A **Character Studio** tab for CHoMU Engine / Godot 4.7. It sits next to 2D, 3D, Script and
Asset Store and puts the everyday character jobs in one place, using the engine's own
nodes (Skeleton3D, BoneMap, TwoBoneIK3D, LookAtModifier3D, SpringBoneSimulator3D, SoftBody3D,
AnimationTree, CSG, ArrayMesh, xatlas).

> **Please read first:** this is a **starter studio, not Blender**. It covers the common steps
> (rig, IK, retarget, simple edits, sculpt touch-ups, weights, shape keys, quick UVs, presets),
> so you can stay inside the engine for small jobs. For heavy modelling, retopology, high-res
> sculpting, UV seam work or detailed animation, keep using Blender (or similar) and import the result.

## Install

1. Copy `addons/chomu_character_studio/` into your project's `addons/` folder.
2. Go to Project > Project Settings > Plugins and enable **CHoMU Character Studio**.
3. Click the **Character Studio** tab at the top of the editor.

The optional `addons/cyclops_level_builder/` folder (Cyclops Level Builder by Mark McKay, MIT)
is a separate plugin. It is not turned on by default; enable it in Plugins if you want its
block-out tools.

## Layout

- **Left bar:** the modes (Rig, Animate, Pose, Cloth, Hair, Material, Model, Edit Mesh, Sculpt, Weights, Shape Keys, UV, Modifiers).
- **Centre:** the studio's own 3D view of the open scene (orbit with MMB or RMB, pan with Shift+MMB, zoom with the wheel, `.` to frame).
- **Right:** the tools for the current mode.
- **Header:** the current target. *Use selection* picks whatever is selected in the Scene dock.

Scene changes (new nodes, materials, applied meshes) go through the editor's undo (Ctrl+Z).
Mesh, sculpt and weight sessions also keep their own undo list inside the studio.

## What each mode does

| Mode | What you get | Engine feature used |
|---|---|---|
| Rig | Import a model into the scene; auto **humanoid BoneMap** (Unreal/Quaternius, Mixamo, VRM and Rigify-style names); write it into the model's import settings and reimport so the engine renames bones and fixes rests; rename scene bones to humanoid names; **one-click IK** for both arms and legs (target and pole markers) plus head **look-at** | BoneMap, SkeletonProfileHumanoid, import retarget, TwoBoneIK3D, LookAtModifier3D |
| Animate | Open the character's AnimationPlayer; **AnimationTree starter** (BlendSpace1D idle 0 / walk 0.5 / run 1); **retarget a whole library** from another file onto the character (bones matched through the humanoid map, rotations corrected for the rest pose); preview any clip with a time slider | AnimationPlayer, AnimationTree, AnimationLibrary |
| Pose | Bone tree plus click-to-pick joints in the view; rotation sliders; R to rotate in the view (X/Y/Z to lock an axis); **key the selected bone or every posed bone** into a clip at any time (the record-pose helper) | Skeleton3D, Animation rotation/position tracks |
| Cloth | Turn the selected cape or skirt into **SoftBody3D**; the top band of vertices is pinned to the nearest chest bone through a BoneAttachment3D; presets **Silk / Cotton / Leather**; *Add demo cape* | SoftBody3D, BoneAttachment3D |
| Hair | Finds hair/tail bone chains and adds a **SpringBoneSimulator3D** with presets (Soft, Stiff, Long flowing, Tail: stiffness, gravity, drag) and **collision capsules** (head, neck, chest, upper arms); can create a ponytail or tail bone chain | SpringBoneSimulator3D, SpringBoneCollisionCapsule3D |
| Material | Presets that keep the model's textures: **Skin** (subsurface + backlight), **Hair** (anisotropic, alpha scissor), Cloth, Leather, Metal, Eyes, **Anime toon** (cel bands + rim) and toon + **outline** | StandardMaterial3D, a toon shader, an inverted-hull outline shader |
| Model | CSG block-out (box, sphere, cylinder, cone, torus) with Union / Subtract / Intersect; **bake to mesh** and go to Edit Mode; editable mesh primitives | CSGCombiner3D, CSGShape3D.bake_static_mesh |
| Edit Mesh | Vertex / edge / face select (click, Shift-click, box drag, all, invert, linked, grow, X-ray); G/R/S move, rotate and scale with axis lock, plus exact number fields; **extrude** (face region or edges), **inset**, **subdivide**, **delete**, **merge** (at centre, by distance), make face, flip normals, tris to quads, smooth/flat | ArrayMesh, SurfaceTool (tangents) |
| Sculpt | **Draw, Smooth, Inflate, Grab** brushes with radius, strength, X symmetry and Ctrl to invert; can sculpt a shape key | ArrayMesh |
| Weights | Bone list with filter; **Add / Subtract / Smooth** weight brushes with a heat-map view; **auto weights** (nearest-bone envelope) that also create the Skin | Skin, ARRAY_BONES / ARRAY_WEIGHTS |
| Shape Keys | List, rename, preview sliders, new key (then sculpt it), key from the current mix; written to the mesh as **blend shapes** on Apply | ArrayMesh blend shapes |
| UV | **One-click unwrap** into UV1, or **UV2 for lightmaps** on the scene mesh; UV layout preview | ArrayMesh.lightmap_unwrap (xatlas) |
| Modifiers | Live **Mirror**, **Array** and **Subdivision** (Catmull-Clark, 0 to 3 levels) stack; reorder, toggle, bake, or apply with the mesh | the studio's own mesh code |

**Apply to scene** writes the edited mesh back to the MeshInstance3D. It keeps UVs, tangents,
skin weights, blend shapes and materials, and creates a Skin if you painted weights on an unskinned mesh.

## Honest limits

- It is **GDScript**. Edit, sculpt and weight tools are fine on game meshes up to roughly 10k to 20k faces.
  A sculpt dab on the 12.5k-face demo body takes about 0.1 s. There is no multires, no dyntopo and no
  remesh; the brushes move the vertices you already have.
- Loading a mesh **welds vertices by position**, so UV and hard-edge seams become smooth shading
  (UVs are kept per corner). A mesh with split normals looks smoother after Apply.
- Edit and Sculpt show the mesh in its **bind pose** on its node transform, not the animated pose.
- No knife, loop cut, bevel, bridge or dissolve yet. Inset works face by face, not on a whole region.
- Retargeting a library assumes **similar rest poses**. For very different rigs, use the engine's
  import retarget (the Rig mode button) on both files, then retarget.
- Auto weights are a simple envelope (nearest bones). Expect to touch up shoulders and hips with the brush.
- The Mirror modifier does not swap left and right bone weights.
- Bones added with *Create chain* on an **imported** skeleton only save if the scene is made local
  (or if you add them in your own DCC file).
- **Compatibility renderer:** subsurface scattering and anisotropy are Forward+ / Mobile features.
  Under Compatibility they fall back to plain PBR (the studio tells you when that happens).
- SoftBody3D cloth only collides with physics bodies. Add collision shapes to the body for cape-versus-legs contact.

## Testing (what was run)

- `godot --headless -e --path <demo> -- --chomu-studio-selftest`: opens the demo, goes through
  all 13 modes and runs every tool through the real editor undo system. 34 checks: IK, look-at,
  import retarget, a 43-clip library retarget, AnimationTree, pose keys, cloth and presets, spring
  bones, CSG and bake, materials, every edit op, sculpt brushes, shape keys to blend shapes, auto
  weights and brush, xatlas UV1/UV2, the modifier stack, and editor undo.
- `godot -e --rendering-driver opengl3 -- --chomu-studio-shots=<dir>`: screenshots of the tab with the demo character (Compatibility renderer).
- Result on Godot 4.7.2 (Linux arm64): 34/34 checks passed, 0 script errors.

## Credits and license

- CHoMU Character Studio: MIT License (below). Built for CHoMU Engine, a Godot 4.7 fork (Godot is MIT, © Godot Engine contributors).
- Demo character and animations (demo project only, not part of the add-on): Quaternius *Universal Base Characters* and *Universal Animation Library*, CC0.
- Optional vendored add-on: Cyclops Level Builder v1.5.2 (official "for Godot 4.7" release) © 2023 Mark McKay, MIT. Its own LICENSE.md is in its folder. Tested: it loads with no script errors next to the studio in Godot 4.7.2 when enabled through Plugins, which registers its `CyclopsAutoload`.

```
MIT License

Copyright (c) 2026 CHoMU Engine (Tejas Singh)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
