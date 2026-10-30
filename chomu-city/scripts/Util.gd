class_name Util
extends RefCounted
## Shared helpers: model loading, AABB measuring, mesh extraction, UI theme.

static var _cache := {}

static func load_scene(path: String) -> PackedScene:
	if _cache.has(path):
		return _cache[path]
	var ps: PackedScene = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = ps
	return ps

## Prefer a user-dropped model in res://assets/custom/<name>.glb over the default.
static func pick_model(custom_name: String, default_path: String) -> String:
	var custom := "res://assets/custom/%s.glb" % custom_name
	if ResourceLoader.exists(custom):
		return custom
	return default_path

static func instance_model(path: String) -> Node3D:
	var ps := load_scene(path)
	if ps == null:
		var fallback := MeshInstance3D.new()
		fallback.mesh = BoxMesh.new()
		return fallback
	return ps.instantiate() as Node3D

## AABB of all MeshInstance3D below root, in root's local space.
static func local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while stack.size() > 0:
		var item = stack.pop_back()
		var n: Node = item[0]
		var xf: Transform3D = item[1]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var ab: AABB = xf * (n as MeshInstance3D).mesh.get_aabb()
			if first:
				result = ab
				first = false
			else:
				result = result.merge(ab)
		for c in n.get_children():
			if c is Node3D:
				stack.append([c, xf * (c as Node3D).transform])
			else:
				stack.append([c, xf])
	return result

## Returns the first Mesh found below root (used for MultiMesh instancing).
static func first_mesh(root: Node) -> Mesh:
	if root is MeshInstance3D and root.mesh:
		return root.mesh
	for c in root.get_children():
		var m := first_mesh(c)
		if m:
			return m
	return null

static func set_visibility_range(root: Node, end_dist: float, cast_shadows := true) -> void:
	if root is GeometryInstance3D:
		var g := root as GeometryInstance3D
		g.visibility_range_end = end_dist
		g.visibility_range_end_margin = end_dist * 0.08
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if not cast_shadows:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in root.get_children():
		set_visibility_range(c, end_dist, cast_shadows)

static func find_anim_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for c in root.get_children():
		var a := find_anim_player(c)
		if a:
			return a
	return null

static func set_loop(ap: AnimationPlayer, names: Array) -> void:
	for n in names:
		if ap.has_animation(n):
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR

static func load_audio(path: String, loop := false) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if loop:
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		elif s is AudioStreamWAV:
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return s

# ---------------- UI ----------------
const ACCENT := Color(1.0, 0.72, 0.18)
const BG := Color(0.07, 0.08, 0.1, 0.92)

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.13, 0.16, 0.92)
	normal.set_corner_radius_all(14)
	normal.set_content_margin_all(14)
	normal.border_color = Color(1, 1, 1, 0.08)
	normal.set_border_width_all(2)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.2, 0.21, 0.25, 0.95)
	hover.border_color = ACCENT
	var pressed := normal.duplicate()
	pressed.bg_color = ACCENT
	pressed.border_color = ACCENT
	for type in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("focus", type, hover)
		t.set_color("font_color", type, Color(0.95, 0.95, 0.97))
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color(0.08, 0.08, 0.1))
	var panel := StyleBoxFlat.new()
	panel.bg_color = BG
	panel.set_corner_radius_all(22)
	panel.set_content_margin_all(28)
	panel.border_color = Color(1, 1, 1, 0.06)
	panel.set_border_width_all(2)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(1, 1, 1, 0.1)
	bar_bg.set_corner_radius_all(8)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = ACCENT
	bar_fg.set_corner_radius_all(8)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	t.set_color("font_color", "Label", Color(0.93, 0.94, 0.96))
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(1, 1, 1, 0.15)
	slider.set_corner_radius_all(6)
	slider.content_margin_top = 6
	slider.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", slider)
	var grab := StyleBoxFlat.new()
	grab.bg_color = ACCENT
	grab.set_corner_radius_all(6)
	grab.content_margin_top = 6
	grab.content_margin_bottom = 6
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	return t

static func label(text: String, size := 26, color := Color(0.93, 0.94, 0.96)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func button(text: String, min_w := 320.0, h := 72.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, h)
	b.focus_mode = Control.FOCUS_NONE
	return b
