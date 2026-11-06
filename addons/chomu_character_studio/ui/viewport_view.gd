@tool
extends SubViewportContainer
## The studio's own 3D view. It renders the edited scene's World3D through its own orbit camera,
## and draws edit overlays (preview mesh, wire, points, bones) as RenderingServer instances,
## so nothing is ever added to the user's scene tree.

const TH = preload("res://addons/chomu_character_studio/ui/studio_theme.gd")

var vp: SubViewport
var cam: Camera3D
var hud: Control
var controller: Object  # receives vp_event(event, view) -> bool

var target := Vector3(0, 1, 0)
var yaw := 0.5
var pitch := -0.25
var dist := 3.5
var _nav := ""
var _last := Vector2.ZERO

var hud_title := ""
var hud_hint := ""
var brush_px := 0.0
var mouse_pos := Vector2.ZERO
var box_rect := Rect2()

var _inst := {}   # name -> [instance_rid, mesh]
var _fallback_world: World3D

func _init() -> void:
	stretch = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp = SubViewport.new()
	vp.name = "StudioViewport"
	vp.msaa_3d = Viewport.MSAA_2X
	vp.handle_input_locally = false
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(vp)
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.near = 0.02
	cam.far = 500.0
	vp.add_child(cam)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	add_child(hud)
	_update_cam()

func _exit_tree() -> void:
	clear_all()

func set_world(w: World3D) -> void:
	if w == null:
		if _fallback_world == null:
			_fallback_world = World3D.new()
			var env = Environment.new()
			env.background_mode = Environment.BG_COLOR
			env.background_color = TH.BG
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.6, 0.65, 0.7)
			_fallback_world.environment = env
		w = _fallback_world
	if vp.world_3d != w:
		clear_all()
		vp.world_3d = w

func scenario() -> RID:
	return vp.world_3d.scenario if vp.world_3d else RID()

# ------------------------------------------------------------- camera

func _update_cam() -> void:
	pitch = clampf(pitch, -1.5, 1.5)
	dist = clampf(dist, 0.05, 200.0)
	var b = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	cam.transform = Transform3D(b, target + b * Vector3(0, 0, dist))
	if hud:
		hud.queue_redraw()

func frame_aabb(box: AABB) -> void:
	if box.size == Vector3.ZERO:
		box = AABB(box.position - Vector3.ONE * 0.5, Vector3.ONE)
	target = box.get_center()
	var r = box.size.length() * 0.5
	dist = r / tan(deg_to_rad(cam.fov * 0.5)) * 1.05
	_update_cam()

func world_per_pixel(at: Vector3) -> float:
	var d = cam.global_transform.origin.distance_to(at)
	var h = maxf(1.0, float(vp.size.y))
	return 2.0 * d * tan(deg_to_rad(cam.fov * 0.5)) / h

func ray(pos: Vector2) -> Array:
	return [cam.project_ray_origin(pos), cam.project_ray_normal(pos)]

func project(p: Vector3) -> Vector2:
	return cam.unproject_position(p)

func behind(p: Vector3) -> bool:
	return cam.is_position_behind(p)

func view_dir() -> Vector3:
	return -cam.global_transform.basis.z

# ------------------------------------------------------------- input

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouse:
		mouse_pos = (e as InputEventMouse).position
		hud.queue_redraw()
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		grab_focus()
	# navigation first for MMB / RMB / wheel / Alt+LMB
	if e is InputEventMouseButton:
		var mb = e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			dist *= 0.9
			_update_cam()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			dist *= 1.1
			_update_cam()
			accept_event()
			return
		var nav_btn = mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and mb.alt_pressed)
		if mb.button_index == MOUSE_BUTTON_RIGHT and not _controller_wants_right():
			nav_btn = true
		if nav_btn:
			if mb.pressed:
				_nav = "pan" if mb.shift_pressed else "orbit"
				_last = mb.position
			else:
				_nav = ""
			accept_event()
			return
	if e is InputEventMouseMotion and _nav != "":
		var mm = e as InputEventMouseMotion
		var d = mm.position - _last
		_last = mm.position
		if _nav == "orbit":
			yaw -= d.x * 0.008
			pitch -= d.y * 0.008
		else:
			var wpp = world_per_pixel(target)
			target += (-cam.global_transform.basis.x * d.x + cam.global_transform.basis.y * d.y) * wpp
		_update_cam()
		accept_event()
		return
	if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_PERIOD and controller and controller.has_method("frame_target"):
		controller.frame_target()
		accept_event()
		return
	if controller and controller.has_method("vp_event"):
		if controller.vp_event(e, self):
			accept_event()

