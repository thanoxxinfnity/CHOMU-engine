@tool
extends RefCounted
## CHoMU Looks (CHoMU Engine 1.3) - editor side of the Chomu Shader Pack looks.
## One tap applies a complete look to the OPEN scene, with undo:
##   sky (bundled CC0 Poly Haven HDRI or procedural) + Environment (tonemap, glow, fog, SSAO/SSR/SSIL/SDFGI...)
##   + sun (first DirectionalLight3D, created if missing) + post FX layer (colour grade, vignette, grain...)
##   + toon/cel conversion with outlines for the anime looks.
## Every look has a "_mobile" fallback (no Forward+-only effects, lighter sky, cheaper post FX) that is used
## automatically when the project's renderer is Mobile / Compatibility, or on request.
## Files a look needs are copied into the project (res://chomu/looks/) so the scene keeps working on export.
## Content source: the editor's data folder (unpacked from the editor APK assets at first start).

const PROJECT_DIR := "res://chomu/looks"
const OUTLINE_MAX_SIZE := 12.0

var plugin: EditorPlugin
var host: Node  # any node inside the editor tree (for timers)

static func content_dir() -> String:
	return EditorInterface.get_editor_paths().get_data_dir().path_join("chomu_store").path_join("looks")

static func order() -> PackedStringArray:
	return PackedStringArray(["Special Grade Realistic", "Special Grade Anime", "Realistic", "Sunset", "Night", "Rainy",
		"Foggy", "Horror", "Anime", "Cinematic", "Noir", "Retro"])

static func categories() -> PackedStringArray:
	return PackedStringArray(["All", "Special Grade", "Realistic", "Time of day", "Weather", "Mood", "Stylized"])

static func category(look: String) -> String:
	return {"Special Grade Realistic": "Special Grade", "Special Grade Anime": "Special Grade",
		"Realistic": "Realistic", "Sunset": "Time of day", "Night": "Time of day", "Rainy": "Weather",
		"Foggy": "Weather", "Horror": "Mood", "Cinematic": "Mood", "Noir": "Mood", "Anime": "Stylized",
		"Retro": "Stylized"}.get(look, "All")

static func file_id(look: String) -> String:
	return look.to_lower().replace(" ", "_")

static func hdri(id: String) -> String:
	return "hdri/" + id + ("_2k" if id == "kloofendal_48d_partly_cloudy_puresky" else "_1k") + ".hdr"

static func thumb_path(look: String) -> String:
	return content_dir().path_join("thumbs").path_join(file_id(look) + ".png")

## Project renderer as configured (not the editor's current one).
static func project_renderer() -> String:
	var m := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	if OS.has_feature("mobile") and ProjectSettings.has_setting("rendering/renderer/rendering_method.mobile"):
		m = str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"))
	return m

static func auto_mobile() -> bool:
	return RenderingServer.get_current_rendering_method() != "forward_plus" or project_renderer() != "forward_plus"

