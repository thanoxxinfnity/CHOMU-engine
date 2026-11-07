@tool
extends RefCounted
## CHoMU Ultra preset tables (data only). Same style as CHoMU Graphics (chomu_graphics.gd):
## one Dictionary per layer - project settings, viewport, RenderingServer quality, Environment, sun, post-process.
##
## Renderer notes (Godot 4.x):
##  - Forward+ : everything (SDFGI, VoxelGI, SSAO, SSIL, SSR, volumetric fog, TAA, FSR2).
##  - Mobile   : glow, tonemap, depth/height fog, MSAA, FXAA, soft shadows, reflection probes. Bilinear 3D scaling only
##               (Godot 4.7 renderer_viewport.cpp rejects FSR 1/2 outside Forward+), so presets add a sharpen pass.
##               NO SSAO / SSIL / SSR / SDFGI / volumetric fog -> those keys are switched off automatically.
##  - Compatibility : roughly like Mobile.

const ORDER: Array[String] = ["Low", "Medium", "Mobile Ultra", "PC Cinematic"]

const PRESET_SETTING := "chomu_ultra/preset"            # what the editor button applies (a name in ORDER)
const RUNTIME_PRESET := "chomu_ultra/runtime_preset"    # what the game applies at start ("Auto" = by device tier)
const APPLY_ON_START := "chomu_ultra/apply_on_start"
const ADAPTIVE := "chomu_ultra/adaptive_resolution"
const TARGET_FPS := "chomu_ultra/target_fps"
const TONEMAPPER := "chomu_ultra/tonemapper"            # "ACES" or "AgX"

static func info() -> Dictionary:
	return {
		"Low": {
			"tag": "Old / low-RAM phones", "renderer": "mobile",
			"desc": "Mobile renderer at 75% resolution, FXAA, 1K hard shadows, light fog, no glow, no post-process. 30-60 fps on low-end GPUs.",
			"colors": [Color("6b7280"), Color("374151")],
		},
		"Medium": {
			"tag": "Most mid-range phones", "renderer": "mobile",
			"desc": "Mobile renderer at 85% + sharpen, 2x MSAA, 2K soft shadows, glow, height fog, colour grade + vignette.",
			"colors": [Color("3ddc97"), Color("2bb3c0")],
		},
		"Mobile Ultra": {
			"tag": "Best look on mid/upper-mid phones", "renderer": "mobile",
			"desc": "Mobile renderer at 90% + CHoMU sharpen, 2x MSAA, 2K soft 4-split shadows, ACES/AgX, punchy glow, aerial height fog, LUT grade, sharpen, vignette, light grain. SSAO-lite only when running on Forward+.",
			"colors": [Color("ffb02e"), Color("ff7a1a")],
		},
		"PC Cinematic": {
			"tag": "PC / flagship, everything on", "renderer": "forward_plus",
			"desc": "Forward+: SDFGI (or VoxelGI), SSIL, SSR, ultra SSAO, volumetric fog, TAA at native res (or FSR 2), 8K PCSS shadows, AgX, full post-process + lens flare. Phones fall back to the Mobile renderer automatically.",
			"colors": [Color("4f9dff"), Color("2bb3c0")],
		},
	}

static func lower_of(preset: String) -> String:
	var i := ORDER.find(preset)
	return ORDER[max(i - 1, 0)] if i >= 0 else "Low"

