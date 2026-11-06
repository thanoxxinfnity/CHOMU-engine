@tool
extends EditorPlugin
## CHoMU Graphics (CHoMU Engine 1.3) - one-tap graphics presets for the whole project.
## Opens from the editor toolbar ("Graphics"), Project > Tools > "CHoMU Graphics...", or by picking a preset in
## Project Settings > CHoMU > Graphics > Preset. A preset sets the renderer, anti-aliasing (TAA / FSR2 / MSAA /
## FXAA), 3D resolution scaling, shadow quality, SSAO / SSIL / SSR / SDFGI / volumetric-fog quality, AgX tone
## mapping and glow, and adds or updates the WorldEnvironment of the open scene.
## Special Grade presets also apply the matching Special Grade look (Realistic or Anime).

const SETTING_PRESET := "chomu/graphics/preset"
const SETTING_PHONES := "chomu/graphics/phones_use_mobile_renderer"
const SETTING_SCENE := "chomu/graphics/update_open_scene"
const BACKUP := "res://chomu/graphics/previous_settings.cfg"

var _btn: Button
var _dlg: AcceptDialog
var _status: Label
var _restart_btn: Button
var _undo_btn: Button
var _scene_chk: CheckBox
var _phones_chk: CheckBox
var _cards := {}
var _last_preset := ""
var _busy := false
var _looks  # chomu_looks.gd instance

# ============================================================================================ presets

static func order() -> PackedStringArray:
	return PackedStringArray(["Special Grade Realistic", "Special Grade Anime", "Ultra", "High", "Balanced", "Mobile"])

static func info() -> Dictionary:
	return {
		"Special Grade Realistic": {
			"tag": "Photoreal, everything maxed", "badge": "SPECIAL GRADE", "renderer": "forward_plus",
			"desc": "SDFGI + SSIL + SSR + volumetric fog, ultra SSAO, 8K soft shadows, TAA + 4x MSAA at native resolution, AgX. For PC and flagship phones.",
			"look": "Special Grade Realistic", "colors": [Color("ff5a36"), Color("ff2e88")],
		},
		"Special Grade Anime": {
			"tag": "Top-tier anime (cel + outlines)", "badge": "SPECIAL GRADE", "renderer": "forward_plus",
			"desc": "Max render quality plus the Special Grade Anime look: cel shading, ink outlines, rim light, punchy bloom, saturated contrast.",
			"look": "Special Grade Anime", "colors": [Color("4f7cff"), Color("b23cff")],
		},
		"Ultra": {
			"tag": "Very high quality", "badge": "", "renderer": "forward_plus",
			"desc": "SDFGI, SSIL, SSR, volumetric fog, high SSAO, 4K soft shadows, TAA + 2x MSAA, AgX + glow.",
			"look": "", "colors": [Color("ffb02e"), Color("ff5a36")],
		},
		"High": {
			"tag": "Great quality, faster", "badge": "", "renderer": "forward_plus",
			"desc": "SSAO + SSR, glow, AgX, FSR 2 upscaling (Quality, 77%) for temporal AA, 4K shadows. No SDFGI / SSIL / volumetric fog.",
			"look": "", "colors": [Color("3ddc97"), Color("2bb3c0")],
		},
		"Balanced": {
			"tag": "Mid-range phones & laptops", "badge": "", "renderer": "mobile",
			"desc": "Mobile renderer (Vulkan), 2x MSAA, FSR 1 at 85%, 2K soft shadows, glow, AgX. Screen-space effects off.",
			"look": "", "colors": [Color("8f97ad"), Color("5b6480")],
		},
		"Mobile": {
			"tag": "Safe for low-end phones", "badge": "", "renderer": "gl_compatibility",
			"desc": "Compatibility renderer (OpenGL ES 3 - runs on almost every phone), FXAA, 80% resolution, small hard shadows, no glow or screen-space effects, AgX.",
			"look": "", "colors": [Color("6b7280"), Color("374151")],
		},
	}