## Look table. Keys per look:
##   desc, swatch, sky {hdri|procedural, energy}, env (all renderers), forward (Forward+ only),
##   mobile (replaces env values in the _mobile fallback), sun, post (post_fx uniforms; {} = off),
##   post_mobile (optional cheaper post for the fallback), toon ("" | "classic" | "special").
static func all() -> Dictionary:
	return {
		"Special Grade Realistic": {
			"desc": "Photoreal max quality: SDFGI + SSIL + SSR + volumetric fog, AgX, high-res soft shadows. Grain / aberration off by default.",
			"badge": "SPECIAL GRADE",
			"swatch": [Color(0.32, 0.55, 0.95), Color(0.95, 0.78, 0.55)],
			"sky": {"hdri": "kloofendal_48d_partly_cloudy_puresky", "energy": 1.0},
			"env": {
				"tonemap_mode": Environment.TONE_MAPPER_AGX, "tonemap_exposure": 1.0, "tonemap_white": 16.0,
				"tonemap_agx_contrast": 1.25,
				"glow_enabled": true, "glow_intensity": 0.45, "glow_strength": 1.0, "glow_bloom": 0.04,
				"glow_blend_mode": Environment.GLOW_BLEND_MODE_SOFTLIGHT, "glow_hdr_threshold": 1.0,
				"fog_enabled": true, "fog_light_color": Color(0.68, 0.76, 0.9), "fog_density": 0.0012,
				"fog_aerial_perspective": 0.75, "fog_sky_affect": 0.25,
				"ambient_light_sky_contribution": 1.0, "ambient_light_energy": 1.0,
				"adjustment_enabled": true, "adjustment_contrast": 1.04, "adjustment_saturation": 1.06,
			},
			"forward": {
				"sdfgi_enabled": true, "sdfgi_use_occlusion": true, "sdfgi_read_sky_light": true,
				"sdfgi_bounce_feedback": 0.6, "sdfgi_cascades": 6, "sdfgi_min_cell_size": 0.15, "sdfgi_energy": 1.0,
				"ssil_enabled": true, "ssil_radius": 6.0, "ssil_intensity": 1.2, "ssil_sharpness": 0.98,
				"ssao_enabled": true, "ssao_radius": 1.4, "ssao_intensity": 2.0, "ssao_detail": 0.6, "ssao_light_affect": 0.15,
				"ssr_enabled": true, "ssr_max_steps": 128, "ssr_fade_in": 0.12, "ssr_fade_out": 2.5, "ssr_depth_tolerance": 0.15,
				"volumetric_fog_enabled": true, "volumetric_fog_density": 0.012, "volumetric_fog_albedo": Color(0.9, 0.92, 0.95),
				"volumetric_fog_anisotropy": 0.65, "volumetric_fog_length": 96.0, "volumetric_fog_gi_inject": 1.0,
				"volumetric_fog_sky_affect": 0.4, "volumetric_fog_temporal_reprojection_enabled": true,
			},
			"mobile": {"glow_intensity": 0.35, "glow_blend_mode": Environment.GLOW_BLEND_MODE_SOFTLIGHT, "ambient_light_energy": 1.15,
				"fog_density": 0.002},
			"sun": {"color": Color(1.0, 0.95, 0.88), "energy": 1.6, "rot": Vector3(-42, -35, 0), "shadows": true,
				"angular": 0.8, "volumetric_fog_energy": 1.5, "split": 4, "max_distance": 300.0},
			"sun_mobile": {"angular": 0.0, "split": 2, "max_distance": 120.0},
			"post": {"vignette": 0.35, "vignette_softness": 0.95, "grain": 0.0, "chromatic_aberration": 0.0},
			"post_mobile": {},
			"toon": "",
		},
		"Special Grade Anime": {
			"desc": "Top-tier anime: cel shading with crisp outlines, cursed-energy rim light, punchy bloom, saturated contrast.",
			"badge": "SPECIAL GRADE",
			"swatch": [Color(0.25, 0.45, 1.0), Color(0.75, 0.2, 0.9)],
			"sky": {"procedural": {"sky_top_color": Color(0.12, 0.36, 0.95), "sky_horizon_color": Color(0.62, 0.84, 1.0),
				"ground_horizon_color": Color(0.62, 0.8, 0.95), "ground_bottom_color": Color(0.22, 0.26, 0.36),
				"sun_angle_max": 18.0, "sun_curve": 0.08}, "energy": 1.15},
			"env": {
				"tonemap_mode": Environment.TONE_MAPPER_AGX, "tonemap_exposure": 0.95, "tonemap_white": 6.0,
				"tonemap_agx_contrast": 1.3,
				"glow_enabled": true, "glow_intensity": 0.9, "glow_strength": 1.1, "glow_bloom": 0.0,
				"glow_blend_mode": Environment.GLOW_BLEND_MODE_SCREEN, "glow_hdr_threshold": 1.0, "glow_hdr_scale": 2.5,
				"fog_enabled": true, "fog_light_color": Color(0.62, 0.78, 1.0), "fog_density": 0.002, "fog_sky_affect": 0.0,
				"ambient_light_source": Environment.AMBIENT_SOURCE_COLOR,
				"ambient_light_color": Color(0.62, 0.68, 0.95), "ambient_light_energy": 0.45,
				"adjustment_enabled": true, "adjustment_contrast": 1.12, "adjustment_saturation": 1.35, "adjustment_brightness": 1.0,
			},
			"forward": {"ssao_enabled": true, "ssao_radius": 0.8, "ssao_intensity": 1.2, "ssao_light_affect": 0.0,
				"ssil_enabled": false, "sdfgi_enabled": false,
				"volumetric_fog_enabled": true, "volumetric_fog_density": 0.006, "volumetric_fog_albedo": Color(0.8, 0.88, 1.0),
				"volumetric_fog_anisotropy": 0.7, "volumetric_fog_length": 64.0},
			"mobile": {"glow_intensity": 0.75, "glow_blend_mode": Environment.GLOW_BLEND_MODE_SCREEN},
			"sun": {"color": Color(1.0, 0.96, 0.9), "energy": 1.15, "rot": Vector3(-38, -42, 0), "shadows": true,
				"angular": 0.0, "split": 4, "max_distance": 200.0, "shadow_bias": 0.08, "shadow_normal_bias": 2.0},
			"sun_mobile": {"split": 2, "max_distance": 90.0},
			"post": {"saturation": 1.12, "contrast": 1.06, "edge_strength": 0.7, "edge_threshold": 0.35,
				"edge_color": Color(0.04, 0.02, 0.08), "vignette": 0.45},
			"post_mobile": {"saturation": 1.1, "contrast": 1.05},
			"toon": "special",
		},
		"Realistic": {
			"desc": "Clear day, real HDRI sky, AgX tonemap, soft bloom, SSAO + SSR on Forward+.",
			"swatch": [Color(0.45, 0.62, 0.85), Color(0.75, 0.72, 0.62)],
			"sky": {"hdri": "kloofendal_48d_partly_cloudy_puresky", "energy": 1.0},
			"env": {
				"tonemap_mode": Environment.TONE_MAPPER_AGX, "tonemap_exposure": 1.0,
				"glow_enabled": true, "glow_intensity": 0.3, "glow_bloom": 0.03, "glow_strength": 0.9,
				"fog_enabled": true, "fog_light_color": Color(0.7, 0.78, 0.9), "fog_density": 0.0015,
				"fog_aerial_perspective": 0.6, "fog_sky_affect": 0.2,
				"ambient_light_sky_contribution": 1.0, "ambient_light_energy": 1.0,
			},
			"forward": {"ssao_enabled": true, "ssao_radius": 1.2, "ssao_intensity": 1.6, "ssr_enabled": true, "ssr_max_steps": 48},
			"mobile": {"ambient_light_energy": 1.15},
			"sun": {"color": Color(1.0, 0.96, 0.9), "energy": 1.3, "rot": Vector3(-50, -35, 0), "shadows": true},
			"post": {"vignette": 0.45, "vignette_softness": 0.9},
		},
		"Sunset": {
			"desc": "Golden hour: warm low sun, orange haze, strong bloom.",
			"swatch": [Color(0.98, 0.55, 0.25), Color(0.35, 0.2, 0.35)],
			"sky": {"hdri": "venice_sunset", "energy": 1.0},
			"env": {
				"tonemap_mode": Environment.TONE_MAPPER_FILMIC, "tonemap_exposure": 1.1,
				"glow_enabled": true, "glow_intensity": 0.7, "glow_bloom": 0.1, "glow_hdr_threshold": 0.9,
				"fog_enabled": true, "fog_light_color": Color(0.95, 0.6, 0.35), "fog_density": 0.006,
				"fog_sun_scatter": 0.4, "fog_aerial_perspective": 0.4, "fog_sky_affect": 0.15,
				"ambient_light_energy": 0.9,
			},
			"forward": {"ssao_enabled": true, "ssr_enabled": true},
			"mobile": {"fog_density": 0.008},
			"sun": {"color": Color(1.0, 0.62, 0.32), "energy": 1.8, "rot": Vector3(-9, 60, 0), "shadows": true},
			"post": {"tint": Color(1.05, 0.97, 0.88), "saturation": 1.15, "contrast": 1.05, "vignette": 0.8},
		},
		"Night": {
			"desc": "Moonlit night, blue ambient, city lights bloom, wet reflections.",
			"swatch": [Color(0.05, 0.08, 0.2), Color(0.95, 0.75, 0.4)],
			"sky": {"hdri": "moonlit_golf", "energy": 0.6},
			"env": {
				"tonemap_mode": Environment.TONE_MAPPER_ACES, "tonemap_exposure": 1.3,
				"glow_enabled": true, "glow_intensity": 1.0, "glow_bloom": 0.15, "glow_hdr_threshold": 0.8,
				"fog_enabled": true, "fog_light_color": Color(0.08, 0.1, 0.2), "fog_density": 0.01,
				"ambient_light_source": Environment.AMBIENT_SOURCE_COLOR,
				"ambient_light_color": Color(0.25, 0.3, 0.55), "ambient_light_energy": 0.35,
			},
			"forward": {"ssr_enabled": true, "ssao_enabled": true},
			"mobile": {"ambient_light_energy": 0.45},
			"sun": {"color": Color(0.6, 0.7, 1.0), "energy": 0.18, "rot": Vector3(-35, 140, 0), "shadows": true},
			"post": {"tint": Color(0.9, 0.95, 1.1), "saturation": 0.85, "vignette": 1.0, "grain": 0.03},
		},
		"Rainy": {
			"desc": "Overcast, flat light, grey-blue grade - pairs with the wet road shader.",
			"swatch": [Color(0.55, 0.58, 0.62), Color(0.2, 0.22, 0.25)],
			"sky": {"hdri": "overcast_soil_puresky", "energy": 0.8},
			"env": {
				"tonemap_mode": Environment.TONE_MAPPER_AGX, "tonemap_exposure": 1.05,
				"glow_enabled": true, "glow_intensity": 0.25,
				"fog_enabled": true, "fog_light_color": Color(0.6, 0.64, 0.7), "fog_density": 0.012, "fog_sky_affect": 0.5,
			},
			"forward": {"ssr_enabled": true, "ssao_enabled": true},
			"mobile": {},
			"sun": {"color": Color(0.85, 0.9, 1.0), "energy": 0.35, "rot": Vector3(-65, 20, 0), "shadows": false},
			"post": {"saturation": 0.8, "tint": Color(0.95, 0.98, 1.05), "contrast": 1.05, "vignette": 0.6},
		},
		"Horror": {
			"desc": "Desaturated green-blue, heavy fog, vignette, film grain, flicker.",
			"swatch": [Color(0.2, 0.28, 0.25), Color(0.02, 0.03, 0.03)],
			"sky": {"hdri": "misty_pines", "energy": 0.35},
			"env": {
				"tonemap_mode": Environment.TONE_MAPPER_FILMIC, "tonemap_exposure": 1.0,
				"glow_enabled": true, "glow_intensity": 0.4,
				"fog_enabled": true, "fog_light_color": Color(0.32, 0.38, 0.36), "fog_density": 0.03, "fog_sky_affect": 0.9,
				"ambient_light_energy": 0.7,
			},
			"forward": {"volumetric_fog_enabled": true, "volumetric_fog_density": 0.03,
				"volumetric_fog_albedo": Color(0.6, 0.7, 0.65), "ssao_enabled": true, "ssao_intensity": 3.0},
			"mobile": {"fog_density": 0.04},
			"sun": {"color": Color(0.7, 0.85, 0.8), "energy": 0.3, "rot": Vector3(-20, -120, 0), "shadows": true},
			"post": {"saturation": 0.35, "tint": Color(0.85, 1.0, 0.92), "lift": Color(0.0, 0.03, 0.04),
				"contrast": 1.15, "vignette": 1.3, "vignette_softness": 0.7, "grain": 0.1,
				"chromatic_aberration": 0.004, "flicker": 0.15},
			"post_mobile": {"saturation": 0.35, "tint": Color(0.85, 1.0, 0.92), "lift": Color(0.0, 0.03, 0.04),
				"contrast": 1.15, "vignette": 1.3, "vignette_softness": 0.7, "grain": 0.08, "flicker": 0.15},
		},
		"Foggy": {
			"desc": "Thick cool morning fog, soft shadowless light, distant objects fade out.",
			"swatch": [Color(0.72, 0.76, 0.8), Color(0.4, 0.45, 0.48)],
			"sky": {"hdri": "misty_pines", "energy": 0.9},
			"env": {
				"tonemap_mode": Environment.TONE_MAPPER_AGX, "tonemap_exposure": 1.1,
				"glow_enabled": true, "glow_intensity": 0.3, "glow_bloom": 0.08,
				"fog_enabled": true, "fog_light_color": Color(0.72, 0.76, 0.8), "fog_light_energy": 1.0,
				"fog_density": 0.028, "fog_sky_affect": 0.8, "fog_aerial_perspective": 0.0,
				"ambient_light_energy": 1.1,
			},
			"forward": {"volumetric_fog_enabled": true, "volumetric_fog_density": 0.02,
				"volumetric_fog_albedo": Color(0.85, 0.88, 0.9), "ssao_enabled": true},
			"mobile": {"fog_density": 0.032},
			"sun": {"color": Color(0.9, 0.93, 1.0), "energy": 0.45, "rot": Vector3(-55, 30, 0), "shadows": false},
			"post": {"saturation": 0.75, "contrast": 0.95, "lift": Color(0.03, 0.035, 0.04), "vignette": 0.5},
		},
		"Noir": {
			"desc": "Black & white film noir: hard contrast, deep shadows, grain and vignette.",
			"swatch": [Color(0.9, 0.9, 0.9), Color(0.05, 0.05, 0.05)],
			"sky": {"hdri": "wide_street_01", "energy": 0.7},
			"env": {
				"tonemap_mode": Environment.TONE_MAPPER_FILMIC, "tonemap_exposure": 1.0,
				"glow_enabled": true, "glow_intensity": 0.6, "glow_bloom": 0.1, "glow_hdr_threshold": 0.9,
				"fog_enabled": true, "fog_light_color": Color(0.5, 0.5, 0.5), "fog_density": 0.006,
				"ambient_light_energy": 0.5,
			},
			"forward": {"ssao_enabled": true, "ssao_intensity": 2.5, "ssr_enabled": true},
			"mobile": {"ambient_light_energy": 0.6},
			"sun": {"color": Color(1.0, 1.0, 1.0), "energy": 1.6, "rot": Vector3(-28, 110, 0), "shadows": true},
			"post": {"saturation": 0.0, "contrast": 1.35, "vignette": 1.2, "vignette_softness": 0.7, "grain": 0.07},
		},
		"Anime": {
			"desc": "Toon/cel shading + black outlines, bright saturated sky (scene materials auto-converted).",
			"swatch": [Color(0.35, 0.65, 1.0), Color(1.0, 0.8, 0.85)],
			"sky": {"procedural": {"sky_top_color": Color(0.2, 0.5, 1.0), "sky_horizon_color": Color(0.7, 0.88, 1.0),
				"ground_horizon_color": Color(0.7, 0.85, 0.95), "ground_bottom_color": Color(0.35, 0.45, 0.4)}, "energy": 1.0},
			"env": {
				"tonemap_mode": Environment.TONE_MAPPER_LINEAR, "tonemap_exposure": 1.0,
				"glow_enabled": true, "glow_intensity": 0.35, "glow_bloom": 0.05,
				"fog_enabled": true, "fog_light_color": Color(0.75, 0.88, 1.0), "fog_density": 0.003, "fog_sky_affect": 0.0,
				"ambient_light_source": Environment.AMBIENT_SOURCE_COLOR,
				"ambient_light_color": Color(0.75, 0.8, 0.95), "ambient_light_energy": 0.6,
			},
			"forward": {},
			"mobile": {},
			"sun": {"color": Color(1.0, 0.97, 0.92), "energy": 1.2, "rot": Vector3(-45, -40, 0), "shadows": true},
			"post": {"saturation": 1.3, "contrast": 1.05, "edge_strength": 0.6, "edge_threshold": 0.45},
			"toon": "classic",
		},
		"Cinematic": {
			"desc": "Teal-orange film grade, letterbox bars, light grain and lens fringing.",
			"swatch": [Color(0.1, 0.35, 0.4), Color(0.95, 0.6, 0.35)],
			"sky": {"hdri": "wide_street_01", "energy": 1.0},
			"env": {
				"tonemap_mode": Environment.TONE_MAPPER_AGX, "tonemap_exposure": 0.95,
				"glow_enabled": true, "glow_intensity": 0.5, "glow_bloom": 0.06,
				"fog_enabled": true, "fog_light_color": Color(0.6, 0.65, 0.7), "fog_density": 0.004, "fog_aerial_perspective": 0.5,
			},
			"forward": {"ssao_enabled": true, "ssr_enabled": true},
			"mobile": {},
			"sun": {"color": Color(1.0, 0.85, 0.7), "energy": 1.4, "rot": Vector3(-25, 45, 0), "shadows": true},
			"post": {"lift": Color(0.0, 0.03, 0.05), "gain": Color(1.06, 0.98, 0.9), "saturation": 1.1, "contrast": 1.12,
				"letterbox": 0.1, "vignette": 0.9, "grain": 0.04, "chromatic_aberration": 0.0015},
		},
		"Retro": {
			"desc": "Pixelated 90s console look: big pixels, few colours, scanlines.",
			"swatch": [Color(0.55, 0.3, 0.6), Color(1.0, 0.6, 0.3)],
			"sky": {"procedural": {"sky_top_color": Color(0.3, 0.2, 0.55), "sky_horizon_color": Color(1.0, 0.55, 0.4),
				"ground_horizon_color": Color(0.6, 0.4, 0.4), "ground_bottom_color": Color(0.15, 0.1, 0.15)}, "energy": 1.0},
			"env": {
				"tonemap_mode": Environment.TONE_MAPPER_LINEAR, "tonemap_exposure": 1.0,
				"glow_enabled": false,
				"fog_enabled": true, "fog_light_color": Color(0.8, 0.5, 0.5), "fog_density": 0.01,
				"ambient_light_energy": 0.8,
			},
			"forward": {},
			"mobile": {},
			"sun": {"color": Color(1.0, 0.8, 0.6), "energy": 1.1, "rot": Vector3(-30, 70, 0), "shadows": false},
			"post": {"pixel_size": 3.0, "posterize_levels": 8.0, "scanlines": 0.3, "saturation": 1.25},
		},
	}