# ------------------------------------------------------------------------------------------- project settings
## Written to project.godot by the editor button. Renderer changes need an editor/game restart.
static func project_settings_for(preset: String) -> Dictionary:
	var s := {
		"rendering/textures/vram_compression/import_etc2_astc": true,
		"rendering/anti_aliasing/quality/screen_space_aa": 0,
		"rendering/anti_aliasing/quality/use_debanding": false,
		"rendering/anti_aliasing/quality/use_taa": false,
		"rendering/anti_aliasing/quality/msaa_3d": 0,
		"rendering/scaling_3d/mode": 0,
		"rendering/scaling_3d/scale": 1.0,
		"rendering/scaling_3d/fsr_sharpness": 0.2,
	}
	match preset:
		"Low":
			s.merge({
				"rendering/renderer/rendering_method": "mobile",
				"rendering/renderer/rendering_method.mobile": "mobile",
				"rendering/anti_aliasing/quality/screen_space_aa": 1,
				"rendering/scaling_3d/mode": 0,
				"rendering/scaling_3d/scale": 0.75,
				"rendering/lights_and_shadows/directional_shadow/size": 1024,
				"rendering/lights_and_shadows/directional_shadow/size.mobile": 1024,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality": 0,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile": 0,
				"rendering/lights_and_shadows/directional_shadow/16_bits": true,
				"rendering/lights_and_shadows/positional_shadow/atlas_size": 1024,
				"rendering/lights_and_shadows/positional_shadow/atlas_size.mobile": 1024,
				"rendering/reflections/sky_reflections/ggx_samples.mobile": 16,
				"rendering/reflections/sky_reflections/texture_array_reflections.mobile": false,
				"rendering/reflections/reflection_atlas/reflection_size.mobile": 128,
				"rendering/textures/default_filters/anisotropic_filtering_level": 1,
				"rendering/mesh_lod/lod_change/threshold_pixels": 2.0,
			}, true)
		"Medium":
			s.merge({
				"rendering/renderer/rendering_method": "mobile",
				"rendering/renderer/rendering_method.mobile": "mobile",
				"rendering/anti_aliasing/quality/msaa_3d": 1,
				"rendering/scaling_3d/mode": 0,
				"rendering/scaling_3d/scale": 0.85,
				"rendering/lights_and_shadows/directional_shadow/size": 2048,
				"rendering/lights_and_shadows/directional_shadow/size.mobile": 2048,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality": 1,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile": 1,
				"rendering/lights_and_shadows/directional_shadow/16_bits": true,
				"rendering/lights_and_shadows/positional_shadow/atlas_size": 2048,
				"rendering/lights_and_shadows/positional_shadow/atlas_size.mobile": 2048,
				"rendering/reflections/sky_reflections/ggx_samples.mobile": 16,
				"rendering/reflections/reflection_atlas/reflection_size.mobile": 128,
				"rendering/textures/default_filters/anisotropic_filtering_level": 2,
				"rendering/mesh_lod/lod_change/threshold_pixels": 1.0,
			}, true)
		"Mobile Ultra":
			s.merge({
				"rendering/renderer/rendering_method": "mobile",
				"rendering/renderer/rendering_method.mobile": "mobile",
				"rendering/anti_aliasing/quality/msaa_3d": 1,  # 2x MSAA - cheap on tile-based phone GPUs
				"rendering/anti_aliasing/quality/use_debanding": true,
				"rendering/scaling_3d/mode": 0,                 # bilinear: FSR is Forward+-only in Godot 4.7
				"rendering/scaling_3d/scale": 0.9,
				"rendering/lights_and_shadows/directional_shadow/size": 2048,
				"rendering/lights_and_shadows/directional_shadow/size.mobile": 2048,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality": 2,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile": 2,
				"rendering/lights_and_shadows/directional_shadow/16_bits": true,
				"rendering/lights_and_shadows/positional_shadow/atlas_size": 2048,
				"rendering/lights_and_shadows/positional_shadow/atlas_size.mobile": 2048,
				"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality.mobile": 2,
				"rendering/environment/glow/upscale_mode.mobile": 0,
				"rendering/reflections/sky_reflections/ggx_samples.mobile": 16,
				"rendering/reflections/reflection_atlas/reflection_size.mobile": 256,
				"rendering/textures/default_filters/anisotropic_filtering_level": 3,
				"rendering/mesh_lod/lod_change/threshold_pixels": 1.0,
			}, true)
		"PC Cinematic":
			s.merge({
				"rendering/renderer/rendering_method": "forward_plus",
				"rendering/renderer/rendering_method.mobile": "mobile",
				"rendering/anti_aliasing/quality/use_taa": true,
				"rendering/anti_aliasing/quality/use_debanding": true,
				"rendering/anti_aliasing/screen_space_roughness_limiter/enabled": true,
				"rendering/lights_and_shadows/directional_shadow/size": 8192,
				"rendering/lights_and_shadows/directional_shadow/size.mobile": 2048,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality": 5,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile": 2,
				"rendering/lights_and_shadows/directional_shadow/16_bits": false,
				"rendering/lights_and_shadows/positional_shadow/atlas_size": 8192,
				"rendering/lights_and_shadows/positional_shadow/atlas_size.mobile": 2048,
				"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality": 5,
				"rendering/environment/ssao/quality": 4,
				"rendering/environment/ssao/half_size": false,
				"rendering/environment/ssil/quality": 3,
				"rendering/environment/ssil/half_size": false,
				"rendering/environment/screen_space_reflection/half_size": false,
				"rendering/environment/volumetric_fog/volume_size": 128,
				"rendering/environment/volumetric_fog/volume_depth": 128,
				"rendering/environment/volumetric_fog/use_filter": 1,
				"rendering/environment/glow/upscale_mode": 1,
				"rendering/global_illumination/gi/use_half_resolution": false,
				"rendering/global_illumination/sdfgi/probe_ray_count": 4,
				"rendering/global_illumination/sdfgi/frames_to_converge": 3,
				"rendering/global_illumination/voxel_gi/quality": 1,
				"rendering/reflections/sky_reflections/ggx_samples": 64,
				"rendering/reflections/reflection_atlas/reflection_size": 512,
				"rendering/reflections/specular_occlusion/enabled": true,
				"rendering/textures/default_filters/anisotropic_filtering_level": 4,
				"rendering/mesh_lod/lod_change/threshold_pixels": 0.5,
			}, true)
	return s

