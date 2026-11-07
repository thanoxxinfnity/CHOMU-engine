# CHoMU Ultra v0.1 (graphics pack for the CHoMU Engine)

CHoMU Ultra is a graphics pack for the CHoMU Engine (4.7 core). It is built Android-first, aimed at
mid-range phones and PCs. You get one-click quality presets, a device-tier auto-pick, adaptive resolution,
production shaders (hero PBR, foliage, water, terrain, sky, post-process, lens flare, heat haze) and a demo scene.

> **Status: v0.1, visuals UNTESTED.** Everything parses and loads in a headless engine (see *Verification*).
> No GPU was available, so nobody has looked at the shaders on screen, compiled them for a GPU, or profiled them yet.
> Install the demo on a phone (vivo T5x 5G) and check it before you rely on any preset.

## Install
1. Copy `addons/chomu_ultra/` into your project.
2. Go to Project > Project Settings > Plugins and enable **CHoMU Ultra**. This adds the `ChomuUltraBoot` autoload.
3. Open a 3D scene, pick a preset next to the **Apply CHoMU Ultra** toolbar button, and click it.
   - The button writes the project settings: renderer, AA, 3D scale, shadows, GI and reflection quality. It backs up the old values first.
   - It also updates the open scene: WorldEnvironment (added if missing), sun cascades and biases, and the `ChomuPost` post layer. Ctrl+Z undoes this.
   - Project > Tools > *CHoMU Ultra: Restore previous settings* puts the project settings back.
   - If the renderer changes, reload the project.

## Runtime API
```gdscript
ChomuUltra.apply("Mobile Ultra")          # "Low" | "Medium" | "Mobile Ultra" | "PC Cinematic" | "Auto"
ChomuUltra.apply("Auto")                  # picks from GPU name / RAM / CPU cores / running renderer
ChomuUltra.apply("PC Cinematic", null, {"gi": "voxelgi", "upscaler": "fsr2", "tonemapper": "AgX", "post": true})
var info := ChomuUltra.detect()           # {tier, preset, reason, gpu, ram_gb, renderer, ...}
ChomuUltra.enable_adaptive(60)            # lowers 3D scale, then the preset, if fps stays under target
```
`apply()` returns a report listing what it applied and what it skipped, with the reason for each skip.
On start (and on every scene change), the boot autoload applies `chomu_ultra/runtime_preset` (default `Auto`).
On phones it also turns on the adaptive governor (`chomu_ultra/adaptive_resolution`, `chomu_ultra/target_fps`).

## Presets
| Preset | Renderer | What it turns on |
|---|---|---|
| Low | Mobile | 75% res, FXAA, 1K hard shadows, light fog, no glow or post. Demo foliage at 40% |
| Medium | Mobile | 85% res + sharpen, 2x MSAA, 2K soft 2-split shadows, ACES, glow, height fog, grade + vignette |
| **Mobile Ultra** | Mobile | 90% res + CHoMU sharpen, 2x MSAA, 2K soft 4-split shadows, ACES (or AgX), punchy glow, aerial height fog, contrast/saturation, warm-teal LUT, vignette, light grain, 60 fps cap. SSAO-lite **only if running on Forward+** |
| PC Cinematic | Forward+ (phones fall back to Mobile) | SDFGI (or VoxelGI), SSIL, SSR, ultra SSAO, volumetric fog, TAA native (or FSR 2 at 77%), 8K PCSS shadows, AgX, full post + chromatic aberration + lens flare |

Engine limits these presets are honest about (from the 4.7 engine source):
- **FSR 1 and FSR 2 only work on Forward+.** `renderer_viewport.cpp` rejects them on Mobile and Compatibility.
  So the Mobile presets use bilinear scaling plus the pack's own sharpen pass. If you want real FSR 1 on phones, that needs an engine patch to the CHoMU fork.
- **The Mobile renderer has no SSAO, SSIL, SSR, SDFGI or volumetric fog.** Those keys are forced off there, not faked.
  Use baked AO (ORM textures), reflection probes and the shaders' AO and wetness instead.
- **The engine has no screen-space contact shadows.** PC Cinematic gets close with PCSS (`light_angular_distance`), tight biases, blended cascades and SSAO/SSIL.