static func post_defaults() -> Dictionary:
	return {
		"exposure": 1.0, "contrast": 1.0, "saturation": 1.0, "tint": Color(1, 1, 1), "lift": Color(0, 0, 0),
		"gain": Color(1, 1, 1), "gamma": 1.0, "vignette": 0.0, "vignette_softness": 0.6, "vignette_color": Color(0, 0, 0),
		"chromatic_aberration": 0.0, "grain": 0.0, "letterbox": 0.0, "pixel_size": 0.0, "posterize_levels": 0.0,
		"edge_strength": 0.0, "edge_threshold": 0.15, "edge_color": Color(0.05, 0.03, 0.08), "scanlines": 0.0, "flicker": 0.0,
	}

## Names of the Forward+-only effects a look turns on (for badges / the info line).
static func forward_extras(look: String) -> PackedStringArray:
	var out := PackedStringArray()
	var f: Dictionary = all().get(look, {}).get("forward", {})
	for k in [["sdfgi_enabled", "SDFGI"], ["ssil_enabled", "SSIL"], ["ssr_enabled", "SSR"], ["ssao_enabled", "SSAO"],
			["volumetric_fog_enabled", "Volumetric fog"]]:
		if f.get(k[0], false):
			out.append(k[1])
	return out

# ------------------------------------------------------------------------------------------- install