## Project settings written by each preset.
static func settings_for(preset: String, phones_mobile: bool) -> Dictionary:
	var s := {
		"rendering/textures/vram_compression/import_etc2_astc": true,  # Android/iOS texture formats
		"rendering/anti_aliasing/quality/screen_space_aa": 0,
		"rendering/anti_aliasing/quality/use_debanding": false,
		"rendering/scaling_3d/mode": 0,
		"rendering/scaling_3d/scale": 1.0,
		"rendering/scaling_3d/fsr_sharpness": 0.2,
	}
	match preset:
		"Special Grade Realistic", "Special Grade Anime":
			s.merge({
				"rendering/renderer/rendering_method": "forward_plus",
				"rendering/renderer/rendering_method.mobile": "mobile" if phones_mobile else "forward_plus",
				"rendering/anti_aliasing/quality/msaa_3d": 2,
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
				"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality.mobile": 2,
				"rendering/environment/ssao/quality": 4,
				"rendering/environment/ssao/half_size": false,
				"rendering/environment/ssil/quality": 4,
				"rendering/environment/ssil/half_size": false,
				"rendering/environment/screen_space_reflection/half_size": false,
				"rendering/environment/volumetric_fog/volume_size": 128,
				"rendering/environment/volumetric_fog/volume_depth": 128,
				"rendering/environment/volumetric_fog/use_filter": 1,
				"rendering/environment/glow/upscale_mode": 1,
				"rendering/global_illumination/gi/use_half_resolution": false,
				"rendering/global_illumination/sdfgi/probe_ray_count": 5,
				"rendering/global_illumination/sdfgi/frames_to_converge": 3,
				"rendering/global_illumination/sdfgi/frames_to_update_lights": 1,
				"rendering/reflections/sky_reflections/ggx_samples": 64,
				"rendering/reflections/sky_reflections/ggx_samples.mobile": 16,
				"rendering/reflections/reflection_atlas/reflection_size": 512,
				"rendering/reflections/specular_occlusion/enabled": true,
				"rendering/textures/default_filters/anisotropic_filtering_level": 4,
			}, true)
		"Ultra":
			s.merge({
				"rendering/renderer/rendering_method": "forward_plus",
				"rendering/renderer/rendering_method.mobile": "mobile" if phones_mobile else "forward_plus",
				"rendering/anti_aliasing/quality/msaa_3d": 1,
				"rendering/anti_aliasing/quality/use_taa": true,
				"rendering/anti_aliasing/quality/use_debanding": true,
				"rendering/lights_and_shadows/directional_shadow/size": 4096,
				"rendering/lights_and_shadows/directional_shadow/size.mobile": 2048,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality": 4,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile": 2,
				"rendering/lights_and_shadows/directional_shadow/16_bits": true,
				"rendering/lights_and_shadows/positional_shadow/atlas_size": 4096,
				"rendering/lights_and_shadows/positional_shadow/atlas_size.mobile": 2048,
				"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality": 4,
				"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality.mobile": 2,
				"rendering/environment/ssao/quality": 3,
				"rendering/environment/ssao/half_size": false,
				"rendering/environment/ssil/quality": 2,
				"rendering/environment/ssil/half_size": true,
				"rendering/environment/screen_space_reflection/half_size": false,
				"rendering/environment/volumetric_fog/volume_size": 64,
				"rendering/environment/volumetric_fog/volume_depth": 64,
				"rendering/environment/volumetric_fog/use_filter": 1,
				"rendering/environment/glow/upscale_mode": 1,
				"rendering/global_illumination/gi/use_half_resolution": false,
				"rendering/global_illumination/sdfgi/probe_ray_count": 3,
				"rendering/global_illumination/sdfgi/frames_to_converge": 2,
				"rendering/global_illumination/sdfgi/frames_to_update_lights": 2,
				"rendering/reflections/sky_reflections/ggx_samples": 32,
				"rendering/reflections/sky_reflections/ggx_samples.mobile": 16,
				"rendering/reflections/reflection_atlas/reflection_size": 256,
				"rendering/reflections/specular_occlusion/enabled": true,
				"rendering/textures/default_filters/anisotropic_filtering_level": 4,
			}, true)
		"High":
			s.merge({
				"rendering/renderer/rendering_method": "forward_plus",
				"rendering/renderer/rendering_method.mobile": "mobile" if phones_mobile else "forward_plus",
				"rendering/anti_aliasing/quality/msaa_3d": 0,
				"rendering/anti_aliasing/quality/use_taa": false,  # FSR 2 does its own temporal AA
				"rendering/scaling_3d/mode": 2,
				"rendering/scaling_3d/scale": 0.77,
				"rendering/lights_and_shadows/directional_shadow/size": 4096,
				"rendering/lights_and_shadows/directional_shadow/size.mobile": 2048,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality": 3,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile": 1,
				"rendering/lights_and_shadows/directional_shadow/16_bits": true,
				"rendering/lights_and_shadows/positional_shadow/atlas_size": 4096,
				"rendering/lights_and_shadows/positional_shadow/atlas_size.mobile": 2048,
				"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality": 3,
				"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality.mobile": 1,
				"rendering/environment/ssao/quality": 2,
				"rendering/environment/ssao/half_size": true,
				"rendering/environment/ssil/quality": 1,
				"rendering/environment/ssil/half_size": true,
				"rendering/environment/screen_space_reflection/half_size": true,
				"rendering/environment/volumetric_fog/volume_size": 64,
				"rendering/environment/volumetric_fog/volume_depth": 64,
				"rendering/environment/glow/upscale_mode": 1,
				"rendering/global_illumination/gi/use_half_resolution": true,
				"rendering/global_illumination/sdfgi/probe_ray_count": 1,
				"rendering/reflections/sky_reflections/ggx_samples": 32,
				"rendering/reflections/sky_reflections/ggx_samples.mobile": 16,
				"rendering/reflections/reflection_atlas/reflection_size": 256,
				"rendering/textures/default_filters/anisotropic_filtering_level": 3,
			}, true)
		"Balanced":
			s.merge({
				"rendering/renderer/rendering_method": "mobile",
				"rendering/renderer/rendering_method.mobile": "mobile",
				"rendering/anti_aliasing/quality/msaa_3d": 1,  # MSAA is cheap on tile-based phone GPUs
				"rendering/anti_aliasing/quality/use_taa": false,
				"rendering/scaling_3d/mode": 1,
				"rendering/scaling_3d/scale": 0.85,
				"rendering/lights_and_shadows/directional_shadow/size": 2048,
				"rendering/lights_and_shadows/directional_shadow/size.mobile": 2048,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality": 2,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile": 2,
				"rendering/lights_and_shadows/directional_shadow/16_bits": true,
				"rendering/lights_and_shadows/positional_shadow/atlas_size": 2048,
				"rendering/lights_and_shadows/positional_shadow/atlas_size.mobile": 2048,
				"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality": 2,
				"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality.mobile": 2,
				"rendering/environment/glow/upscale_mode": 0,
				"rendering/environment/glow/upscale_mode.mobile": 0,
				"rendering/reflections/sky_reflections/ggx_samples": 16,
				"rendering/reflections/sky_reflections/ggx_samples.mobile": 16,
				"rendering/reflections/sky_reflections/texture_array_reflections.mobile": false,
				"rendering/reflections/reflection_atlas/reflection_size": 128,
				"rendering/reflections/reflection_atlas/reflection_size.mobile": 128,
				"rendering/textures/default_filters/anisotropic_filtering_level": 2,
			}, true)
		"Mobile":
			s.merge({
				"rendering/renderer/rendering_method": "gl_compatibility",
				"rendering/renderer/rendering_method.mobile": "gl_compatibility",
				"rendering/anti_aliasing/quality/msaa_3d": 0,
				"rendering/anti_aliasing/quality/use_taa": false,
				"rendering/anti_aliasing/quality/screen_space_aa": 1,  # FXAA: one cheap pass
				"rendering/scaling_3d/mode": 0,
				"rendering/scaling_3d/scale": 0.8,
				"rendering/lights_and_shadows/directional_shadow/size": 1024,
				"rendering/lights_and_shadows/directional_shadow/size.mobile": 1024,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality": 0,
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile": 0,
				"rendering/lights_and_shadows/directional_shadow/16_bits": true,
				"rendering/lights_and_shadows/positional_shadow/atlas_size": 1024,
				"rendering/lights_and_shadows/positional_shadow/atlas_size.mobile": 1024,
				"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality": 0,
				"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality.mobile": 0,
				"rendering/reflections/sky_reflections/ggx_samples": 16,
				"rendering/reflections/sky_reflections/ggx_samples.mobile": 16,
				"rendering/reflections/sky_reflections/texture_array_reflections": false,
				"rendering/reflections/sky_reflections/texture_array_reflections.mobile": false,
				"rendering/reflections/reflection_atlas/reflection_size": 128,
				"rendering/reflections/reflection_atlas/reflection_size.mobile": 128,
				"rendering/textures/default_filters/anisotropic_filtering_level": 1,
				"rendering/occlusion_culling/use_occlusion_culling": false,
			}, true)
	return s

