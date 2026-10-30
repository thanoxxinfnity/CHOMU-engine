extends Node
## Day-night cycle + environment / graphics presets.
## Owns WorldEnvironment, sun + moon DirectionalLights, HDRI sky shader, fog, glow.

@export var day_length_sec := 480.0    # real seconds per in-game 24 h
@export var start_hour := 16.5
var hour := 16.5
var time_scale := 1.0                  # multiplier (demo speeds this up)

var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var probe: ReflectionProbe
var city: Node

func _ready() -> void:
	hour = start_hour
	Game.day_night = self
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("hdri", load("res://assets/textures/sky.hdr"))
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.68, 0.78)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.5
	sun.light_angular_distance = 0.5
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.shadow_enabled = false
	add_child(moon)

	probe = ReflectionProbe.new()
	probe.size = Vector3(420, 80, 420)
	probe.position = Vector3(0, 30, 0)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.box_projection = false
	probe.max_distance = 300.0
	probe.intensity = 0.6
	add_child(probe)

	Game.quality_changed.connect(apply_quality)
	apply_quality(Game.quality)
	_update(0.0)

func _process(delta: float) -> void:
	_update(delta)

func _update(delta: float) -> void:
	hour = fmod(hour + delta * 24.0 / day_length_sec * time_scale, 24.0)
	# sun elevation: 0 at 6:00 and 18:00, max at 12:00
	var a := (hour - 6.0) / 12.0 * PI
	var elev := sin(a)                       # -1..1
	var sun_dir := Vector3(cos(a), sin(a), 0.35).normalized()   # direction TO the sun
	_point_light(sun, sun_dir)
	_point_light(moon, Vector3(-sun_dir.x, absf(sun_dir.y) * 0.8 + 0.25, -0.3).normalized())

	var day := smoothstep(-0.12, 0.18, elev)
	var sunset := clampf(1.0 - absf(elev) / 0.35, 0.0, 1.0) * smoothstep(-0.2, 0.0, elev)
	sun.visible = elev > -0.08
	sun.light_energy = clampf(elev * 3.0, 0.0, 1.0) * 1.35
	sun.light_color = Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.55, 0.3), sunset)
	moon.visible = day < 0.6
	moon.light_energy = (1.0 - day) * 0.22

	sky_mat.set_shader_parameter("day", day)
	sky_mat.set_shader_parameter("sunset", sunset)
	sky_mat.set_shader_parameter("hdri_energy", lerpf(0.3, 1.0, day))
	env.ambient_light_energy = lerpf(0.25, 1.0, day)
	env.fog_light_color = Color(0.04, 0.05, 0.09).lerp(Color(0.66, 0.72, 0.82), day).lerp(Color(0.9, 0.6, 0.45), sunset * 0.6)
	env.tonemap_exposure = lerpf(1.35, 1.0, day)
	env.glow_intensity = lerpf(1.1, 0.55, day)
	var night := 1.0 - smoothstep(-0.05, 0.12, elev)
	if city:
		city.set_night(night)

func _point_light(l: DirectionalLight3D, dir_to_light: Vector3) -> void:
	# a DirectionalLight shines along its -Z
	var target := -dir_to_light
	var up := Vector3.UP if absf(target.y) < 0.99 else Vector3.FORWARD
	l.global_transform = Transform3D(Basis.looking_at(target, up), Vector3.ZERO)

func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "%02d:%02d" % [h, m]

func is_night() -> bool:
	return hour < 6.3 or hour > 18.4

# ---------------------------------------------------------------- graphics presets
func apply_quality(q: int) -> void:
	var vp := get_viewport()
	var fp := Game.is_forward_plus()
	match q:
		0: # Low
			vp.scaling_3d_scale = 0.6
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			sun.shadow_enabled = false
			env.glow_enabled = false
			env.fog_density = 0.008
			probe.visible = false
			vp.mesh_lod_threshold = 4.0
		1: # Medium
			vp.scaling_3d_scale = 0.8
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 60.0
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			env.glow_enabled = true
			env.fog_density = 0.005
			probe.visible = false
			vp.mesh_lod_threshold = 2.0
		2: # High
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 100.0
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			env.glow_enabled = true
			env.fog_density = 0.0038
			probe.visible = true
			vp.mesh_lod_threshold = 1.0
		3: # Ultra
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = 160.0
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			env.glow_enabled = true
			env.fog_density = 0.0032
			probe.visible = true
			vp.mesh_lod_threshold = 0.5
	# Forward+-only effects (ignored by the Mobile renderer, used on desktop builds)
	env.ssao_enabled = fp and q >= 2
	env.ssil_enabled = fp and q >= 3
	env.sdfgi_enabled = fp and q >= 3
	env.volumetric_fog_enabled = fp and q >= 2
	env.volumetric_fog_density = 0.01
	env.ssr_enabled = fp and q >= 3
	var cam := vp.get_camera_3d()
	if cam:
		cam.far = [260.0, 340.0, 460.0, 600.0][q]