## Copies a file from the bundled content into the project (only if missing or changed in size).
static func _install(rel: String) -> String:
	var src := content_dir().path_join(rel)
	var dst := PROJECT_DIR.path_join(rel)
	if not FileAccess.file_exists(src):
		return ""
	var gdst := ProjectSettings.globalize_path(dst)
	if FileAccess.file_exists(gdst):
		var a := FileAccess.open(src, FileAccess.READ)
		var b := FileAccess.open(gdst, FileAccess.READ)
		if a and b and a.get_length() == b.get_length():
			return dst
	DirAccess.make_dir_recursive_absolute(gdst.get_base_dir())
	if DirAccess.copy_absolute(src, gdst) != OK:
		return ""
	return dst

static func content_ok() -> bool:
	return FileAccess.file_exists(content_dir().path_join("shaders/post_fx.gdshader"))

## Installs what a look needs into res://chomu/looks/ and waits until the editor imported it.
func install_for(look: String) -> Dictionary:
	var p: Dictionary = all().get(look, {})
	var out := {"post": "", "toon": "", "toon_special": "", "outline": "", "hdri": ""}
	out.post = _install("shaders/post_fx.gdshader")
	if str(p.get("toon", "")) != "":
		out.toon = _install("shaders/toon.gdshader")
		out.toon_special = _install("shaders/toon_special.gdshader")
		out.outline = _install("shaders/toon_outline.gdshader")
	var sky: Dictionary = p.get("sky", {})
	if sky.has("hdri"):
		out.hdri = _install(hdri(str(sky.hdri)))
		_install("CREDITS.txt")
	var need: Array = []
	for k in out:
		if out[k] != "" and not ResourceLoader.exists(out[k]):
			need.append(out[k])
	if need.size() > 0:
		await _wait_import(need)
	return out