## Environment values each preset writes into the open scene's WorldEnvironment (sky is kept).
static func env_for(preset: String) -> Dictionary:
	var off := {"sdfgi_enabled": false, "ssil_enabled": false, "ssr_enabled": false, "ssao_enabled": false,
		"volumetric_fog_enabled": false}
	var e := {"tonemap_mode": Environment.TONE_MAPPER_AGX, "tonemap_white": 16.0}
	match preset:
		"Ultra":
			e.merge({"sdfgi_enabled": true, "sdfgi_use_occlusion": true, "sdfgi_read_sky_light": true, "sdfgi_cascades": 4,
				"ssil_enabled": true, "ssil_radius": 5.0, "ssil_intensity": 1.0,
				"ssao_enabled": true, "ssao_radius": 1.2, "ssao_intensity": 1.8,
				"ssr_enabled": true, "ssr_max_steps": 64,
				"volumetric_fog_enabled": true, "volumetric_fog_density": 0.01, "volumetric_fog_anisotropy": 0.6,
				"glow_enabled": true, "glow_intensity": 0.6, "glow_bloom": 0.05, "glow_blend_mode": Environment.GLOW_BLEND_MODE_SOFTLIGHT}, true)
		"High":
			e.merge(off, true)
			e.merge({"ssao_enabled": true, "ssao_radius": 1.0, "ssao_intensity": 1.6, "ssr_enabled": true, "ssr_max_steps": 48,
				"glow_enabled": true, "glow_intensity": 0.5, "glow_bloom": 0.04, "glow_blend_mode": Environment.GLOW_BLEND_MODE_SOFTLIGHT}, true)
		"Balanced":
			e.merge(off, true)
			e.merge({"glow_enabled": true, "glow_intensity": 0.4, "glow_bloom": 0.03, "glow_blend_mode": Environment.GLOW_BLEND_MODE_SOFTLIGHT}, true)
		"Mobile":
			e.merge(off, true)
			e.merge({"glow_enabled": false, "tonemap_white": 6.0}, true)
	return e