# ------------------------------------------------------------------------------------------- viewport (runtime)
static func viewport_for(preset: String, renderer: String) -> Dictionary:
	var v := {}
	match preset:
		"Low":
			v = {"msaa_3d": Viewport.MSAA_DISABLED, "screen_space_aa": Viewport.SCREEN_SPACE_AA_FXAA, "use_taa": false,
				"scaling_3d_mode": Viewport.SCALING_3D_MODE_FSR, "scaling_3d_scale": 0.75, "fsr_sharpness": 0.4,
				"use_debanding": false, "mesh_lod_threshold": 2.0, "positional_shadow_atlas_size": 1024}
		"Medium":
			v = {"msaa_3d": Viewport.MSAA_2X, "screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED, "use_taa": false,
				"scaling_3d_mode": Viewport.SCALING_3D_MODE_FSR, "scaling_3d_scale": 0.85, "fsr_sharpness": 0.3,
				"use_debanding": false, "mesh_lod_threshold": 1.0, "positional_shadow_atlas_size": 2048}
		"Mobile Ultra":
			v = {"msaa_3d": Viewport.MSAA_2X, "screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED, "use_taa": false,
				"scaling_3d_mode": Viewport.SCALING_3D_MODE_FSR, "scaling_3d_scale": 0.9, "fsr_sharpness": 0.25,
				"use_debanding": true, "mesh_lod_threshold": 1.0, "positional_shadow_atlas_size": 2048}
		"PC Cinematic":
			v = {"msaa_3d": Viewport.MSAA_DISABLED, "screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED, "use_taa": true,
				"scaling_3d_mode": Viewport.SCALING_3D_MODE_BILINEAR, "scaling_3d_scale": 1.0, "fsr_sharpness": 0.2,
				"use_debanding": true, "mesh_lod_threshold": 0.5, "positional_shadow_atlas_size": 8192}
	# Renderer capability fallbacks. Godot 4.7 (renderer_viewport.cpp) only allows FSR 1 / FSR 2 on Forward+;
	# on Mobile / Compatibility we use bilinear scaling and the post layer's sharpen pass instead.
	if renderer != "forward_plus":
		if v.get("scaling_3d_mode", 0) in [Viewport.SCALING_3D_MODE_FSR, Viewport.SCALING_3D_MODE_FSR2]:
			v["scaling_3d_mode"] = Viewport.SCALING_3D_MODE_BILINEAR
		if v.get("use_taa", false):
			v["use_taa"] = false
			v["msaa_3d"] = Viewport.MSAA_2X
		v["positional_shadow_atlas_size"] = mini(int(v.get("positional_shadow_atlas_size", 2048)), 2048)
	return v