func _wait_import(paths: Array) -> bool:
	var efs := EditorInterface.get_resource_filesystem()
	await host.get_tree().create_timer(0.3, true, false, true).timeout
	if not efs.is_scanning():
		efs.scan()
	var t := 0.0
	while t < 300.0:
		await host.get_tree().create_timer(0.25, true, false, true).timeout
		t += 0.25
		if efs.is_scanning():
			continue
		var ok := true
		for p in paths:
			if not ResourceLoader.exists(p):
				ok = false
		if ok:
			return true
		if fmod(t, 15.0) < 0.26:
			efs.scan()
	return false

# ------------------------------------------------------------------------------------------- build

static func build_environment(look: String, mobile: bool, files: Dictionary) -> Environment:
	var p: Dictionary = all().get(look, {})
	if p.is_empty():
		return null
	var env := Environment.new()
	env.resource_name = look + (" (mobile)" if mobile else "")
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_64 if mobile else Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL if mobile else Sky.PROCESS_MODE_QUALITY
	var sd: Dictionary = p.get("sky", {})
	var hdr_path: String = files.get("hdri", "")
	if sd.has("hdri") and hdr_path != "" and ResourceLoader.exists(hdr_path):
		var pm := PanoramaSkyMaterial.new()
		pm.panorama = load(hdr_path)
		pm.filter = true
		pm.energy_multiplier = sd.get("energy", 1.0)
		sky.sky_material = pm
	else:
		var proc := ProceduralSkyMaterial.new()
		var pd: Dictionary = sd.get("procedural", {})
		for k in pd:
			proc.set(k, pd[k])
		proc.energy_multiplier = sd.get("energy", 1.0)
		sky.sky_material = proc
	env.sky = sky
	var envd: Dictionary = p.get("env", {})
	for k in envd:
		env.set(k, envd[k])
	if mobile:
		var md: Dictionary = p.get("mobile", {})
		for k in md:
			env.set(k, md[k])
	else:
		var fd: Dictionary = p.get("forward", {})
		for k in fd:
			env.set(k, fd[k])
	return env