# ============================================================================================ plugin

func _enter_tree() -> void:
	_looks = load(get_script().resource_path.get_base_dir().path_join("chomu_looks.gd")).new()
	_looks.plugin = self
	_looks.host = EditorInterface.get_base_control()
	_register_settings()
	_btn = Button.new()
	_btn.text = "Graphics"
	_btn.tooltip_text = "CHoMU Graphics: one-tap quality presets (Special Grade, Ultra, High, Balanced, Mobile)"
	_btn.flat = true
	var th := EditorInterface.get_editor_theme()
	if th and th.has_icon("Environment", "EditorIcons"):
		_btn.icon = th.get_icon("Environment", "EditorIcons")
	_btn.pressed.connect(open_dialog)
	add_control_to_container(CONTAINER_TOOLBAR, _btn)
	add_tool_menu_item("CHoMU Graphics...", open_dialog)
	_last_preset = str(ProjectSettings.get_setting(SETTING_PRESET, "Custom"))
	ProjectSettings.settings_changed.connect(_on_settings_changed)

func _exit_tree() -> void:
	if ProjectSettings.settings_changed.is_connected(_on_settings_changed):
		ProjectSettings.settings_changed.disconnect(_on_settings_changed)
	remove_tool_menu_item("CHoMU Graphics...")
	if is_instance_valid(_btn):
		remove_control_from_container(CONTAINER_TOOLBAR, _btn)
		_btn.queue_free()
	if is_instance_valid(_dlg):
		_dlg.queue_free()