## PC Cinematic with FSR 2 instead of native TAA (option "upscaler": "fsr2").
static func fsr2_override(renderer: String) -> Dictionary:
	if renderer != "forward_plus":
		return {}
	return {"use_taa": false, "scaling_3d_mode": Viewport.SCALING_3D_MODE_FSR2, "scaling_3d_scale": 0.77, "fsr_sharpness": 0.2}

# ------------------------------------------------------------------------------------------- RenderingServer (runtime)
static func render_for(preset: String) -> Dictionary:
	match preset:
		"Low":
			return {"dir_shadow_size": 1024, "dir_shadow_16": true, "soft_dir": RenderingServer.SHADOW_QUALITY_HARD,
				"soft_pos": RenderingServer.SHADOW_QUALITY_HARD, "glow_bicubic": false}
		"Medium":
			return {"dir_shadow_size": 2048, "dir_shadow_16": true, "soft_dir": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
				"soft_pos": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "glow_bicubic": false}
		"Mobile Ultra":
			return {"dir_shadow_size": 2048, "dir_shadow_16": true, "soft_dir": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
				"soft_pos": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "glow_bicubic": false,
				# used only when actually running on Forward+ (SSAO-lite)
				"ssao_q": RenderingServer.ENV_SSAO_QUALITY_LOW, "ssao_half": true}
		"PC Cinematic":
			return {"dir_shadow_size": 8192, "dir_shadow_16": false, "soft_dir": RenderingServer.SHADOW_QUALITY_SOFT_ULTRA,
				"soft_pos": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "glow_bicubic": true,
				"ssao_q": RenderingServer.ENV_SSAO_QUALITY_ULTRA, "ssao_half": false,
				"ssil_q": RenderingServer.ENV_SSIL_QUALITY_HIGH, "ssil_half": false,
				"ssr_q": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_HIGH,
				"vol_size": 128, "vol_depth": 128, "vol_filter": true,
				"sdfgi_rays": RenderingServer.ENV_SDFGI_RAY_COUNT_32, "sdfgi_converge": RenderingServer.ENV_SDFGI_CONVERGE_IN_15_FRAMES,
				"gi_half": false, "roughness_limiter": true}
	return {}