static func _make_toon_from(m: Material, outline: bool, files: Dictionary, special: bool, mobile: bool) -> ShaderMaterial:
	var t := ShaderMaterial.new()
	var use_special: bool = special and str(files.get("toon_special", "")) != ""
	t.shader = load(files.toon_special if use_special else files.toon)
	var col := Color(0.85, 0.85, 0.85)
	var tex: Texture2D = null
	if m is BaseMaterial3D:
		col = (m as BaseMaterial3D).albedo_color
		tex = (m as BaseMaterial3D).albedo_texture
	elif m is ShaderMaterial and (m as ShaderMaterial).shader:
		var sm := m as ShaderMaterial
		for pname in ["albedo_tex", "albedo_texture", "texture_albedo"]:
			var v = sm.get_shader_parameter(pname)
			if v is Texture2D:
				tex = v
		for pname in ["paint_color", "albedo", "tint", "albedo_color"]:
			var c = sm.get_shader_parameter(pname)
			if c == null:
				c = RenderingServer.shader_get_parameter_default(sm.shader.get_rid(), pname)
			if c is Color:
				col = c
				break
	if use_special:
		col = col.lightened(0.08)
		t.set_shader_parameter("albedo", col)
		var sh := col.darkened(0.5).lerp(Color(0.3, 0.24, 0.55), 0.4)
		t.set_shader_parameter("shade_color", sh)
		if mobile:
			t.set_shader_parameter("rim_strength", 1.1)
			t.set_shader_parameter("specular_strength", 0.8)
		if not outline:
			# Ground / walls / big props: no rim (a fresnel rim lights up every grazing-angle floor) and no glint.
			t.set_shader_parameter("rim_strength", 0.0)
			t.set_shader_parameter("specular_strength", 0.0)
	else:
		col = col.lightened(0.15)
		t.set_shader_parameter("albedo", col)
		t.set_shader_parameter("shade_color", col.darkened(0.45).lerp(Color(0.45, 0.4, 0.7), 0.35))
		if not outline:
			t.set_shader_parameter("rim_strength", 0.0)
	if tex:
		t.set_shader_parameter("albedo_texture", tex)
		t.set_shader_parameter("use_texture", true)
	if outline and files.get("outline", "") != "":
		var o := ShaderMaterial.new()
		o.shader = load(files.outline)
		if use_special:
			o.set_shader_parameter("outline_color", Color(0.03, 0.02, 0.06))
			o.set_shader_parameter("outline_width", 0.03 if mobile else 0.04)
		t.next_pass = o
	return t

