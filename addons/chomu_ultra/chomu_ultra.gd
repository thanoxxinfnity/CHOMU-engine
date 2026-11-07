@tool
class_name ChomuUltra
extends RefCounted
## CHoMU Ultra runtime API.
##
##   ChomuUltra.apply("Mobile Ultra")          # or "Low", "Medium", "PC Cinematic", "Auto"
##   ChomuUltra.apply("Auto")                  # picks by device tier (GPU / RAM / renderer)
##   ChomuUltra.apply("PC Cinematic", null, {"gi": "voxelgi", "upscaler": "fsr2", "tonemapper": "AgX"})
##   ChomuUltra.enable_adaptive(60)            # drop resolution, then preset, if fps stays under target
##
## What it touches (all at runtime, no restart needed):
##  - the Viewport: MSAA / FXAA / TAA, 3D scaling (FSR 1 / FSR 2), debanding, mesh LOD, shadow atlas
##  - RenderingServer: shadow atlas size + soft-shadow filter, SSAO/SSIL/SSR/SDFGI/volumetric quality (Forward+ only)
##  - the scene's WorldEnvironment (created with a procedural sky if missing): tonemap, glow, fog, GI, SSR...
##  - the first DirectionalLight3D: cascades, distance, biases, PCSS
##  - a "ChomuPost" CanvasLayer: LUT colour grade, sharpen, vignette, grain, (PC) chromatic aberration + lens flare
## The renderer itself (Forward+ / Mobile / Compatibility) can only change with a restart - set it from the
## editor button or project settings. Features the running renderer can't draw are switched off, not faked.

const Presets = preload("res://addons/chomu_ultra/presets.gd")
const DeviceTier = preload("res://addons/chomu_ultra/device_tier.gd")
const PostLayer = preload("res://addons/chomu_ultra/post/chomu_post_layer.gd")
const GovernorScript = preload("res://addons/chomu_ultra/governor.gd")

const AUTO := "Auto"

static var current_preset := ""
static var last_report := {}

static func presets() -> Array[String]:
	return Presets.ORDER.duplicate()

static func detect() -> Dictionary:
	return DeviceTier.detect()

## "Auto" -> preset picked from the device tier; unknown names fall back to "Medium".
static func resolve(preset: String) -> String:
	if preset == AUTO or preset == "":
		return str(DeviceTier.detect().preset)
	if not Presets.ORDER.has(preset):
		push_warning("CHoMU Ultra: unknown preset '%s', using Medium." % preset)
		return "Medium"
	return preset

## Applies a preset to the running game. `scope` = node whose scene/viewport is changed (default: current scene).
## `options`: {"gi": "sdfgi"|"voxelgi"|"none", "upscaler": "taa"|"fsr2", "tonemapper": "ACES"|"AgX",
##             "post": true|false, "max_fps": int, "create_environment": true|false}
## Returns a report Dictionary (what was applied / skipped and why).
static func apply(preset: String = AUTO, scope: Node = null, options: Dictionary = {}) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var p := resolve(preset)
	var renderer := RenderingServer.get_current_rendering_method()
	var tonemapper := str(options.get("tonemapper", ProjectSettings.get_setting(Presets.TONEMAPPER, "")))
	var report := {"requested": preset, "preset": p, "renderer": renderer, "applied": [], "skipped": []}
	var root: Node = scope
	if root == null and tree != null:
		root = tree.current_scene if tree.current_scene != null else tree.root
	var vp: Viewport = null
	if root != null and root.is_inside_tree():
		vp = root.get_viewport()
	elif tree != null:
		vp = tree.root
	# 1. Viewport
	if vp != null:
		var v := Presets.viewport_for(p, renderer)
		if p == "PC Cinematic" and str(options.get("upscaler", "taa")) == "fsr2":
			v.merge(Presets.fsr2_override(renderer), true)
		for k in v:
			_set_safe(vp, k, v[k], report, "viewport")
	# 2. RenderingServer quality
	_apply_render_server(Presets.render_for(p), renderer, report)
	# 3. Scene: environment, sun, post
	if root != null:
		var env_d := Presets.env_for(p, renderer, tonemapper)
		var gi := str(options.get("gi", "sdfgi"))
		if gi != "sdfgi":
			env_d["sdfgi_enabled"] = false
		_apply_environment(root, env_d, Presets.sky_radiance_for(p), bool(options.get("create_environment", true)), report)
		_apply_voxel_gi(root, gi == "voxelgi" and renderer == "forward_plus", report)
		var sun := find_first(root, "DirectionalLight3D") as DirectionalLight3D
		if sun != null:
			var sd := Presets.sun_for(p, renderer)
			for k in sd:
				_set_safe(sun, k, sd[k], report, "sun")
		else:
			report.skipped.append("sun: no DirectionalLight3D in scene")
		var post := Presets.post_for(p)
		if options.has("post") and not bool(options.post):
			post["enabled"] = false
		_apply_post(root, post, report)
	# 4. Engine
	var eng := Presets.engine_for(p)
	if options.has("max_fps"):
		eng["max_fps"] = int(options.max_fps)
	if eng.has("max_fps") and not Engine.is_editor_hint():
		Engine.max_fps = int(eng.max_fps)
		report.applied.append("engine.max_fps=%d" % Engine.max_fps)
	current_preset = p
	last_report = report
	print("CHoMU Ultra: applied %s (renderer %s, %d changes, %d skipped)" % [p, renderer, report.applied.size(), report.skipped.size()])
	return report