func _controller_wants_right() -> bool:
	return controller != null and controller.has_method("wants_right_click") and controller.wants_right_click()

# ------------------------------------------------------------- overlays

func set_overlay(name: String, mesh: Mesh, xform: Transform3D, material: Material = null) -> void:
	var sc = scenario()
	if not sc.is_valid():
		return
	var entry: Array = _inst.get(name, [])
	var rid: RID
	if entry.is_empty():
		rid = RenderingServer.instance_create()
		RenderingServer.instance_set_scenario(rid, sc)
		RenderingServer.instance_geometry_set_cast_shadows_setting(rid, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	else:
		rid = entry[0]
	if mesh == null:
		RenderingServer.instance_set_visible(rid, false)
		_inst[name] = [rid, null]
		return
	RenderingServer.instance_set_base(rid, mesh.get_rid())
	RenderingServer.instance_set_transform(rid, xform)
	RenderingServer.instance_set_visible(rid, true)
	if material:
		RenderingServer.instance_geometry_set_material_override(rid, material.get_rid())
	else:
		RenderingServer.instance_geometry_set_material_override(rid, RID())
	RenderingServer.instance_set_custom_aabb(rid, AABB(Vector3(-1e4, -1e4, -1e4), Vector3(2e4, 2e4, 2e4)))
	_inst[name] = [rid, mesh, material]  # keep refs alive

func hide_overlay(name: String) -> void:
	if _inst.has(name):
		RenderingServer.instance_set_visible(_inst[name][0], false)

func clear_all() -> void:
	for k in _inst:
		RenderingServer.free_rid(_inst[k][0])
	_inst.clear()

# ------------------------------------------------------------- HUD

func _draw_hud() -> void:
	var f = get_theme_default_font()
	if hud_title != "":
		var sb = TH.flat(Color(TH.PANEL.r, TH.PANEL.g, TH.PANEL.b, 0.86), 6, TH.LINE, 1, 4)
		var w = f.get_string_size(hud_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 22
		hud.draw_style_box(sb, Rect2(10, 10, w, 28))
		hud.draw_string(f, Vector2(21, 30), hud_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TH.ORANGE)
	if hud_hint != "":
		var y = hud.size.y - 14
		var lines = hud_hint.split("\n")
		for i in range(lines.size() - 1, -1, -1):
			hud.draw_string(f, Vector2(12, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(TH.TEXT, 0.85))
			y -= 18
	if brush_px > 0.0 and get_global_rect().has_point(get_global_mouse_position()):
		hud.draw_arc(mouse_pos, brush_px, 0, TAU, 48, TH.ORANGE, 1.6, true)
		hud.draw_arc(mouse_pos, brush_px * 0.5, 0, TAU, 32, Color(TH.ORANGE, 0.35), 1.0, true)
	if box_rect.size != Vector2.ZERO:
		hud.draw_rect(box_rect.abs(), Color(TH.BLUE, 0.12), true)
		hud.draw_rect(box_rect.abs(), TH.BLUE, false, 1.2)
	# axis gizmo
	var o = Vector2(hud.size.x - 46, hud.size.y - 46)
	var axes = [[Vector3.RIGHT, TH.ORANGE, "X"], [Vector3.UP, TH.TEAL, "Y"], [Vector3.BACK, TH.BLUE, "Z"]]
	var cb = cam.global_transform.basis.inverse()
	for a in axes:
		var v: Vector3 = cb * (a[0] as Vector3)
		var e = o + Vector2(v.x, -v.y) * 26.0
		hud.draw_line(o, e, a[1], 2.0, true)
		hud.draw_string(f, e + Vector2(-4, 5), a[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, a[1])