func _register_settings() -> void:
	var defs := [
		[SETTING_PRESET, TYPE_STRING, PROPERTY_HINT_ENUM, "Custom," + ",".join(order()), "Custom"],
		[SETTING_PHONES, TYPE_BOOL, PROPERTY_HINT_NONE, "", true],
		[SETTING_SCENE, TYPE_BOOL, PROPERTY_HINT_NONE, "", true],
	]
	for d in defs:
		if not ProjectSettings.has_setting(d[0]):
			ProjectSettings.set_setting(d[0], d[4])
		ProjectSettings.set_initial_value(d[0], d[4])
		ProjectSettings.add_property_info({"name": d[0], "type": d[1], "hint": d[2], "hint_string": d[3]})
		ProjectSettings.set_as_basic(d[0], true)

func _on_settings_changed() -> void:
	if _busy:
		return
	var p := str(ProjectSettings.get_setting(SETTING_PRESET, "Custom"))
	if p == _last_preset:
		return
	_last_preset = p
	if p in order():
		# Picked in Project Settings > CHoMU > Graphics: apply it (deferred - we are inside the settings dialog).
		apply_preset.call_deferred(p)

# ============================================================================================ apply

func apply_preset(preset: String) -> void:
	if _busy or not info().has(preset):
		return
	_busy = true
	var phones := bool(ProjectSettings.get_setting(SETTING_PHONES, true))
	var update_scene := bool(ProjectSettings.get_setting(SETTING_SCENE, true))
	var old_renderer := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	var s := settings_for(preset, phones)
	# Back up the values we are about to change (for "Undo last preset").
	var bk := ConfigFile.new()
	for k in s:
		bk.set_value("settings", k.replace("/", "|"), ProjectSettings.get_setting(k) if ProjectSettings.has_setting(k) else null)
	bk.set_value("meta", "preset", _last_applied_name())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP.get_base_dir()))
	bk.save(BACKUP)
	for k in s:
		ProjectSettings.set_setting(k, s[k])
	ProjectSettings.set_setting(SETTING_PRESET, preset)
	_last_preset = preset
	var err := ProjectSettings.save()
	var msg := "%s preset saved to project settings%s." % [preset, "" if err == OK else " (save failed: %d)" % err]
	var scene_msg := ""
	if update_scene and EditorInterface.get_edited_scene_root() != null:
		var look := str(info()[preset].get("look", ""))
		if look != "":
			_set_status("Applying the %s look to the open scene..." % look)
			scene_msg = await _looks.apply(look, false)
		else:
			scene_msg = _apply_env(preset)
	elif update_scene:
		scene_msg = "Open a 3D scene and apply again to add a WorldEnvironment."
	var new_renderer := str(s.get("rendering/renderer/rendering_method", old_renderer))
	var need_restart := new_renderer != old_renderer
	if need_restart:
		msg += " Renderer changed to %s - restart the editor to see it." % _renderer_name(new_renderer)
	_set_status(msg + ("\n" + scene_msg if scene_msg != "" else ""))
	if is_instance_valid(_restart_btn):
		_restart_btn.visible = need_restart or _restart_btn.visible
	if is_instance_valid(_undo_btn):
		_undo_btn.disabled = false
	_highlight(preset)
	_busy = false

func _last_applied_name() -> String:
	return str(ProjectSettings.get_setting(SETTING_PRESET, "Custom"))