## Adds (once) the adaptive-resolution governor under the scene tree root.
static func enable_adaptive(target_fps := 60.0, min_scale := 0.6) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var g := tree.root.get_node_or_null("ChomuUltraGovernor")
	if g == null:
		g = GovernorScript.new()
		g.name = "ChomuUltraGovernor"
		tree.root.add_child.call_deferred(g)
	g.set("target_fps", target_fps)
	g.set("min_scale", min_scale)
	return g

# ------------------------------------------------------------------------------------------- internals

static func _set_safe(obj: Object, prop: String, value: Variant, report: Dictionary, tag: String) -> void:
	if prop in obj:
		obj.set(prop, value)
		report.applied.append("%s.%s" % [tag, prop])
	else:
		report.skipped.append("%s.%s (not in this engine version)" % [tag, prop])

static func _apply_render_server(r: Dictionary, renderer: String, report: Dictionary) -> void:
	if r.is_empty():
		return
	RenderingServer.directional_shadow_atlas_set_size(int(r.dir_shadow_size), bool(r.dir_shadow_16))
	RenderingServer.directional_soft_shadow_filter_set_quality(int(r.soft_dir))
	RenderingServer.positional_soft_shadow_filter_set_quality(int(r.soft_pos))
	report.applied.append("rs.shadows")
	if renderer != "forward_plus":
		report.skipped.append("rs.ssao/ssil/ssr/sdfgi/volumetric (renderer %s)" % renderer)
		return
	RenderingServer.environment_glow_set_use_bicubic_upscale(bool(r.get("glow_bicubic", false)))
	if r.has("ssao_q"):
		RenderingServer.environment_set_ssao_quality(int(r.ssao_q), bool(r.ssao_half), 0.5, 2, 50.0, 300.0)
	if r.has("ssil_q"):
		RenderingServer.environment_set_ssil_quality(int(r.ssil_q), bool(r.ssil_half), 0.5, 4, 50.0, 300.0)
	if r.has("ssr_q"):
		RenderingServer.environment_set_ssr_roughness_quality(int(r.ssr_q))
	if r.has("vol_size"):
		RenderingServer.environment_set_volumetric_fog_volume_size(int(r.vol_size), int(r.vol_depth))
		RenderingServer.environment_set_volumetric_fog_filter_active(bool(r.vol_filter))
	if r.has("sdfgi_rays"):
		RenderingServer.environment_set_sdfgi_ray_count(int(r.sdfgi_rays))
		RenderingServer.environment_set_sdfgi_frames_to_converge(int(r.sdfgi_converge))
	if r.has("gi_half"):
		RenderingServer.gi_set_use_half_resolution(bool(r.gi_half))
	if r.get("roughness_limiter", false):
		RenderingServer.screen_space_roughness_limiter_set_active(true, 0.25, 0.18)
	report.applied.append("rs.forward_plus_quality")

static func find_first(n: Node, cls: String) -> Node:
	if n == null:
		return null
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := find_first(c, cls)
		if f != null:
			return f
	return null

static func find_all(n: Node, cls: String, out: Array = []) -> Array:
	if n == null:
		return out
	if n.is_class(cls):
		out.append(n)
	for c in n.get_children():
		find_all(c, cls, out)
	return out

static func make_default_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	return env

static func _apply_environment(root: Node, e: Dictionary, radiance: int, create: bool, report: Dictionary) -> void:
	var we := find_first(root, "WorldEnvironment") as WorldEnvironment
	if we == null:
		var cam := root.get_viewport().get_camera_3d() if root.is_inside_tree() and root.get_viewport() else null
		if cam != null and cam.environment != null:
			_apply_env_values(cam.environment, e, radiance, report)
			return
		if not create:
			report.skipped.append("environment: no WorldEnvironment")
			return
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		root.add_child(we)
		report.applied.append("environment.created")
	if we.environment == null:
		we.environment = make_default_environment()
	_apply_env_values(we.environment, e, radiance, report)

static func _apply_env_values(env: Environment, e: Dictionary, radiance: int, report: Dictionary) -> void:
	for k in e:
		_set_safe(env, k, e[k], report, "env")
	if env.sky != null:
		env.sky.radiance_size = radiance as Sky.RadianceSize

static func _apply_voxel_gi(root: Node, on: bool, report: Dictionary) -> void:
	var vgis := find_all(root, "VoxelGI")
	if on and vgis.is_empty():
		report.skipped.append("voxelgi requested but no VoxelGI node in scene (add one and bake it)")
	for v in vgis:
		(v as VoxelGI).visible = on

static func _apply_post(root: Node, post: Dictionary, report: Dictionary) -> void:
	var layer := root.get_node_or_null("ChomuPost")
	if layer == null:
		for c in root.get_children():
			if c.get_script() == PostLayer:
				layer = c
				break
	if layer == null:
		if not bool(post.get("enabled", false)):
			return
		layer = PostLayer.new()
		layer.name = "ChomuPost"
		root.add_child(layer)
		report.applied.append("post.created")
	layer.call("configure", post)
	report.applied.append("post.%s" % ("on" if post.get("enabled", false) else "off"))