# ------------------------------------------------------------------------------------------- Environment
## Environment property values. Features the running renderer cannot draw are forced off.
static func env_for(preset: String, renderer: String, tonemapper := "") -> Dictionary:
	var e := {
		"tonemap_white": 6.0, "tonemap_exposure": 1.0,
		"sdfgi_enabled": false, "ssil_enabled": false, "ssr_enabled": false, "ssao_enabled": false,
		"volumetric_fog_enabled": false, "glow_enabled": false, "fog_enabled": false, "adjustment_enabled": false,
	}
	match preset:
		"Low":
			e.merge({"tonemap_mode": Environment.TONE_MAPPER_FILMIC,
				"fog_enabled": true, "fog_mode": Environment.FOG_MODE_EXPONENTIAL, "fog_density": 0.004,
				"fog_light_color": Color(0.70, 0.78, 0.88), "fog_sky_affect": 0.3, "fog_aerial_perspective": 0.0}, true)
		"Medium":
			e.merge({"tonemap_mode": Environment.TONE_MAPPER_ACES, "tonemap_white": 6.0,
				"glow_enabled": true, "glow_intensity": 0.5, "glow_strength": 0.9, "glow_bloom": 0.03,
				"glow_hdr_threshold": 1.0, "glow_blend_mode": Environment.GLOW_BLEND_MODE_SOFTLIGHT,
				"fog_enabled": true, "fog_mode": Environment.FOG_MODE_EXPONENTIAL, "fog_density": 0.003,
				"fog_light_color": Color(0.72, 0.80, 0.90), "fog_sun_scatter": 0.15, "fog_sky_affect": 0.35,
				"fog_aerial_perspective": 0.3, "fog_height": 2.0, "fog_height_density": 0.05}, true)
		"Mobile Ultra":
			e.merge({"tonemap_mode": Environment.TONE_MAPPER_ACES, "tonemap_white": 8.0, "tonemap_exposure": 1.05,
				"glow_enabled": true, "glow_intensity": 0.7, "glow_strength": 1.0, "glow_bloom": 0.06,
				"glow_hdr_threshold": 0.9, "glow_blend_mode": Environment.GLOW_BLEND_MODE_SOFTLIGHT,
				"fog_enabled": true, "fog_mode": Environment.FOG_MODE_EXPONENTIAL, "fog_density": 0.0025,
				"fog_light_color": Color(0.74, 0.82, 0.93), "fog_sun_scatter": 0.3, "fog_sky_affect": 0.4,
				"fog_aerial_perspective": 0.55, "fog_height": 3.0, "fog_height_density": 0.08,
				"adjustment_enabled": true, "adjustment_contrast": 1.06, "adjustment_saturation": 1.1,
				# SSAO-lite: only drawn on Forward+ (stripped below on the Mobile renderer)
				"ssao_enabled": true, "ssao_radius": 0.8, "ssao_intensity": 1.2, "ssao_power": 1.5,
				"ssao_detail": 0.3, "ssao_light_affect": 0.1}, true)
		"PC Cinematic":
			e.merge({"tonemap_mode": Environment.TONE_MAPPER_AGX, "tonemap_white": 16.0,
				"sdfgi_enabled": true, "sdfgi_use_occlusion": true, "sdfgi_read_sky_light": true, "sdfgi_cascades": 6,
				"sdfgi_min_cell_size": 0.2, "sdfgi_bounce_feedback": 0.5,
				"ssil_enabled": true, "ssil_radius": 5.0, "ssil_intensity": 1.0,
				"ssao_enabled": true, "ssao_radius": 1.2, "ssao_intensity": 2.0, "ssao_power": 1.5,
				"ssao_detail": 0.5, "ssao_light_affect": 0.2, "ssao_ao_channel_affect": 0.5,
				"ssr_enabled": true, "ssr_max_steps": 96, "ssr_fade_in": 0.15, "ssr_fade_out": 2.0, "ssr_depth_tolerance": 0.2,
				"volumetric_fog_enabled": true, "volumetric_fog_density": 0.012, "volumetric_fog_anisotropy": 0.6,
				"volumetric_fog_albedo": Color(0.92, 0.94, 1.0), "volumetric_fog_length": 96.0, "volumetric_fog_sky_affect": 0.6,
				"volumetric_fog_gi_inject": 1.0,
				"fog_enabled": true, "fog_mode": Environment.FOG_MODE_EXPONENTIAL, "fog_density": 0.0015,
				"fog_light_color": Color(0.74, 0.82, 0.93), "fog_sun_scatter": 0.3, "fog_sky_affect": 0.3,
				"fog_aerial_perspective": 0.7,
				"glow_enabled": true, "glow_intensity": 0.6, "glow_strength": 1.0, "glow_bloom": 0.05,
				"glow_hdr_threshold": 1.0, "glow_blend_mode": Environment.GLOW_BLEND_MODE_SOFTLIGHT,
				"adjustment_enabled": true, "adjustment_contrast": 1.04, "adjustment_saturation": 1.05}, true)
	match tonemapper.to_lower():
		"aces":
			e["tonemap_mode"] = Environment.TONE_MAPPER_ACES
		"agx":
			e["tonemap_mode"] = Environment.TONE_MAPPER_AGX
	if renderer != "forward_plus":
		for k in ["sdfgi_enabled", "ssil_enabled", "ssr_enabled", "ssao_enabled", "volumetric_fog_enabled"]:
			e[k] = false
	return e

## Sky radiance size per preset (smaller = cheaper reflections update).
static func sky_radiance_for(preset: String) -> int:
	return {"Low": Sky.RADIANCE_SIZE_32, "Medium": Sky.RADIANCE_SIZE_64, "Mobile Ultra": Sky.RADIANCE_SIZE_128,
		"PC Cinematic": Sky.RADIANCE_SIZE_256}.get(preset, Sky.RADIANCE_SIZE_64)