func undo_last_preset() -> void:
	var bk := ConfigFile.new()
	if bk.load(BACKUP) != OK:
		_set_status("Nothing to undo.")
		return
	_busy = true
	for key in bk.get_section_keys("settings"):
		var k := key.replace("|", "/")
		var v = bk.get_value("settings", key)
		if v == null:
			ProjectSettings.clear(k)
		else:
			ProjectSettings.set_setting(k, v)
	var prev := str(bk.get_value("meta", "preset", "Custom"))
	ProjectSettings.set_setting(SETTING_PRESET, prev)
	_last_preset = prev
	ProjectSettings.save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))
	_busy = false
	_highlight(prev)
	if is_instance_valid(_undo_btn):
		_undo_btn.disabled = true
	_set_status("Project settings restored (%s). Scene changes can be undone with Ctrl+Z / the Undo button." % prev)

static func _find_first(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := _find_first(c, cls)
		if f:
			return f
	return null

## Adds / updates the WorldEnvironment (and sun shadows) of the open scene for a non-Special-Grade preset.
func _apply_env(preset: String) -> String:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return ""
	var e := env_for(preset)
	var ur := get_undo_redo()
	ur.create_action("CHoMU Graphics: %s" % preset, UndoRedo.MERGE_DISABLE, root)
	var we := _find_first(root, "WorldEnvironment") as WorldEnvironment
	var created := false
	if we and we.environment:
		var env := we.environment
		for k in e:
			ur.add_do_property(env, k, e[k])
			ur.add_undo_property(env, k, env.get(k))
		if env.sky:
			var rs := Sky.RADIANCE_SIZE_32 if preset == "Mobile" else (Sky.RADIANCE_SIZE_64 if preset == "Balanced" else Sky.RADIANCE_SIZE_256)
			ur.add_do_property(env.sky, "radiance_size", rs)
			ur.add_undo_property(env.sky, "radiance_size", env.sky.radiance_size)
	else:
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var proc := ProceduralSkyMaterial.new()
		sky.sky_material = proc
		sky.radiance_size = Sky.RADIANCE_SIZE_32 if preset == "Mobile" else (Sky.RADIANCE_SIZE_64 if preset == "Balanced" else Sky.RADIANCE_SIZE_256)
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		for k in e:
			env.set(k, e[k])
		if we:
			ur.add_do_property(we, "environment", env)
			ur.add_undo_property(we, "environment", null)
		else:
			we = WorldEnvironment.new()
			we.name = "WorldEnvironment"
			we.environment = env
			ur.add_do_method(root, "add_child", we, true)
			ur.add_do_method(we, "set_owner", root)
			ur.add_do_reference(we)
			ur.add_undo_method(root, "remove_child", we)
			created = true
	var sun := _find_first(root, "DirectionalLight3D") as DirectionalLight3D
	if sun:
		var sp: Dictionary = {
			"Ultra": {"directional_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "directional_shadow_max_distance": 200.0, "light_angular_distance": 0.5},
			"High": {"directional_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "directional_shadow_max_distance": 150.0, "light_angular_distance": 0.0},
			"Balanced": {"directional_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "directional_shadow_max_distance": 80.0, "light_angular_distance": 0.0},
			"Mobile": {"directional_shadow_mode": DirectionalLight3D.SHADOW_ORTHOGONAL, "directional_shadow_max_distance": 50.0, "light_angular_distance": 0.0},
		}.get(preset, {})
		for k in sp:
			ur.add_do_property(sun, k, sp[k])
			ur.add_undo_property(sun, k, sun.get(k))
	ur.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	return "WorldEnvironment %s for %s (AgX%s)." % ["added" if created else "updated", preset,
		", glow" if e.get("glow_enabled", true) else ""]

static func _renderer_name(m: String) -> String:
	return {"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "Compatibility"}.get(m, m)

# ============================================================================================ dialog

const BG := Color("0f1117")
const PANEL := Color("161a24")
const CARD := Color("1b2030")
const CARD_HOVER := Color("232a3f")
const LINE := Color("2a3146")
const TEXT := Color("eef0f6")
const MUTED := Color("8f97ad")
const ACCENT := Color("ff5a36")
const ACCENT2 := Color("ff2e88")

var _s := 1.0

func _px(v: float) -> int:
	return int(round(v * _s))

func _box(bg: Color, radius := 12.0, border := Color(0, 0, 0, 0), bw := 0.0, pad_x := 12.0, pad_y := 8.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(_px(radius))
	b.border_color = border
	b.set_border_width_all(int(round(bw * _s)) if bw > 0.0 else 0)
	b.content_margin_left = _px(pad_x)
	b.content_margin_right = _px(pad_x)
	b.content_margin_top = _px(pad_y)
	b.content_margin_bottom = _px(pad_y)
	b.anti_aliasing = true
	return b

func _label(text: String, size := 15.0, col := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _px(size))
	l.add_theme_color_override("font_color", col)
	var th := EditorInterface.get_editor_theme()
	if th and th.has_font("bold" if bold else "main", "EditorFonts"):
		l.add_theme_font_override("font", th.get_font("bold" if bold else "main", "EditorFonts"))
	return l

func _style_button(b: Button, primary: bool, c1 := ACCENT) -> void:
	var base := c1 if primary else CARD
	b.add_theme_stylebox_override("normal", _box(base, 12.0, base if primary else LINE, 1.0, 16.0, 10.0))
	b.add_theme_stylebox_override("hover", _box(base.lightened(0.12) if primary else CARD_HOVER, 12.0, base if primary else LINE, 1.0, 16.0, 10.0))
	b.add_theme_stylebox_override("pressed", _box(base.darkened(0.25), 12.0, base, 1.0, 16.0, 10.0))
	b.add_theme_stylebox_override("disabled", _box(CARD.darkened(0.3), 12.0, LINE, 1.0, 16.0, 10.0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color.WHITE if primary else TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", _px(15))
	b.custom_minimum_size.y = _px(44)
	b.focus_mode = Control.FOCUS_NONE

func _chip(text: String, col: Color) -> Label:
	var l := _label(text, 11, col, true)
	l.add_theme_stylebox_override("normal", _box(Color(col.r, col.g, col.b, 0.16), 99.0, Color(col.r, col.g, col.b, 0.6), 1.0, 8.0, 2.0))
	return l

func _gradient_tex(c1: Color, c2: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 1)
	t.width = 64
	t.height = 64
	return t

func open_dialog() -> void:
	if not is_instance_valid(_dlg):
		_build_dialog()
	_highlight(str(ProjectSettings.get_setting(SETTING_PRESET, "Custom")))
	_scene_chk.set_pressed_no_signal(bool(ProjectSettings.get_setting(SETTING_SCENE, true)))
	_phones_chk.set_pressed_no_signal(bool(ProjectSettings.get_setting(SETTING_PHONES, true)))
	_undo_btn.disabled = not FileAccess.file_exists(BACKUP)
	var vp := EditorInterface.get_base_control().get_viewport_rect().size
	var want := Vector2(min(vp.x * 0.94, _px(1180)), min(vp.y * 0.92, _px(820)))
	_dlg.popup_centered(Vector2i(want))

func _build_dialog() -> void:
	_s = EditorInterface.get_editor_scale()
	_dlg = AcceptDialog.new()
	_dlg.title = "CHoMU Graphics"
	_dlg.ok_button_text = "Close"
	_dlg.add_theme_stylebox_override("panel", _box(BG, 0.0, Color(0, 0, 0, 0), 0.0, 16.0, 14.0))
	EditorInterface.get_base_control().add_child(_dlg)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", _px(12))
	_dlg.add_child(root)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", _px(12))
	root.add_child(head)
	var tb := VBoxContainer.new()
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.add_theme_constant_override("separation", 0)
	head.add_child(tb)
	tb.add_child(_label("Graphics presets", 22, TEXT, true))
	var sub := _label("One tap sets the renderer, anti-aliasing, shadows, GI, reflections, fog and tone mapping for the whole project.", 13, MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = _px(420)
	tb.add_child(sub)
	var cur := _chip("Running: " + _renderer_name(RenderingServer.get_current_rendering_method()), Color("3ddc97"))
	cur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cur)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.y = _px(300)
	root.add_child(sc)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", _px(12))
	grid.add_theme_constant_override("v_separation", _px(12))
	sc.add_child(grid)
	for name in order():
		grid.add_child(_make_card(name))

	var opts := HFlowContainer.new()
	opts.add_theme_constant_override("h_separation", _px(18))
	root.add_child(opts)
	_scene_chk = CheckBox.new()
	_scene_chk.text = "Add / update the WorldEnvironment in the open scene"
	_scene_chk.add_theme_font_size_override("font_size", _px(14))
	_scene_chk.toggled.connect(func(on): ProjectSettings.set_setting(SETTING_SCENE, on))
	opts.add_child(_scene_chk)
	_phones_chk = CheckBox.new()
	_phones_chk.text = "Phones fall back to the Mobile renderer (recommended)"
	_phones_chk.tooltip_text = "Special Grade / Ultra / High use Forward+ on PC. With this on, Android/iOS builds use the Mobile renderer\n(SDFGI, SSIL, SSR and volumetric fog are skipped there automatically). Turn off only for flagship-only games."
	_phones_chk.add_theme_font_size_override("font_size", _px(14))
	_phones_chk.toggled.connect(func(on): ProjectSettings.set_setting(SETTING_PHONES, on))
	opts.add_child(_phones_chk)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", _px(10))
	root.add_child(foot)
	_status = _label("Tip: also in Project Settings > Chomu > Graphics (preset picker).", 13, MUTED)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(_px(520), _px(40))
	foot.add_child(_status)
	_undo_btn = Button.new()
	_undo_btn.text = "Undo last preset"
	_style_button(_undo_btn, false)
	_undo_btn.pressed.connect(undo_last_preset)
	foot.add_child(_undo_btn)
	_restart_btn = Button.new()
	_restart_btn.text = "Restart editor"
	_style_button(_restart_btn, true)
	_restart_btn.pressed.connect(func(): EditorInterface.restart_editor(true))
	_restart_btn.hide()
	foot.add_child(_restart_btn)

func _make_card(name: String) -> Control:
	var d: Dictionary = info()[name]
	var cols: Array = d.colors
	var special: bool = d.badge != ""
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(_px(340), _px(200))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _box(CARD, 16.0, cols[0] if special else LINE, 2.0 if special else 1.0, 14.0, 12.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _px(6))
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", _px(10))
	v.add_child(top)
	var sw := TextureRect.new()
	sw.texture = _gradient_tex(cols[0], cols[1])
	sw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sw.custom_minimum_size = Vector2(_px(40), _px(40))
	top.add_child(sw)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	tv.add_child(_label(name, 18, TEXT, true))
	tv.add_child(_label(str(d.tag), 13, cols[0].lightened(0.25) if special else MUTED, special))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", _px(6))
	chips.add_theme_constant_override("v_separation", _px(4))
	v.add_child(chips)
	if special:
		chips.add_child(_chip(str(d.badge), cols[0].lightened(0.2)))
	chips.add_child(_chip(_renderer_name(str(d.renderer)), Color("8fb3ff")))
	if str(d.renderer) == "forward_plus":
		chips.add_child(_chip("Phones: Mobile fallback", Color("ffc24b")))
	if name == "Mobile":
		chips.add_child(_chip("Low-end safe", Color("3ddc97")))
	var desc := _label(str(d.desc), 13, MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var b := Button.new()
	b.text = "Apply " + name
	_style_button(b, true, cols[0] if special else ACCENT)
	b.pressed.connect(func():
		apply_preset(name))
	v.add_child(b)
	_cards[name] = {"panel": card, "button": b, "special": special, "color": cols[0]}
	return card

func _highlight(preset: String) -> void:
	for n in _cards:
		var c: Dictionary = _cards[n]
		var on: bool = n == preset
		var col: Color = c.color
		(c.panel as PanelContainer).add_theme_stylebox_override("panel", _box(CARD_HOVER if on else CARD, 16.0,
			Color.WHITE if on else (col if c.special else LINE), 3.0 if on else (2.0 if c.special else 1.0), 14.0, 12.0))
		(c.button as Button).text = ("✓ Active - apply again" if on else "Apply " + n)

func _set_status(t: String) -> void:
	if is_instance_valid(_status):
		_status.text = t
	print("CHoMU Graphics: ", t)
