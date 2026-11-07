@tool
extends ColorRect
## Drives shaders/lens_flare.gdshader: projects the sun (first DirectionalLight3D, or `sun_path`) onto the
## screen each frame and fades the flare when the sun is behind the camera or off-screen.
## No occlusion test (terrain/buildings in front of the sun do NOT hide it) - add a raycast if you need that.

@export var sun_path: NodePath
@export var intensity := 0.6

var _sun: DirectionalLight3D
var _search_cd := 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	var m := material as ShaderMaterial
	if m == null:
		return
	if not is_instance_valid(_sun):
		_search_cd -= delta
		if _search_cd > 0.0:
			return
		_search_cd = 1.0
		if not sun_path.is_empty():
			_sun = get_node_or_null(sun_path) as DirectionalLight3D
		if _sun == null:
			_sun = _find_sun(get_tree().current_scene if get_tree() else null)
		if _sun == null:
			m.set_shader_parameter("intensity", 0.0)
			return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		m.set_shader_parameter("intensity", 0.0)
		return
	# Light shines along -Z, so the sun sits along +Z of the light's basis.
	var sun_pos := cam.global_position + _sun.global_transform.basis.z.normalized() * 1000.0
	if cam.is_position_behind(sun_pos):
		m.set_shader_parameter("intensity", 0.0)
		return
	var vs := get_viewport().get_visible_rect().size
	var sp := cam.unproject_position(sun_pos) / vs
	var edge := clampf(1.0 - maxf(absf(sp.x - 0.5), absf(sp.y - 0.5)) * 1.6, 0.0, 1.0)
	m.set_shader_parameter("sun_screen", sp)
	m.set_shader_parameter("aspect", vs.x / maxf(vs.y, 1.0))
	m.set_shader_parameter("intensity", intensity * edge * clampf(_sun.light_energy, 0.0, 2.0))
	m.set_shader_parameter("flare_color", _sun.light_color)

func _find_sun(n: Node) -> DirectionalLight3D:
	if n == null:
		return null
	if n is DirectionalLight3D:
		return n
	for c in n.get_children():
		var f := _find_sun(c)
		if f != null:
			return f
	return null