# ------------------------------------------------------------------------------------------- sun
## Godot has no built-in screen-space contact shadows; PC Cinematic gets PCSS (light_angular_distance),
## tight biases and blended 4-split cascades instead, plus SSAO/SSIL for contact darkening.
static func sun_for(preset: String, renderer: String) -> Dictionary:
	var d := {}
	match preset:
		"Low":
			d = {"shadow_enabled": true, "directional_shadow_mode": DirectionalLight3D.SHADOW_ORTHOGONAL,
				"directional_shadow_max_distance": 45.0, "light_angular_distance": 0.0, "shadow_blur": 1.0,
				"shadow_bias": 0.1, "shadow_normal_bias": 2.0, "directional_shadow_blend_splits": false}
		"Medium":
			d = {"shadow_enabled": true, "directional_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
				"directional_shadow_max_distance": 70.0, "light_angular_distance": 0.0, "shadow_blur": 1.2,
				"shadow_bias": 0.06, "shadow_normal_bias": 1.5, "directional_shadow_blend_splits": false}
		"Mobile Ultra":
			d = {"shadow_enabled": true, "directional_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
				"directional_shadow_max_distance": 100.0, "light_angular_distance": 0.0, "shadow_blur": 1.5,
				"shadow_bias": 0.04, "shadow_normal_bias": 1.2, "directional_shadow_blend_splits": false,
				"directional_shadow_split_1": 0.08, "directional_shadow_split_2": 0.22, "directional_shadow_split_3": 0.5}
		"PC Cinematic":
			d = {"shadow_enabled": true, "directional_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
				"directional_shadow_max_distance": 250.0, "light_angular_distance": 0.6, "shadow_blur": 1.0,
				"shadow_bias": 0.02, "shadow_normal_bias": 0.8, "directional_shadow_blend_splits": true,
				"directional_shadow_split_1": 0.05, "directional_shadow_split_2": 0.15, "directional_shadow_split_3": 0.4}
	if renderer != "forward_plus":
		d["light_angular_distance"] = 0.0
		d["directional_shadow_max_distance"] = minf(float(d.get("directional_shadow_max_distance", 80.0)), 100.0)
	return d

# ------------------------------------------------------------------------------------------- post-process
const LUT_WARM := "res://addons/chomu_ultra/luts/chomu_warm_teal.png"
const LUT_NEUTRAL := "res://addons/chomu_ultra/luts/neutral.png"

## Uniforms of shaders/post_grade.gdshader. "enabled": false hides the pass (zero cost).
static func post_for(preset: String) -> Dictionary:
	match preset:
		"Medium":
			return {"enabled": true, "flare": false, "lut_path": "", "use_lut": false,
				"contrast": 1.03, "saturation": 1.05, "sharpen": 0.25, "vignette_strength": 0.18,
				"grain_amount": 0.0, "chromatic_aberration": 0.0}
		"Mobile Ultra":
			return {"enabled": true, "flare": false, "lut_path": LUT_WARM, "use_lut": true, "lut_strength": 0.55,
				"contrast": 1.04, "saturation": 1.06, "sharpen": 0.4, "vignette_strength": 0.25,
				"grain_amount": 0.02, "chromatic_aberration": 0.0}
		"PC Cinematic":
			return {"enabled": true, "flare": true, "lut_path": LUT_WARM, "use_lut": true, "lut_strength": 0.45,
				"contrast": 1.03, "saturation": 1.04, "sharpen": 0.2, "vignette_strength": 0.3,
				"grain_amount": 0.03, "chromatic_aberration": 0.0012}
	return {"enabled": false, "flare": false}

static func engine_for(preset: String) -> Dictionary:
	# 0 = unlimited. Phones: cap to 60 so the GPU doesn't thermal-throttle chasing 90/120 Hz.
	return {"Low": {"max_fps": 60}, "Medium": {"max_fps": 60}, "Mobile Ultra": {"max_fps": 60},
		"PC Cinematic": {"max_fps": 0}}.get(preset, {})