## Shaders (`addons/chomu_ultra/shaders/`)
| File | What it is |
|---|---|
| `hero_pbr.gdshader` | Albedo + ORM + normal + distance-faded detail normal, wetness (porosity darkening, gloss, world-space puddles), emission, rim |
| `foliage.gdshader` | Alpha-scissor double-sided cards, world-noise gusts + flutter (root-weighted), BACKLIGHT subsurface, up-bent normals, MultiMesh-safe |
| `water.gdshader` | 2-wave vertex swell, 2 scrolling normal maps, Beer-Lambert depth colour, refraction with leak rejection, shore + crest foam, fresnel |
| `terrain_triplanar.gdshader` | Grass / triplanar rock / sand by slope + height + macro noise, whiteout normal blending (no tangents), wet shoreline band, optional heightmap displacement |
| `sky_atmosphere.gdshader` | Analytic zenith/horizon gradient, Mie sun glow, sun disk, sunset tint, planar clouds. No `TIME`, so phones don't re-render radiance every frame |
| `post_grade.gdshader` | Full-screen canvas pass: 16³ LUT strip, exposure/WB, lift-gamma-gain, contrast, saturation, sharpen, vignette, grain, chromatic aberration |
| `lens_flare.gdshader` + `post/lens_flare.gd` | Procedural additive flare that follows the sun (no occlusion test) |
| `heat_haze.gdshader` | Billboard screen-texture distortion (fire, exhausts) |

The post-process is a full-screen `ColorRect` on CanvasLayer 100, not a `CompositorEffect`, so it runs on all
three renderers. It grades after tonemapping. Put your HUD on a CanvasLayer above 100.

LUTs: `luts/neutral.png` and `luts/chomu_warm_teal.png`, both 256x16 strips with blue picking the slice.
You can make your own: grade `neutral.png` in any photo editor and keep the size.

## Demo (`demo/demo.tscn`, the project's main scene)
The demo has terrain (150 m, baked mesh) with a lake, water, 3000 grass clumps and 400 reeds (wind),
a wet stone plaza with puddles, a gold orb and ring (metal PBR), a crate (detail normals), an ember with heat haze
and a light, a reflection probe, the atmospheric sky, fog and post FX.
On screen there are preset buttons, Post FX and Rain toggles, and an fps / renderer / tier readout.
You can drag to orbit and pinch to zoom.
Noise textures are generated at load time (`NoiseTexture2D`). For a shipping game, bake them to PNG.
`tools/build_demo.gd` rebuilds the scene and `tools/gen_assets.gd` regenerates the LUTs and grass texture.

## Verification (what was actually checked)
Everything was run headless with the 4.7.2 engine binary (`tools/verify.gd`, output in `tools/verify_output.txt`):
- 12/12 GDScript files compile: 0 parse errors.
- 8/8 `.gdshader` files pass the engine's shader-language front end (the headless dummy renderer parses shaders and reports
  errors such as unknown identifiers or hints). This is **not** GPU compilation (SPIR-V / GLSL ES).
- Every Environment, DirectionalLight3D and Viewport property and every project-setting key the presets use exists in 4.7.2.
- The device-tier heuristic gave the expected result for 10 sample GPU/RAM combinations.
- `demo.tscn` loads, instantiates and runs frames. `ChomuUltra.apply()` succeeded for all 4 presets, Auto, and PC Cinematic with options.
  The post layer, governor and 3000-instance grass were all built.
- Headless editor: the plugin loads, the toolbar button and picker appear, and Apply works on the open demo scene
  (environment updated, undo works, settings restore works). Expected editor-only warnings appear when PC Cinematic
  values are written while the editor runs on the Mobile renderer.

**Not checked: anything visual or about performance.** That includes how shaders compile on Adreno or Mali drivers,
how the water depth looks on the Mobile renderer, foliage alpha, colours, fps and heat.

## Phone test checklist (vivo T5x 5G)
1. Export the demo to Android (Mobile renderer, ETC2/ASTC on) and check the tier readout: GPU name, RAM and picked preset.
2. Try each preset button and note the fps (the readout shows it) and whether the phone gets warm after 5 minutes.
3. Look for solid flat-colour "error" materials (a shader failed to compile on the GPU), water edges, grass shimmer, sky banding, and how the LUT looks.
4. Send the GPU name and fps per preset so the tier table in `device_tier.gd` can be tuned.

A note on BGMI: it ships with years of hand-made art, baked lighting and per-device tuning.
This pack gives you the rendering side. How close a game gets depends mostly on its textures, models and lighting bakes.

## What's missing in v0.1
- No on-device testing, screenshots or profiling yet.
- FSR 1 on the Mobile renderer needs a CHoMU engine patch.
- No CompositorEffect / compute-shader post (to keep all renderers working); no TAA-like AA on Mobile.
- The lens flare has no occlusion test. Clouds are static unless you script `cloud_offset`.
- No baked VoxelGI or lightmaps in the demo (PC Cinematic uses SDFGI). There are no real PBR texture sets: the demo uses noise.
- The device-tier GPU table is a heuristic and isn't tuned on real devices.