# ------------------------------------------------------------------------------------------- apply

static func _find_first(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := _find_first(c, cls)
		if f:
			return f
	return null

static func _meshes(n: Node, out: Array) -> Array:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)
	return out

## Applies a look to the edited scene. Returns a short human summary (or "" on failure).
func apply(look: String, mobile: bool) -> String:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return ""
	var p: Dictionary = all().get(look, {})
	if p.is_empty():
		return ""
	var files: Dictionary = await install_for(look)
	if files.post == "":
		push_error("CHoMU Looks: bundled look files are missing (%s)." % content_dir())
		return ""
	root = EditorInterface.get_edited_scene_root()  # scene could have changed while importing
	if root == null:
		return ""
	var env := build_environment(look, mobile, files)
	var env_path := PROJECT_DIR.path_join(file_id(look) + ("_mobile" if mobile else "") + ".tres")
	if ResourceSaver.save(env, env_path) == OK:
		env.take_over_path(env_path)
	var ur := plugin.get_undo_redo()
	ur.create_action("CHoMU Look: %s%s" % [look, " (mobile)" if mobile else ""], UndoRedo.MERGE_DISABLE, root)
	# World environment --------------------------------------------------------------------
	var we := _find_first(root, "WorldEnvironment") as WorldEnvironment
	if we:
		ur.add_do_property(we, "environment", env)
		ur.add_undo_property(we, "environment", we.environment)
	else:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		we.environment = env
		ur.add_do_method(root, "add_child", we, true)
		ur.add_do_method(we, "set_owner", root)
		ur.add_do_reference(we)
		ur.add_undo_method(root, "remove_child", we)
	# Sun -----------------------------------------------------------------------------------
	var s: Dictionary = p.get("sun", {}).duplicate()
	if mobile:
		s.merge(p.get("sun_mobile", {}), true)
	if root is Node3D and not s.is_empty():
		var sun := _find_first(root, "DirectionalLight3D") as DirectionalLight3D
		var props := {
			"light_color": s.get("color", Color.WHITE), "light_energy": s.get("energy", 1.0),
			"rotation_degrees": s.get("rot", Vector3(-45, -30, 0)), "shadow_enabled": s.get("shadows", true),
			"light_angular_distance": s.get("angular", 0.0),
			"directional_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if int(s.get("split", 4)) == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
			"directional_shadow_max_distance": s.get("max_distance", 100.0),
			"light_volumetric_fog_energy": s.get("volumetric_fog_energy", 1.0),
		}
		for extra in ["shadow_bias", "shadow_normal_bias", "shadow_blur"]:
			if s.has(extra):
				props[extra] = s[extra]
		if sun:
			for k in props:
				ur.add_do_property(sun, k, props[k])
				ur.add_undo_property(sun, k, sun.get(k))
		else:
			sun = DirectionalLight3D.new()
			sun.name = "Sun"
			for k in props:
				sun.set(k, props[k])
			ur.add_do_method(root, "add_child", sun, true)
			ur.add_do_method(sun, "set_owner", root)
			ur.add_do_reference(sun)
			ur.add_undo_method(root, "remove_child", sun)
	# Post FX layer ---------------------------------------------------------------------------
	var post: Dictionary = p.get("post", {})
	if mobile and p.has("post_mobile"):
		post = p.post_mobile
	var old_layer := root.get_node_or_null("ChomuPostFX")
	if old_layer:
		ur.add_do_method(root, "remove_child", old_layer)
		ur.add_undo_method(root, "add_child", old_layer, true)
		ur.add_undo_method(old_layer, "set_owner", root)
		ur.add_undo_reference(old_layer)
	if not post.is_empty():
		var layer := CanvasLayer.new()
		layer.name = "ChomuPostFX"
		layer.layer = 90
		var rect := ColorRect.new()
		rect.name = "Grade"
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load(files.post)
		var d := post_defaults()
		d.merge(post, true)
		for k in d:
			var v = d[k]
			if v is Color:
				v = Vector3(v.r, v.g, v.b)
			mat.set_shader_parameter(k, v)
		rect.material = mat
		layer.add_child(rect)
		ur.add_do_method(root, "add_child", layer, true)
		ur.add_do_method(layer, "set_owner", root)
		ur.add_do_method(rect, "set_owner", root)
		ur.add_do_reference(layer)
		ur.add_undo_method(root, "remove_child", layer)
	# Toon / cel conversion -------------------------------------------------------------------
	var toon := str(p.get("toon", ""))
	var converted := 0
	var restored := 0
	for mi in _meshes(root, []):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		var was: bool = m3.has_meta("chomu_orig_mats")
		if was:
			# Restore originals first (both when switching to a non-toon look and when re-toonifying).
			var orig: Array = m3.get_meta("chomu_orig_mats")
			var cur := []
			for si in m3.mesh.get_surface_count():
				cur.append(m3.get_surface_override_material(si))
			for si in min(orig.size(), m3.mesh.get_surface_count()):
				ur.add_do_method(m3, "set_surface_override_material", si, orig[si])
				ur.add_undo_method(m3, "set_surface_override_material", si, cur[si])
			ur.add_do_property(m3, "material_override", m3.get_meta("chomu_orig_override", null))
			ur.add_undo_property(m3, "material_override", m3.material_override)
			ur.add_do_method(m3, "remove_meta", "chomu_orig_mats")
			ur.add_do_method(m3, "remove_meta", "chomu_orig_override")
			ur.add_undo_method(m3, "set_meta", "chomu_orig_mats", orig)
			ur.add_undo_method(m3, "set_meta", "chomu_orig_override", m3.get_meta("chomu_orig_override", null))
			restored += 1
		if toon == "":
			continue
		var src: Material = m3.get_meta("chomu_orig_override", null) if was else m3.material_override
		if src is ShaderMaterial and ((src as ShaderMaterial).shader == null or (src as ShaderMaterial).shader.get_mode() != Shader.MODE_SPATIAL):
			continue
		var world_size: float = (m3.global_transform.basis * m3.get_aabb().size).length() if m3.is_inside_tree() else m3.get_aabb().size.length()
		var big: bool = m3.mesh is PlaneMesh or m3.mesh is QuadMesh or world_size > OUTLINE_MAX_SIZE
		var orig_mats := []
		var new_mats := []
		var orig_list: Array = m3.get_meta("chomu_orig_mats") if was else []
		for si in m3.mesh.get_surface_count():
			var o_mat: Material = orig_list[si] if was and si < orig_list.size() else m3.get_surface_override_material(si)
			orig_mats.append(o_mat)
			var basem: Material = src if src else (o_mat if o_mat else m3.mesh.surface_get_material(si))
			if basem is ShaderMaterial and (basem as ShaderMaterial).shader and str((basem as ShaderMaterial).shader.resource_path).get_file().begins_with("water"):
				new_mats.append(o_mat)
				continue
			new_mats.append(_make_toon_from(basem, not big, files, toon == "special", mobile))
		ur.add_do_method(m3, "set_meta", "chomu_orig_mats", orig_mats)
		ur.add_do_method(m3, "set_meta", "chomu_orig_override", src)
		for si in new_mats.size():
			ur.add_do_method(m3, "set_surface_override_material", si, new_mats[si])
		ur.add_do_property(m3, "material_override", null)
		if not was:
			for si in new_mats.size():
				ur.add_undo_method(m3, "set_surface_override_material", si, orig_mats[si])
			ur.add_undo_property(m3, "material_override", m3.material_override)
			ur.add_undo_method(m3, "remove_meta", "chomu_orig_mats")
			ur.add_undo_method(m3, "remove_meta", "chomu_orig_override")
		# Meshes inside an instanced scene (e.g. an imported model) need editable children to be saved.
		if m3.owner and m3.owner != root and m3.owner.owner == root and not root.is_editable_instance(m3.owner):
			ur.add_do_method(root, "set_editable_instance", m3.owner, true)
			ur.add_undo_method(root, "set_editable_instance", m3.owner, false)
		converted += 1
	ur.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	var bits := PackedStringArray()
	bits.append("mobile fallback" if mobile else "full quality")
	if not mobile:
		var fx := forward_extras(look)
		if fx.size() > 0:
			bits.append(", ".join(fx))
	if converted > 0:
		bits.append("%d meshes cel-shaded" % converted)
	elif restored > 0 and toon == "":
		bits.append("%d meshes restored" % restored)
	if not post.is_empty():
		bits.append("post FX (visible when the game runs)")
	return "%s applied - %s." % [look, ", ".join(bits)]
