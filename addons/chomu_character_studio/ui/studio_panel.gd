@tool
extends Control
## CHoMU Character Studio main screen: one tab for rigging, animation, cloth, hair, modelling,
## mesh editing, sculpting, weight painting, shape keys, posing, UVs, modifiers and materials.

const TH = preload("res://addons/chomu_character_studio/ui/studio_theme.gd")
const IC = preload("res://addons/chomu_character_studio/ui/icons.gd")
const VV = preload("res://addons/chomu_character_studio/ui/viewport_view.gd")
const SU = preload("res://addons/chomu_character_studio/core/scene_util.gd")
const HM = preload("res://addons/chomu_character_studio/core/humanoid_map.gd")
const RIG = preload("res://addons/chomu_character_studio/core/rig_tools.gd")
const ANIM = preload("res://addons/chomu_character_studio/core/anim_tools.gd")
const PHYS = preload("res://addons/chomu_character_studio/core/physics_tools.gd")
const MODEL = preload("res://addons/chomu_character_studio/core/model_tools.gd")
const MAT = preload("res://addons/chomu_character_studio/core/material_tools.gd")
const EM = preload("res://addons/chomu_character_studio/core/edit_mesh.gd")
const WIRE_SHADER = preload("res://addons/chomu_character_studio/shaders/overlay_wire.gdshader")
const CLAY_SHADER = preload("res://addons/chomu_character_studio/shaders/clay.gdshader")
const XRAY_SHADER = preload("res://addons/chomu_character_studio/shaders/overlay_xray.gdshader")
const POINTS_SHADER = preload("res://addons/chomu_character_studio/shaders/overlay_points.gdshader")
const XRAY_POINTS_SHADER = preload("res://addons/chomu_character_studio/shaders/overlay_xray_points.gdshader")

const MODES = [
	["rig", "Rig", "rig"], ["anim", "Animate", "anim"], ["pose", "Pose", "pose"],
	["cloth", "Cloth", "cloth"], ["hair", "Hair", "hair"], ["material", "Material", "material"],
	["model", "Model", "model"], ["edit", "Edit Mesh", "edit"], ["sculpt", "Sculpt", "sculpt"],
	["weights", "Weights", "weights"], ["shapes", "Shape Keys", "shapes"], ["uv", "UV", "uv"],
	["modifiers", "Modifiers", "modifiers"],
]
const MESH_MODES = ["edit", "sculpt", "weights", "shapes", "uv", "modifiers"]

var plugin: EditorPlugin
var ur: EditorUndoRedoManager

var mode = ""
var view
var props: VBoxContainer
var props_scroll: ScrollContainer
var status_lbl: Label
var target_lbl: Label
var stats_lbl: Label
var mode_btns = {}
var file_dialog: EditorFileDialog
var _file_cb: Callable

var target: Node
var mesh_node: MeshInstance3D
var em = null
var em_source: MeshInstance3D
var history = []
var redo_stack = []
var mod_stack = []
var modal = {}
var stroke = {}
var click = {}

var sculpt_brush = "draw"
var brush_radius = 0.08
var brush_strength = 0.5
var sym_x = true
var weight_bone = -1
var weight_mode = "add"
var pose_bone = -1
var xray = false
var extrude_dist = 0.05
var inset_t = 0.25
var merge_dist = 0.001
var cloth_preset = "Cotton"
var pin_band = 0.08
var hair_preset = "Soft hair"
var hair_colliders = true
var chain_count = 5
var chain_seg = 0.07
var csg_op = "Union"
var mat_surface = -1
var anim_lib_path = "res://demo/assets/anim/UAL1_Standard.glb"
var key_anim = "pose_take"
var key_time = 0.0

var mat_wire: ShaderMaterial
var mat_clay: ShaderMaterial
var mat_clay_vc: ShaderMaterial
var mat_points: ShaderMaterial
var mat_bones: ShaderMaterial
var mat_bonepts: ShaderMaterial
var _world_check = 0.0
var uv_canvas: Control

func setup(p: EditorPlugin) -> void:
	plugin = p
	ur = p.get_undo_redo()

func _ready() -> void:
	theme = TH.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mat_wire = ShaderMaterial.new()
	mat_wire.shader = WIRE_SHADER
	mat_wire.render_priority = 10
	mat_clay = ShaderMaterial.new()
	mat_clay.shader = CLAY_SHADER
	mat_clay_vc = ShaderMaterial.new()
	mat_clay_vc.shader = CLAY_SHADER
	mat_clay_vc.set_shader_parameter("use_vertex_color", true)
	mat_points = ShaderMaterial.new()
	mat_points.shader = POINTS_SHADER
	mat_points.render_priority = 11
	mat_bones = ShaderMaterial.new()
	mat_bones.shader = XRAY_SHADER
	mat_bones.render_priority = 20
	mat_bones.set_shader_parameter("pull", 0.0)
	mat_bonepts = ShaderMaterial.new()
	mat_bonepts.shader = XRAY_POINTS_SHADER
	mat_bonepts.render_priority = 21
	mat_bonepts.set_shader_parameter("pull", 0.0)
	mat_bonepts.set_shader_parameter("point_size", 9.0)
	_build_ui()
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	_on_selection_changed()
	_set_mode("rig")

func _exit_tree() -> void:
	_end_session_display()
	if view:
		view.clear_all()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_world_check -= delta
	if _world_check <= 0.0:
		_world_check = 0.5
		var w: World3D = null
		var r = SU.root()
		if r and r.is_inside_tree():
			w = r.get_viewport().find_world_3d()
		view.set_world(w)
		if target != null and not is_instance_valid(target):
			target = null
			_on_selection_changed()

# =============================================================== UI construction

func _build_ui() -> void:
	var bg = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", TH.flat(TH.BG, 0))
	add_child(bg)
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	# header
	var header = PanelContainer.new()
	header.add_theme_stylebox_override("panel", TH.flat(TH.PANEL, 0, TH.LINE, 0, 6))
	root.add_child(header)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	header.add_child(hb)
	var logo = TextureRect.new()
	logo.texture = IC.get_icon("studio", 26)
	logo.modulate = TH.ORANGE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	hb.add_child(logo)
	var t1 = Label.new()
	t1.text = "CHoMU"
	t1.add_theme_color_override("font_color", TH.ORANGE)
	t1.add_theme_font_size_override("font_size", 17)
	hb.add_child(t1)
	var t2 = Label.new()
	t2.text = "Character Studio"
	t2.add_theme_font_size_override("font_size", 17)
	hb.add_child(t2)
	var badge = Label.new()
	badge.text = " starter studio "
	badge.add_theme_color_override("font_color", TH.TEAL)
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_stylebox_override("normal", TH.flat(TH.PANEL3, 8, TH.TEAL.darkened(0.4), 1, 1))
	hb.add_child(badge)
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	target_lbl = Label.new()
	target_lbl.add_theme_color_override("font_color", TH.MUTED)
	target_lbl.text = "No target"
	hb.add_child(target_lbl)
	var ub = _btn("Use selection", "target", _use_selection, TH.BLUE)
	ub.size_flags_horizontal = Control.SIZE_SHRINK_END
	hb.add_child(ub)
	var fb = _btn("Frame", "frame", frame_target, TH.TEAL)
	fb.size_flags_horizontal = Control.SIZE_SHRINK_END
	hb.add_child(fb)
	# body
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)
	# mode rail
	var rail_bg = PanelContainer.new()
	rail_bg.add_theme_stylebox_override("panel", TH.flat(TH.PANEL, 0, TH.LINE, 0, 6))
	body.add_child(rail_bg)
	var rail_scroll = ScrollContainer.new()
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail_scroll.custom_minimum_size = Vector2(132, 0)
	rail_bg.add_child(rail_scroll)
	var rail = VBoxContainer.new()
	rail.add_theme_constant_override("separation", 3)
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_scroll.add_child(rail)
	var group = ButtonGroup.new()
	var section_after = {"pose": "PHYSICS & LOOK", "material": "MODELLING"}
	var cap = Label.new()
	cap.text = "CHARACTER"
	cap.add_theme_color_override("font_color", TH.MUTED)
	cap.add_theme_font_size_override("font_size", 11)
	rail.add_child(cap)
	for m in MODES:
		var b = Button.new()
		b.text = m[1]
		b.icon = IC.get_icon(m[2], 20)
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(120, 34)
		b.tooltip_text = m[1]
		b.add_theme_stylebox_override("normal", TH.flat(Color(0, 0, 0, 0), 6))
		b.add_theme_stylebox_override("pressed", TH.flat(TH.PANEL3, 6, _mode_color(m[0]), 1))
		b.add_theme_stylebox_override("hover_pressed", TH.flat(TH.PANEL3, 6, _mode_color(m[0]), 1))
		b.add_theme_color_override("icon_normal_color", _mode_color(m[0]).darkened(0.1))
		b.add_theme_color_override("icon_pressed_color", _mode_color(m[0]))
		b.add_theme_color_override("icon_hover_color", _mode_color(m[0]).lightened(0.2))
		b.pressed.connect(_set_mode.bind(m[0]))
		rail.add_child(b)
		mode_btns[m[0]] = b
		if section_after.has(m[0]):
			var c2 = Label.new()
			c2.text = section_after[m[0]]
			c2.add_theme_color_override("font_color", TH.MUTED)
			c2.add_theme_font_size_override("font_size", 11)
			rail.add_child(HSeparator.new())
			rail.add_child(c2)
	# viewport
	var center = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 0)
	body.add_child(center)
	view = VV.new()
	view.controller = self
	center.add_child(view)
	# properties
	var right = PanelContainer.new()
	right.add_theme_stylebox_override("panel", TH.flat(TH.PANEL, 0, TH.LINE, 0, 8))
	right.custom_minimum_size = Vector2(340, 0)
	body.add_child(right)
	props_scroll = ScrollContainer.new()
	props_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(props_scroll)
	props = VBoxContainer.new()
	props.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	props.add_theme_constant_override("separation", 6)
	props_scroll.add_child(props)
	# status bar
	var sb = PanelContainer.new()
	sb.add_theme_stylebox_override("panel", TH.flat(TH.PANEL, 0, TH.LINE, 0, 4))
	root.add_child(sb)
	var sbh = HBoxContainer.new()
	sb.add_child(sbh)
	status_lbl = Label.new()
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_lbl.clip_text = true
	status_lbl.text = "Ready."
	status_lbl.add_theme_color_override("font_color", TH.MUTED)
	sbh.add_child(status_lbl)
	stats_lbl = Label.new()
	stats_lbl.add_theme_color_override("font_color", TH.MUTED)
	sbh.add_child(stats_lbl)
	file_dialog = EditorFileDialog.new()
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.file_selected.connect(func(path):
		if _file_cb.is_valid():
			_file_cb.call(path))
	add_child(file_dialog)

func _mode_color(m: String) -> Color:
	if m in ["rig", "anim", "pose"]:
		return TH.BLUE
	if m in ["cloth", "hair", "material"]:
		return TH.TEAL
	return TH.ORANGE

func _btn(text: String, icon: String, cb: Callable, tint: Color = TH.TEXT, tip: String = "") -> Button:
	var b = Button.new()
	b.text = text
	if icon != "":
		b.icon = IC.get_icon(icon, 18)
		b.add_theme_color_override("icon_normal_color", tint)
		b.add_theme_color_override("icon_hover_color", tint.lightened(0.25))
		b.add_theme_color_override("icon_pressed_color", Color.WHITE)
	b.tooltip_text = tip if tip != "" else text
	b.pressed.connect(cb)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b

func _section(title: String, icon: String = "") -> VBoxContainer:
	var pc = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", TH.flat(TH.PANEL2, 8, TH.LINE, 1, 8))
	props.add_child(pc)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var h = HBoxContainer.new()
	v.add_child(h)
	if icon != "":
		var tr = TextureRect.new()
		tr.texture = IC.get_icon(icon, 16)
		tr.modulate = _mode_color(mode)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(tr)
	var l = Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color.WHITE)
	h.add_child(l)
	return v

func _note(parent: Control, text: String, color: Color = TH.MUTED) -> Label:
	var l = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 12)
	l.custom_minimum_size = Vector2(280, 0)
	parent.add_child(l)
	return l

func _grid(parent: Control, cols: int = 2) -> GridContainer:
	var g = GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	parent.add_child(g)
	return g

func _spin(parent: Control, label: String, minv: float, maxv: float, step: float, val: float, cb: Callable) -> SpinBox:
	var h = HBoxContainer.new()
	parent.add_child(h)
	var l = Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_color_override("font_color", TH.MUTED)
	h.add_child(l)
	var s = SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(cb)
	h.add_child(s)
	return s

func _slider(parent: Control, label: String, minv: float, maxv: float, step: float, val: float, cb: Callable) -> HSlider:
	var h = HBoxContainer.new()
	parent.add_child(h)
	var l = Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	l.add_theme_color_override("font_color", TH.MUTED)
	h.add_child(l)
	var s = HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var v = Label.new()
	v.custom_minimum_size = Vector2(44, 0)
	v.text = _fmt(val, step)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	s.value_changed.connect(func(x):
		v.text = _fmt(x, step)
		cb.call(x))
	return s

func _fmt(x: float, step: float) -> String:
	if step >= 1.0:
		return str(int(x))
	return "%.2f" % x

func _option(parent: Control, label: String, items: Array, current: String, cb: Callable) -> OptionButton:
	var h = HBoxContainer.new()
	parent.add_child(h)
	if label != "":
		var l = Label.new()
		l.text = label
		l.custom_minimum_size = Vector2(90, 0)
		l.add_theme_color_override("font_color", TH.MUTED)
		h.add_child(l)
	var o = OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		o.add_item(str(items[i]), i)
		if str(items[i]) == current:
			o.select(i)
	o.item_selected.connect(func(i): cb.call(str(items[i])))
	h.add_child(o)
	return o

func _check(parent: Control, label: String, val: bool, cb: Callable) -> CheckBox:
	var c = CheckBox.new()
	c.text = label
	c.button_pressed = val
	c.toggled.connect(cb)
	parent.add_child(c)
	return c

func _say(msg: String, color: Color = TH.TEXT) -> void:
	status_lbl.text = msg
	status_lbl.add_theme_color_override("font_color", color)
	print("[CHoMU Studio] ", msg)

func _warn(msg: String) -> void:
	_say(msg, TH.WARN)

func _pick_file(filters: PackedStringArray, cb: Callable) -> void:
	file_dialog.filters = filters
	_file_cb = cb
	file_dialog.popup_file_dialog()

# =============================================================== target / selection

func _on_selection_changed() -> void:
	if mode in MESH_MODES and em != null and is_instance_valid(em_source):
		_update_target_label()
		return
	var sel = SU.selected()
	var n: Node = sel[0] if not sel.is_empty() else SU.root()
	target = n
	mesh_node = null
	if n:
		var mi = SU.find_mesh(n)
		if n is MeshInstance3D:
			mi = n
		elif mi != null:
			mi = _largest_mesh(SU.character_of(n))
		mesh_node = mi
	_update_target_label()
	if mode != "" and not (mode in MESH_MODES):
		_rebuild_props()
	if mode == "pose":
		_refresh_pose_overlay()

func _largest_mesh(n: Node) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var bestc = -1
	for m in SU.find_all_of_type(n, "MeshInstance3D", []):
		if m is SoftBody3D or (m as MeshInstance3D).mesh == null:
			continue
		var c = 0
		var mm = (m as MeshInstance3D).mesh
		if mm is ArrayMesh:
			for s in mm.get_surface_count():
				c += (mm as ArrayMesh).surface_get_array_len(s)
		if c > bestc:
			bestc = c
			best = m
	return best

func _use_selection() -> void:
	_end_session_display()
	em = null
	em_source = null
	var m = mode
	mode = ""
	_on_selection_changed()
	_set_mode(m)

func _update_target_label() -> void:
	var t = "No target"
	if target and is_instance_valid(target):
		t = "Target: " + String(target.name)
	if mesh_node and is_instance_valid(mesh_node):
		t += "   Mesh: " + String(mesh_node.name)
	target_lbl.text = t

func frame_target() -> void:
	var n: Node = target if target and is_instance_valid(target) else SU.root()
	if mode in MESH_MODES and is_instance_valid(em_source) and em != null:
		var b = em.aabb()
		view.frame_aabb(em_source.global_transform * b)
		return
	var box = _global_aabb(SU.character_of(n) if n else null)
	view.frame_aabb(box)

func _global_aabb(n: Node) -> AABB:
	var out = AABB()
	var first = true
	if n == null:
		return AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	for vi in SU.find_all_of_type(n, "VisualInstance3D", []):
		if not (vi as VisualInstance3D).is_visible_in_tree():
			continue
		var b = (vi as VisualInstance3D).global_transform * (vi as VisualInstance3D).get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	if first:
		return AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	return out

# =============================================================== modes

func _set_mode(m: String) -> void:
	if modal.size() > 0:
		_modal_cancel()
	var was_mesh = mode in MESH_MODES
	mode = m
	if mode_btns.has(m):
		mode_btns[m].button_pressed = true
	if m in MESH_MODES:
		if not _ensure_session():
			_end_session_display()
	else:
		if was_mesh:
			_end_session_display()
	view.hide_overlay("bones")
	view.hide_overlay("bonepts")
	view.brush_px = 0.0
	_rebuild_props()
	_update_hud()
	if m == "pose":
		_refresh_pose_overlay()
	elif m in MESH_MODES and em != null:
		_refresh_overlay()

func _update_hud() -> void:
	var titles = {"rig": "Rig", "anim": "Animate", "pose": "Pose Mode", "cloth": "Cloth", "hair": "Hair",
		"material": "Material", "model": "Model", "edit": "Edit Mode", "sculpt": "Sculpt Mode",
		"weights": "Weight Paint", "shapes": "Shape Keys", "uv": "UV", "modifiers": "Modifiers"}
	view.hud_title = titles.get(mode, mode)
	var hints = {
		"edit": "LMB select (Shift add, drag = box)   1/2/3 vert/edge/face   G/R/S move/rotate/scale (X/Y/Z axis)\nE extrude   I inset   X delete   M merge   F make face   A all   Ctrl+Z undo   MMB/RMB orbit   Shift+MMB pan   wheel zoom",
		"sculpt": "LMB drag to sculpt   Ctrl = invert   [ / ] radius   1 draw  2 smooth  3 inflate  4 grab   MMB/RMB orbit",
		"weights": "LMB drag to paint the selected bone   Ctrl = subtract   [ / ] radius   MMB/RMB orbit",
		"pose": "LMB pick a joint   R rotate in view (X/Y/Z axis)   K key selected bone   MMB/RMB orbit",
		"shapes": "Sliders preview keys; 'Sculpt this key' edits a key in Sculpt Mode",
		"modifiers": "Non-destructive preview: mirror, array, Catmull-Clark subdivision",
	}
	view.hud_hint = hints.get(mode, "MMB/RMB orbit   Shift+MMB pan   wheel zoom   .  frame")
	view.hud.queue_redraw()

func _clear_props() -> void:
	for c in props.get_children():
		props.remove_child(c)
		c.queue_free()

func _rebuild_props() -> void:
	_clear_props()
	uv_canvas = null
	match mode:
		"rig":
			_props_rig()
		"anim":
			_props_anim()
		"pose":
			_props_pose()
		"cloth":
			_props_cloth()
		"hair":
			_props_hair()
		"material":
			_props_material()
		"model":
			_props_model()
		"edit":
			_props_edit()
		"sculpt":
			_props_sculpt()
		"weights":
			_props_weights()
		"shapes":
			_props_shapes()
		"uv":
			_props_uv()
		"modifiers":
			_props_modifiers()
	_update_stats()

func _skel() -> Skeleton3D:
	var n: Node = mesh_node if mesh_node and is_instance_valid(mesh_node) else target
	if n == null or not is_instance_valid(n):
		n = SU.root()
	return SU.find_skeleton(n)

# =============================================================== RIG

func _props_rig() -> void:
	var s = _section("Import model", "import")
	_note(s, "Brings a glTF / FBX / Blend / scene file from the project into the open scene.")
	s.add_child(_btn("Import model into scene…", "import", func():
		_pick_file(PackedStringArray(["*.glb, *.gltf ; glTF", "*.fbx ; FBX", "*.blend ; Blender", "*.tscn, *.scn ; Scene"]), func(path):
			var n = RIG.import_model(ur, path)
			if n:
				target = n
				_say("Imported %s." % path.get_file(), TH.OK)
				_rebuild_props()
				frame_target()), TH.BLUE))
	var skel = _skel()
	var s2 = _section("Humanoid BoneMap / retarget", "rig")
	if skel == null:
		_note(s2, "No Skeleton3D found on the target. Select a rigged character.", TH.WARN)
	else:
		var m = HM.map_skeleton(skel)
		var l = _note(s2, "%s: %d bones, %d / 56 SkeletonProfileHumanoid bones matched." % [skel.name, skel.get_bone_count(), m.size()], TH.TEXT)
		var g = _grid(s2, 2)
		for k in ["Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperArm", "LeftHand", "RightUpperLeg", "RightFoot", "LeftThumbMetacarpal"]:
			var a = Label.new()
			a.text = k
			a.add_theme_font_size_override("font_size", 12)
			a.add_theme_color_override("font_color", TH.MUTED)
			g.add_child(a)
			var b = Label.new()
			b.text = m.get(k, "—")
			b.add_theme_font_size_override("font_size", 12)
			b.add_theme_color_override("font_color", TH.TEAL if m.has(k) else TH.GREY)
			g.add_child(b)
		var src = _model_path_of(target)
		s2.add_child(_btn("Auto BoneMap + retarget on import", "rig", func():
			var p = _model_path_of(target)
			if p == "":
				_warn("The target is not an imported model instance (glb/gltf/fbx/blend).")
				return
			var r = RIG.setup_humanoid_import(p)
			_say(r.msg, TH.OK if r.ok else TH.WARN), TH.BLUE,
			"Writes retarget/bone_map into the model's .import and reimports (engine retarget pipeline)."))
		if src == "":
			_note(s2, "Import retarget needs the target to be an instance of a model file.")
		s2.add_child(_btn("Save BoneMap resource", "apply", func():
			_say("BoneMap saved: " + RIG.save_bone_map(skel), TH.OK), TH.TEAL))
		s2.add_child(_btn("Rename scene bones to Humanoid", "bone", func():
			var n = RIG.rename_to_humanoid(ur, skel)
			_say("Renamed %d bones to humanoid profile names (undoable)." % n, TH.OK)
			_rebuild_props(), TH.GREY))
	var s3 = _section("IK & look-at", "ik")
	_note(s3, "TwoBoneIK3D for both arms and legs (targets + poles as markers), LookAtModifier3D on the head.")
	s3.add_child(_btn("One-click IK (arms, legs, look-at)", "ik", func():
		var sk = _skel()
		if sk == null:
			_warn("No skeleton.")
			return
		_say(RIG.setup_ik(ur, sk), TH.OK), TH.BLUE))
	s3.add_child(_btn("Look-at only", "look", func():
		var sk = _skel()
		if sk == null:
			_warn("No skeleton.")
			return
		_say(RIG.setup_look_at(ur, sk), TH.OK), TH.TEAL))

func _model_path_of(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return ""
	var ch = SU.character_of(n)
	for c in [n, ch]:
		if c and c.scene_file_path != "":
			var ext = c.scene_file_path.get_extension().to_lower()
			if ext in ["glb", "gltf", "fbx", "blend", "obj", "dae"]:
				return c.scene_file_path
	return ""

# =============================================================== ANIMATE

func _props_anim() -> void:
	var ch = SU.character_of(target) if target else SU.root()
	var p: AnimationPlayer = SU.find_anim_player(target) if target else null
	var s = _section("AnimationPlayer", "anim")
	_note(s, ("Player: %s with %d animations." % [p.name, p.get_animation_list().size()]) if p else "No AnimationPlayer yet - one is created on demand.", TH.TEXT if p else TH.MUTED)
	s.add_child(_btn("Open AnimationPlayer for this character", "anim", func():
		var pl = ANIM.ensure_player(ur, ch)
		ANIM.open_player(pl)
		_say("Opened %s in the Animation panel." % pl.name, TH.OK), TH.BLUE))
	s.add_child(_btn("AnimationTree starter (idle / walk / run)", "modifiers", func():
		var pl = ANIM.ensure_player(ur, ch)
		_say(ANIM.make_locomotion_tree(ur, ch, pl), TH.OK), TH.BLUE))
	var s2 = _section("Retarget from a library", "import")
	_note(s2, "Copies a library's clips onto this character, matching bones through the humanoid map (rest-corrected rotations, hips position).")
	var le = LineEdit.new()
	le.text = anim_lib_path
	le.text_changed.connect(func(t): anim_lib_path = t)
	s2.add_child(le)
	var h = HBoxContainer.new()
	s2.add_child(h)
	h.add_child(_btn("Browse…", "import", func():
		_pick_file(PackedStringArray(["*.glb, *.gltf ; glTF", "*.fbx ; FBX", "*.tscn, *.scn ; Scene"]), func(path):
			anim_lib_path = path
			le.text = path), TH.GREY))
	h.add_child(_btn("Retarget", "rig", func():
		_say(ANIM.retarget_library(ur, ch, anim_lib_path), TH.OK)
		_rebuild_props(), TH.BLUE))
	if p:
		var s3 = _section("Preview a clip", "play")
		var list = ItemList.new()
		list.custom_minimum_size = Vector2(0, 160)
		for a in p.get_animation_list():
			list.add_item(a, IC.get_icon("play", 14))
		s3.add_child(list)
		var scrub = _slider(s3, "Time", 0.0, 1.0, 0.01, 0.0, func(x):
			var cur = p.assigned_animation
			if cur != "":
				p.seek(x * p.get_animation(cur).length, true))
		list.item_selected.connect(func(i):
			var an = list.get_item_text(i)
			p.assigned_animation = an
			p.seek(scrub.value * p.get_animation(an).length, true)
			_say("Previewing %s." % an))
	var s4 = _section("Record pose", "key")
	_note(s4, "Pose bones in Pose mode and key them into a clip at any time.")
	s4.add_child(_btn("Go to Pose mode", "pose", _set_mode.bind("pose"), TH.BLUE))

# =============================================================== POSE

func _props_pose() -> void:
	var skel = _skel()
	var s = _section("Pose mode", "pose")
	if skel == null:
		_note(s, "Select a rigged character (no Skeleton3D found).", TH.WARN)
		return
	_note(s, "%s - click a joint in the view or pick a bone below." % skel.name, TH.TEXT)
	var tree = Tree.new()
	tree.custom_minimum_size = Vector2(0, 220)
	tree.hide_root = true
	var troot = tree.create_item()
	var items = {}
	for i in skel.get_bone_count():
		var par = skel.get_bone_parent(i)
		var it = tree.create_item(items.get(par, troot))
		it.set_text(0, skel.get_bone_name(i))
		it.set_metadata(0, i)
		it.set_icon(0, IC.get_icon("bone", 14))
		it.set_icon_modulate(0, TH.BLUE)
		items[i] = it
		if i == pose_bone:
			it.select(0)
		it.collapsed = par >= 0 and skel.get_bone_parent(par) >= 2
	tree.item_selected.connect(func():
		var it = tree.get_selected()
		if it:
			pose_bone = int(it.get_metadata(0))
			_rebuild_pose_sliders()
			_refresh_pose_overlay())
	s.add_child(tree)
	var s2 = _section("Rotate bone", "rotate")
	s2.name = "PoseSliders"
	_fill_pose_sliders(s2, skel)
	var s3 = _section("Keyframes", "key")
	var le = LineEdit.new()
	le.text = key_anim
	le.placeholder_text = "animation (library/name)"
	le.text_changed.connect(func(t): key_anim = t)
	s3.add_child(le)
	_spin(s3, "Time (s)", 0.0, 600.0, 0.05, key_time, func(v): key_time = v)
	var g = _grid(s3, 2)
	g.add_child(_btn("Key bone", "key", func(): _key_pose(false), TH.ORANGE))
	g.add_child(_btn("Key posed bones", "key", func(): _key_pose(true), TH.ORANGE))
	g.add_child(_btn("Reset bone", "revert", func():
		if pose_bone >= 0:
			skel.reset_bone_pose(pose_bone)
			_rebuild_pose_sliders()
			_refresh_pose_overlay(), TH.GREY))
	g.add_child(_btn("Reset all", "revert", func():
		skel.reset_bone_poses()
		_rebuild_pose_sliders()
		_refresh_pose_overlay(), TH.GREY))
	s3.add_child(_btn("Open AnimationPlayer", "anim", func():
		var pl = ANIM.ensure_player(ur, SU.character_of(skel))
		ANIM.open_player(pl), TH.BLUE))

func _fill_pose_sliders(s2: Control, skel: Skeleton3D) -> void:
	if pose_bone < 0 or pose_bone >= skel.get_bone_count():
		_note(s2, "No bone selected.")
		return
	_note(s2, skel.get_bone_name(pose_bone), TH.ORANGE)
	var rest_q = skel.get_bone_rest(pose_bone).basis.get_rotation_quaternion()
	var rel = (rest_q.inverse() * skel.get_bone_pose_rotation(pose_bone)).get_euler()
	var axes = ["X", "Y", "Z"]
	for k in 3:
		_slider(s2, "Rot " + axes[k], -180.0, 180.0, 1.0, rad_to_deg(rel[k]), func(v):
			var rq = skel.get_bone_rest(pose_bone).basis.get_rotation_quaternion()
			var e = (rq.inverse() * skel.get_bone_pose_rotation(pose_bone)).get_euler()
			e[k] = deg_to_rad(v)
			skel.set_bone_pose_rotation(pose_bone, rq * Quaternion.from_euler(e))
			_refresh_pose_overlay())

func _rebuild_pose_sliders() -> void:
	var s2 = props.find_child("PoseSliders", true, false)
	var skel = _skel()
	if s2 == null or skel == null:
		return
	var kids = s2.get_children()
	for i in range(1, kids.size()):
		s2.remove_child(kids[i])
		kids[i].queue_free()
	_fill_pose_sliders(s2, skel)

func _key_pose(all_posed: bool) -> void:
	var skel = _skel()
	if skel == null:
		return
	var p = ANIM.ensure_player(ur, SU.character_of(skel))
	var bones = []
	if all_posed:
		for i in skel.get_bone_count():
			var rq = skel.get_bone_rest(i).basis.get_rotation_quaternion()
			if not skel.get_bone_pose_rotation(i).is_equal_approx(rq) or not skel.get_bone_pose_position(i).is_equal_approx(skel.get_bone_rest(i).origin):
				bones.append(i)
	elif pose_bone >= 0:
		bones.append(pose_bone)
	if bones.is_empty():
		_warn("No posed bones to key.")
		return
	_say(ANIM.key_pose(ur, p, skel, bones, key_anim, key_time), TH.OK)

func _refresh_pose_overlay() -> void:
	if mode != "pose":
		return
	var skel = _skel()
	if skel == null:
		view.hide_overlay("bones")
		view.hide_overlay("bonepts")
		return
	var lines = PackedVector3Array()
	var lcol = PackedColorArray()
	var pts = PackedVector3Array()
	var pcol = PackedColorArray()
	for i in skel.get_bone_count():
		var o = skel.get_bone_global_pose(i).origin
		var par = skel.get_bone_parent(i)
		var c = TH.ORANGE if i == pose_bone else Color(TH.BLUE, 0.95)
		if par >= 0:
			lines.append(skel.get_bone_global_pose(par).origin)
			lines.append(o)
			var cc = TH.ORANGE if par == pose_bone else Color(TH.TEAL, 0.9)
			lcol.append(cc)
			lcol.append(cc)
		pts.append(o)
		pcol.append(c)
	if lines.size() > 0:
		var am = ArrayMesh.new()
		var a = []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = lines
		a[Mesh.ARRAY_COLOR] = lcol
		am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, a)
		view.set_overlay("bones", am, skel.global_transform, mat_bones)
	var pm = ArrayMesh.new()
	var a2 = []
	a2.resize(Mesh.ARRAY_MAX)
	a2[Mesh.ARRAY_VERTEX] = pts
	a2[Mesh.ARRAY_COLOR] = pcol
	pm.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, a2)
	view.set_overlay("bonepts", pm, skel.global_transform, mat_bonepts)

func _pick_bone(pos: Vector2) -> int:
	var skel = _skel()
	if skel == null:
		return -1
	var best = -1
	var bd = 18.0
	for i in skel.get_bone_count():
		var g = skel.global_transform * skel.get_bone_global_pose(i).origin
		if view.behind(g):
			continue
		var d = view.project(g).distance_to(pos)
		if d < bd:
			bd = d
			best = i
	return best

# =============================================================== CLOTH

func _props_cloth() -> void:
	var s = _section("Cloth (SoftBody3D)", "cloth")
	_note(s, "Select a cape or skirt MeshInstance3D. The top band of vertices is pinned to the nearest chest/hips bone.")
	_option(s, "Preset", PHYS.CLOTH_PRESETS.keys(), cloth_preset, func(v): cloth_preset = v)
	_slider(s, "Pin band", 0.02, 0.4, 0.01, pin_band, func(v): pin_band = v)
	s.add_child(_btn("Make selected mesh cloth", "cloth", func():
		var mi = SU.first_selected("MeshInstance3D") as MeshInstance3D
		if mi == null:
			_warn("Select the cape/skirt MeshInstance3D first.")
			return
		_say(PHYS.add_cloth(ur, mi, cloth_preset, pin_band), TH.OK), TH.TEAL))
	s.add_child(_btn("Apply preset to selected SoftBody3D", "apply", func():
		var sb = SU.first_selected("SoftBody3D") as SoftBody3D
		if sb == null:
			_warn("Select a SoftBody3D.")
			return
		PHYS.apply_cloth_preset(ur, sb, cloth_preset)
		_say("Cloth preset %s applied." % cloth_preset, TH.OK), TH.GREY))
	var s2 = _section("Quick cape", "add")
	_note(s2, "Adds a subdivided cape mesh behind the upper chest so you can try cloth right away.")
	s2.add_child(_btn("Add demo cape", "add", _add_demo_cape, TH.TEAL))
	var g = _grid(s2, 3)
	for k in PHYS.CLOTH_PRESETS:
		var l = Label.new()
		var p: Dictionary = PHYS.CLOTH_PRESETS[k]
		l.text = "%s\nstiff %.2f\nmass %.1f" % [k, p.linear_stiffness, p.total_mass]
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", TH.MUTED)
		g.add_child(l)

func _add_demo_cape() -> void:
	var skel = _skel()
	var ch = SU.character_of(target) if target else SU.root()
	var pm = PlaneMesh.new()
	pm.size = Vector2(0.5, 0.95)
	pm.subdivide_width = 8
	pm.subdivide_depth = 14
	pm.orientation = PlaneMesh.FACE_Z
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, pm.get_mesh_arrays())
	var mat = MAT.make("Cloth", null)
	(mat as StandardMaterial3D).albedo_color = Color("#2c5aa0")
	(mat as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	am.surface_set_material(0, mat)
	var mi = MeshInstance3D.new()
	mi.name = SU.unique_name(ch, "Cape")
	mi.mesh = am
	var pos = Vector3(0, 1.0, -0.15)
	if skel:
		var bi = HM.find_bone(skel, "UpperChest")
		if bi < 0:
			bi = HM.find_bone(skel, "Chest")
		if bi >= 0:
			var g = skel.global_transform * skel.get_bone_global_pose(bi).origin
			var inv = (ch as Node3D).global_transform.affine_inverse() if ch is Node3D else Transform3D.IDENTITY
			pos = inv * (g + Vector3(0, -0.38, -0.16))
	mi.position = pos
	SU.add_node(ur, "CHoMU: Demo cape", ch, mi, true)
	_say("Cape added and selected - press 'Make selected mesh cloth'.", TH.OK)

# =============================================================== HAIR

func _props_hair() -> void:
	var skel = _skel()
	var s = _section("Hair / tail spring bones", "hair")
	if skel == null:
		_note(s, "No skeleton found.", TH.WARN)
		return
	var chains = PHYS.find_chains(skel)
	_note(s, ("Found %d chain(s): %s" % [chains.size(), ", ".join(chains.map(func(c): return c[0] + " → " + c[1]))]) if chains.size() > 0 else "No hair/tail bones yet (names with hair, tail, ponytail, braid…).", TH.TEXT if chains.size() > 0 else TH.MUTED)
	_option(s, "Preset", PHYS.HAIR_PRESETS.keys(), hair_preset, func(v): hair_preset = v)
	_check(s, "Collision capsules (head, neck, chest, arms)", hair_colliders, func(v): hair_colliders = v)
	s.add_child(_btn("Add SpringBoneSimulator3D", "hair", func():
		_say(PHYS.add_spring_bones(ur, skel, hair_preset, PHYS.find_chains(skel), hair_colliders), TH.OK), TH.TEAL))
	s.add_child(_btn("Apply preset to selected simulator", "apply", func():
		var sim = SU.first_selected("SpringBoneSimulator3D") as SpringBoneSimulator3D
		if sim == null:
			_warn("Select a SpringBoneSimulator3D.")
			return
		PHYS.apply_hair_preset(ur, sim, hair_preset)
		_say("Preset %s applied." % hair_preset, TH.OK), TH.GREY))
	var s2 = _section("Create a chain", "bone")
	_note(s2, "Adds a ponytail/tail bone chain under the head (or hips for a tail). On an imported skeleton, make the scene local to keep new bones.")
	_spin(s2, "Bones", 2, 12, 1, chain_count, func(v): chain_count = int(v))
	_spin(s2, "Segment (m)", 0.01, 0.5, 0.01, chain_seg, func(v): chain_seg = v)
	var g = _grid(s2, 2)
	g.add_child(_btn("Ponytail", "hair", func(): _make_chain("Head", "Hair_Ponytail", Vector3(0, -0.6, -0.8)), TH.TEAL))
	g.add_child(_btn("Tail", "hair", func(): _make_chain("Hips", "Tail", Vector3(0, -0.3, -1.0)), TH.TEAL))
	var g2 = _grid(s2, 4)
	for k in PHYS.HAIR_PRESETS:
		var p: Dictionary = PHYS.HAIR_PRESETS[k]
		var l = Label.new()
		l.text = "%s\nk %.1f g %.2f" % [k, p.stiffness, p.gravity]
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", TH.MUTED)
		g2.add_child(l)

func _make_chain(parent_profile: String, base: String, dir: Vector3) -> void:
	var skel = _skel()
	if skel == null:
		return
	var bi = HM.find_bone(skel, parent_profile)
	if bi < 0:
		_warn("No %s bone." % parent_profile)
		return
	var r = PHYS.create_chain(skel, skel.get_bone_name(bi), base, chain_count, chain_seg, dir)
	_say("Created chain %s (%d bones) under %s." % [r, chain_count, skel.get_bone_name(bi)], TH.OK)
	_rebuild_props()

# =============================================================== MATERIAL

func _props_material() -> void:
	var mi: GeometryInstance3D = mesh_node
	var sel = SU.first_selected("GeometryInstance3D")
	if sel:
		mi = sel
	var s = _section("Material presets", "material")
	if mi == null:
		_note(s, "Select a MeshInstance3D.", TH.WARN)
		return
	_note(s, "Target: %s. Keeps its albedo / normal / roughness textures." % mi.name, TH.TEXT)
	var items = ["All surfaces"]
	if mi is MeshInstance3D and (mi as MeshInstance3D).mesh:
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			var m = (mi as MeshInstance3D).get_active_material(i)
			items.append("Surface %d%s" % [i, (" - " + m.resource_name) if m and m.resource_name != "" else ""])
	_option(s, "Apply to", items, items[clampi(mat_surface + 1, 0, items.size() - 1)], func(v):
		mat_surface = items.find(v) - 1)
	var icons = {"Skin (realistic)": "material", "Hair (anisotropic)": "hair", "Cloth": "cloth", "Leather": "cloth", "Metal": "sphere", "Eyes (glossy)": "look", "Anime toon": "studio", "Anime toon + outline": "studio"}
	var g = _grid(s, 2)
	for p in MAT.PRESETS:
		var tint = TH.ORANGE if p.begins_with("Anime") else TH.TEAL
		g.add_child(_btn(p, icons.get(p, "material"), func(): _say(MAT.apply(ur, mi, p, mat_surface), TH.OK), tint))
	if str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "gl_compatibility":
		_note(s, "Compatibility renderer: subsurface scattering and anisotropy need Forward+ or Mobile; here they fall back to standard PBR.", TH.WARN)

# =============================================================== MODEL

func _props_model() -> void:
	var s = _section("CSG block-out", "model")
	_note(s, "Add primitives under a CSGCombiner3D and combine them with booleans, then bake to a mesh for Edit / Sculpt.")
	_option(s, "Operation", ["Union", "Subtract", "Intersect"], csg_op, func(v): csg_op = v)
	var g = _grid(s, 3)
	for k in [["Box", "model"], ["Sphere", "sphere"], ["Cylinder", "cylinder"], ["Cone", "cylinder"], ["Torus", "torus"]]:
		g.add_child(_btn(k[0], k[1], func(): _say(MODEL.add_csg(ur, k[0], csg_op), TH.OK), TH.ORANGE))
	s.add_child(_btn("Set operation on selected CSG", "merge", func(): _say(MODEL.set_operation(ur, csg_op), TH.OK), TH.GREY))
	s.add_child(_btn("Bake CSG to mesh → Edit Mode", "bake", func():
		var mi = MODEL.bake_csg(ur)
		if mi == null:
			_warn("Select a CSG node (or add one first).")
			return
		_say("Baked to %s." % mi.name, TH.OK)
		_take_mesh(mi, "edit"), TH.ORANGE))
	var s2 = _section("Editable mesh primitives", "edit")
	var g2 = _grid(s2, 2)
	for k in [["Cube", "model"], ["Sphere", "sphere"], ["Cylinder", "cylinder"], ["Plane", "plane"]]:
		g2.add_child(_btn(k[0], k[1], func():
			var mi = MODEL.add_mesh_primitive(ur, k[0])
			_take_mesh(mi, "edit")
			if em:
				em.tris_to_quads()
				_refresh_overlay(), TH.ORANGE))
	var s3 = _section("Level block-out add-on", "modifiers")
	var cyclops = DirAccess.dir_exists_absolute("res://addons/cyclops_level_builder")
	_note(s3, "Cyclops Level Builder (MIT, by Mark McKay) is %s." % ("installed in addons/cyclops_level_builder - enable it in Project Settings > Plugins" if cyclops else "not bundled in this build (see README)"), TH.TEXT if cyclops else TH.MUTED)

func _take_mesh(mi: MeshInstance3D, to_mode: String) -> void:
	_end_session_display()
	em = null
	em_source = null
	target = mi
	mesh_node = mi
	_update_target_label()
	_set_mode(to_mode)
	frame_target()

# =============================================================== MESH SESSION

func _ensure_session() -> bool:
	if mesh_node == null or not is_instance_valid(mesh_node) or mesh_node.mesh == null:
		_warn("Select a MeshInstance3D to edit.")
		return false
	if em == null or em_source != mesh_node:
		_end_session_display()
		em = EM.new()
		if not em.load_mesh(mesh_node.mesh):
			_warn("Could not read triangles from %s." % mesh_node.name)
			em = null
			return false
		em_source = mesh_node
		history.clear()
		redo_stack.clear()
		mod_stack.clear()
		weight_bone = -1
		_say("Editing %s: %d verts, %d faces%s." % [mesh_node.name, em.verts.size(), em.faces.size(), ", skinned" if em.has_skin else ""])
	_hide_source(true)
	return true

func _hide_source(h: bool) -> void:
	if em_source and is_instance_valid(em_source) and em_source.is_inside_tree():
		RenderingServer.instance_set_visible(em_source.get_instance(), (not h) and em_source.is_visible_in_tree())

func _end_session_display() -> void:
	_hide_source(false)
	if view:
		for k in ["mesh", "wire", "pts", "faces"]:
			view.hide_overlay(k)
		view.brush_px = 0.0

func _push_undo() -> void:
	if em == null:
		return
	history.append(em.snapshot())
	if history.size() > 40:
		history.pop_front()
	redo_stack.clear()

func _undo() -> void:
	if history.is_empty():
		_say("Nothing to undo.")
		return
	redo_stack.append(em.snapshot())
	em.restore(history.pop_back())
	_refresh_overlay()
	_say("Undo.")

func _redo() -> void:
	if redo_stack.is_empty():
		return
	history.append(em.snapshot())
	em.restore(redo_stack.pop_back())
	_refresh_overlay()
	_say("Redo.")

func _apply_to_scene() -> void:
	if em == null or not is_instance_valid(em_source):
		return
	var ev = em.evaluate(mod_stack)
	var am = ev.build_mesh()
	if am.get_surface_count() == 0:
		_warn("Mesh is empty - nothing applied.")
		return
	ur.create_action("CHoMU: Apply edited mesh", UndoRedo.MERGE_DISABLE, em_source)
	ur.add_do_property(em_source, "mesh", am)
	ur.add_undo_property(em_source, "mesh", em_source.mesh)
	if ev.has_skin and em_source.skin == null:
		var sk = SU.find_skeleton(em_source)
		if sk:
			var skin = sk.create_skin_from_rest_transforms()
			ur.add_do_property(em_source, "skin", skin)
			ur.add_undo_property(em_source, "skin", null)
			ur.add_do_property(em_source, "skeleton", em_source.get_path_to(sk))
			ur.add_undo_property(em_source, "skeleton", em_source.skeleton)
	ur.commit_action()
	_hide_source(true)
	_say("Applied to %s: %d verts, %d faces%s (Ctrl+Z in the editor to undo)." % [em_source.name, ev.verts.size(), ev.faces.size(), (", %d modifiers baked" % mod_stack.size()) if mod_stack.size() > 0 else ""], TH.OK)

func _revert_session() -> void:
	if em_source == null or not is_instance_valid(em_source):
		return
	em = null
	_ensure_session()
	_refresh_overlay()
	_say("Reloaded %s from the scene." % em_source.name)

func _session_buttons(parent: Control) -> void:
	var g = _grid(parent, 2)
	g.add_child(_btn("Apply to scene", "apply", _apply_to_scene, TH.OK, "Write the edited mesh back to the MeshInstance3D (undoable)"))
	g.add_child(_btn("Revert", "revert", _revert_session, TH.GREY, "Reload from the scene mesh"))
	g.add_child(_btn("Undo", "revert", _undo, TH.GREY, "Ctrl+Z"))
	g.add_child(_btn("Redo", "rotate", _redo, TH.GREY, "Ctrl+Shift+Z"))

func _display_positions() -> PackedVector3Array:
	if mode == "shapes" or mode == "weights":
		return em.display_positions()
	return em.positions()

func _refresh_overlay() -> void:
	if em == null or not is_instance_valid(em_source) or not (mode in MESH_MODES):
		return
	var xf = em_source.global_transform
	match mode:
		"weights":
			var p = em.display_positions()
			view.set_overlay("mesh", em.build_fast(p, em.weight_colors(weight_bone)), xf, mat_clay_vc)
			view.hide_overlay("wire")
			view.hide_overlay("pts")
		"modifiers":
			var ev = em.evaluate(mod_stack)
			view.set_overlay("mesh", ev.build_fast(ev.positions()), xf, mat_clay)
			view.hide_overlay("pts")
			if ev.faces.size() < 20000:
				view.set_overlay("wire", _wire_mesh(ev, ev.positions(), false, false)[0], xf, mat_wire)
			else:
				view.hide_overlay("wire")
		"edit", "uv":
			var p2 = em.positions()
			view.set_overlay("mesh", em.build_fast(p2), xf, mat_clay)
			var wm = _wire_mesh(em, p2, mode == "edit" and em.sel_mode == EM.SEL_VERT, mode == "edit")
			view.set_overlay("wire", wm[0], xf, mat_wire)
			if wm[1] != null:
				view.set_overlay("pts", wm[1], xf, mat_points)
			else:
				view.hide_overlay("pts")
		_:
			var p3 = _display_positions()
			view.set_overlay("mesh", em.build_fast(p3), xf, mat_clay)
			view.hide_overlay("wire")
			view.hide_overlay("pts")
	_update_stats()
	if uv_canvas:
		uv_canvas.queue_redraw()

func _wire_mesh(m, p: PackedVector3Array, points: bool, selection: bool) -> Array:
	var am = ArrayMesh.new()
	var lv = PackedVector3Array()
	var lc = PackedColorArray()
	var sv = m.selected_verts() if selection else {}
	var se = {}
	if selection:
		if m.sel_mode == EM.SEL_EDGE:
			se = m.sel_e
		elif m.sel_mode == EM.SEL_FACE:
			for fi in m.sel_f:
				if fi < m.faces.size():
					var f: PackedInt32Array = m.faces[fi]
					for i in f.size():
						se[EM.ekey(f[i], f[(i + 1) % f.size()])] = true
	var base = Color(0.08, 0.1, 0.13, 0.75)
	var hi = TH.ORANGE
	for e in m.edge_faces():
		lv.append(p[e.x])
		lv.append(p[e.y])
		var on = selection and (se.has(e) or (m.sel_mode == EM.SEL_VERT and sv.has(e.x) and sv.has(e.y)))
		var c = hi if on else base
		lc.append(c)
		lc.append(c)
	if lv.size() > 0:
		var a = []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = lv
		a[Mesh.ARRAY_COLOR] = lc
		am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, a)
	var ptm = null
	if points:
		ptm = ArrayMesh.new()
		var pc = PackedColorArray()
		pc.resize(p.size())
		for i in p.size():
			pc[i] = hi if sv.has(i) else Color(0.1, 0.13, 0.17, 0.9)
		var a2 = []
		a2.resize(Mesh.ARRAY_MAX)
		a2[Mesh.ARRAY_VERTEX] = p
		a2[Mesh.ARRAY_COLOR] = pc
		ptm.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, a2)
	if selection:
		var fv = PackedVector3Array()
		var fc = PackedColorArray()
		var tint = Color(TH.ORANGE, 0.28)
		for fi in m.selected_faces_full():
			var f: PackedInt32Array = m.faces[fi]
			for t in range(1, f.size() - 1):
				fv.append(p[f[0]])
				fv.append(p[f[t]])
				fv.append(p[f[t + 1]])
				fc.append(tint)
				fc.append(tint)
				fc.append(tint)
		if fv.size() > 0:
			var a3 = []
			a3.resize(Mesh.ARRAY_MAX)
			a3[Mesh.ARRAY_VERTEX] = fv
			a3[Mesh.ARRAY_COLOR] = fc
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a3)
	return [am, ptm]

func _update_stats() -> void:
	if stats_lbl == null:
		return
	if em != null and mode in MESH_MODES:
		var selc = em.selected_verts().size()
		stats_lbl.text = "Verts %d  ·  Faces %d  ·  Edges %d  ·  Selected %d" % [em.verts.size(), em.faces.size(), em.edge_faces().size(), selc]
	else:
		stats_lbl.text = ""

# =============================================================== EDIT MODE

func _props_edit() -> void:
	var s = _section("Edit Mode", "edit")
	if em == null:
		_note(s, "Select a MeshInstance3D (or bake one in Model) to edit.", TH.WARN)
		return
	var h = HBoxContainer.new()
	s.add_child(h)
	var grp = ButtonGroup.new()
	for k in [[EM.SEL_VERT, "Vertex", "vert"], [EM.SEL_EDGE, "Edge", "edgesel"], [EM.SEL_FACE, "Face", "facesel"]]:
		var b = _btn(k[1], k[2], func():
			em.set_sel_mode(k[0])
			_refresh_overlay(), TH.ORANGE)
		b.toggle_mode = true
		b.button_group = grp
		b.button_pressed = em.sel_mode == k[0]
		h.add_child(b)
	var g = _grid(s, 3)
	g.add_child(_btn("All", "", func(): em.select_all(true); _refresh_overlay()))
	g.add_child(_btn("None", "", func(): em.select_all(false); _refresh_overlay()))
	g.add_child(_btn("Invert", "", func(): em.select_invert(); _refresh_overlay()))
	g.add_child(_btn("Linked", "", func(): em.select_linked(); _refresh_overlay()))
	g.add_child(_btn("Grow", "", func(): em.select_grow(); _refresh_overlay()))
	var xr = CheckBox.new()
	xr.text = "X-ray"
	xr.button_pressed = xray
	xr.toggled.connect(func(v): xray = v)
	g.add_child(xr)
	var s2 = _section("Transform", "move")
	_note(s2, "G / R / S in the view for free move, rotate, scale; type exact values here.")
	var mv = [0.0, 0.0, 0.0]
	var hm = HBoxContainer.new()
	s2.add_child(hm)
	for k in 3:
		var sp = SpinBox.new()
		sp.min_value = -100
		sp.max_value = 100
		sp.step = 0.005
		sp.prefix = ["X", "Y", "Z"][k]
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.value_changed.connect(func(v): mv[k] = v)
		hm.add_child(sp)
	var g2 = _grid(s2, 3)
	g2.add_child(_btn("Move", "move", func():
		_push_undo()
		em.translate(Vector3(mv[0], mv[1], mv[2]))
		_refresh_overlay(), TH.ORANGE))
	g2.add_child(_btn("Rotate°", "rotate", func():
		_push_undo()
		var ax = Vector3(mv[0], mv[1], mv[2])
		var ang = ax.length()
		if ang > 0.0:
			em.rotate(ax.normalized(), deg_to_rad(ang), em.selection_center())
		_refresh_overlay(), TH.ORANGE, "Rotate by the X/Y/Z values in degrees (axis = vector)"))
	g2.add_child(_btn("Scale", "scale", func():
		_push_undo()
		var f = Vector3(mv[0] if mv[0] != 0.0 else 1.0, mv[1] if mv[1] != 0.0 else 1.0, mv[2] if mv[2] != 0.0 else 1.0)
		em.scale(f, em.selection_center())
		_refresh_overlay(), TH.ORANGE, "Scale by X/Y/Z factors (0 = unchanged)"))
	var s3 = _section("Mesh tools", "extrude")
	_spin(s3, "Extrude dist", -10, 10, 0.005, extrude_dist, func(v): extrude_dist = v)
	_spin(s3, "Inset amount", 0.01, 0.95, 0.01, inset_t, func(v): inset_t = v)
	_spin(s3, "Merge dist", 0.0, 1.0, 0.0005, merge_dist, func(v): merge_dist = v)
	var g3 = _grid(s3, 2)
	var tools = [
		["Extrude (E)", "extrude", func(): return em.extrude(extrude_dist)],
		["Inset (I)", "inset", func(): return em.inset(inset_t)],
		["Subdivide", "subdivide", func(): return em.subdivide()],
		["Delete (X)", "delete", func(): return em.delete_selected()],
		["Merge center (M)", "merge", func(): return em.merge_at_center()],
		["Merge by dist", "merge", func(): return em.merge_by_distance(merge_dist)],
		["Make face (F)", "facesel", func(): return em.make_face()],
		["Flip normals", "rotate", func(): return em.flip_normals()],
		["Tris → quads", "subdivide", func(): return em.tris_to_quads()],
		["Smooth / flat", "sphere", func():
			em.smooth_shading = not em.smooth_shading
			return "Shading: " + ("smooth" if em.smooth_shading else "flat") + " (applies on Apply)"],
	]
	for t in tools:
		g3.add_child(_btn(t[0], t[1], func(): _run_op(t[2]), TH.ORANGE))
	var s4 = _section("Session", "apply")
	_session_buttons(s4)

func _run_op(fn: Callable) -> void:
	_push_undo()
	var msg = fn.call()
	_say(str(msg), TH.OK)
	_refresh_overlay()

func _pick_edit(pos: Vector2, additive: bool) -> void:
	var xf = em_source.global_transform
	var inv = xf.affine_inverse()
	var r = view.ray(pos)
	var o = inv * r[0]
	var d = (inv.basis * r[1]).normalized()
	var p = em.positions()
	var hit = em.raycast(o, d, p)
	var hit_d = INF
	if hit[0] >= 0:
		hit_d = o.distance_to(hit[1])
	var eps = em.aabb().size.length() * 0.01
	match em.sel_mode:
		EM.SEL_FACE:
			if hit[0] >= 0:
				em.toggle_face(hit[0], additive)
			elif not additive:
				em.sel_f.clear()
		EM.SEL_VERT:
			var best = -1
			var bd = 14.0
			for i in p.size():
				var g = xf * p[i]
				if view.behind(g):
					continue
				var sd = view.project(g).distance_to(pos)
				if sd < bd:
					if not xray and o.distance_to(p[i]) > hit_d + eps:
						continue
					bd = sd
					best = i
			if best >= 0:
				em.toggle_vert(best, additive)
			elif not additive:
				em.sel_v.clear()
		EM.SEL_EDGE:
			var beste = null
			var bde = 10.0
			for e in em.edge_faces():
				var a = xf * p[e.x]
				var b = xf * p[e.y]
				if view.behind(a) or view.behind(b):
					continue
				var sp = Geometry2D.get_closest_point_to_segment(pos, view.project(a), view.project(b))
				var sd = sp.distance_to(pos)
				if sd < bde:
					var mid = (p[e.x] + p[e.y]) * 0.5
					if not xray and o.distance_to(mid) > hit_d + eps:
						continue
					bde = sd
					beste = e
			if beste != null:
				em.toggle_edge(beste, additive)
			elif not additive:
				em.sel_e.clear()
	_refresh_overlay()

func _box_select(rect: Rect2, additive: bool) -> void:
	rect = rect.abs()
	var xf = em_source.global_transform
	var inv = xf.affine_inverse()
	var p = em.positions()
	var camo = inv * view.cam.global_transform.origin
	var inside = {}
	var eps = em.aabb().size.length() * 0.01
	for i in p.size():
		var g = xf * p[i]
		if view.behind(g):
			continue
		var sp = view.project(g)
		if not rect.has_point(sp):
			continue
		if not xray:
			var dir = (p[i] - camo)
			var hit = em.raycast(camo, dir.normalized(), p)
			if hit[0] >= 0 and camo.distance_to(hit[1]) < dir.length() - eps:
				continue
		inside[i] = true
	if not additive:
		em.sel_v.clear()
		em.sel_e.clear()
		em.sel_f.clear()
	match em.sel_mode:
		EM.SEL_VERT:
			for i in inside:
				em.sel_v[i] = true
		EM.SEL_EDGE:
			for e in em.edge_faces():
				if inside.has(e.x) and inside.has(e.y):
					em.sel_e[e] = true
		EM.SEL_FACE:
			for fi in em.faces.size():
				var all_in = true
				for v in em.faces[fi]:
					if not inside.has(v):
						all_in = false
						break
				if all_in:
					em.sel_f[fi] = true
	_refresh_overlay()

# ----- modal G / R / S (edit + pose)

func _modal_start(kind: String) -> void:
	if mode == "edit":
		var sv = em.selected_verts().keys()
		if sv.is_empty():
			_warn("Nothing selected.")
			return
		_push_undo()
		var pivot_l = em.selection_center()
		modal = {"kind": kind, "start": view.mouse_pos, "base": em.positions().duplicate(), "sv": sv, "pivot": pivot_l, "axis": -1,
			"pivot_s": view.project(em_source.global_transform * pivot_l)}
	elif mode == "pose":
		var skel = _skel()
		if skel == null or pose_bone < 0:
			_warn("Pick a bone first.")
			return
		var g = skel.global_transform * skel.get_bone_global_pose(pose_bone).origin
		modal = {"kind": "R", "start": view.mouse_pos, "base_rot": skel.get_bone_pose_rotation(pose_bone), "axis": -1, "pivot_s": view.project(g)}
	_say("%s - move the mouse, X/Y/Z to lock an axis, LMB/Enter confirm, RMB/Esc cancel." % {"G": "Move", "R": "Rotate", "S": "Scale"}[modal.get("kind", "R")])

func _modal_update() -> void:
	var mpos = view.mouse_pos
	if mode == "pose":
		var skel = _skel()
		var a0 = (modal.start - modal.pivot_s).angle()
		var a1 = (mpos - modal.pivot_s).angle()
		var ang = a1 - a0
		var par = skel.get_bone_parent(pose_bone)
		var pb = skel.global_transform.basis
		if par >= 0:
			pb = pb * skel.get_bone_global_pose(par).basis
		var axis_g = -view.view_dir()
		if modal.axis >= 0:
			axis_g = (skel.global_transform.basis * skel.get_bone_global_pose(pose_bone).basis).orthonormalized()[modal.axis]
			ang = -ang
		var axis_l = (pb.orthonormalized().inverse() * axis_g).normalized()
		skel.set_bone_pose_rotation(pose_bone, (Quaternion(axis_l, -ang) * modal.base_rot).normalized())
		_refresh_pose_overlay()
		return
	var xf = em_source.global_transform
	var inv_b = xf.basis.inverse()
	var base: PackedVector3Array = modal.base
	var pivot: Vector3 = modal.pivot
	var axis = modal.axis
	match modal.kind:
		"G":
			var wpp = view.world_per_pixel(xf * pivot)
			var dm = mpos - modal.start
			var dw = (view.cam.global_transform.basis.x * dm.x - view.cam.global_transform.basis.y * dm.y) * wpp
			var dl = inv_b * dw
			if axis >= 0:
				var ax = Vector3.ZERO
				ax[axis] = 1.0
				dl = ax * dl.dot(ax)
			em.set_from_base(base, modal.sv, func(x): return x + dl)
		"R":
			var a0 = (modal.start - modal.pivot_s).angle()
			var a1 = (mpos - modal.pivot_s).angle()
			var ang = a1 - a0
			var axw = -view.view_dir()
			var axl = (inv_b * axw).normalized()
			if axis >= 0:
				axl = Vector3.ZERO
				axl[axis] = 1.0
				if (xf.basis * axl).dot(axw) < 0.0:
					ang = -ang
			var b = Basis(axl, -ang)
			em.set_from_base(base, modal.sv, func(x): return pivot + b * (x - pivot))
		"S":
			var d0 = maxf(4.0, modal.start.distance_to(modal.pivot_s))
			var f = mpos.distance_to(modal.pivot_s) / d0
			var fv = Vector3(f, f, f)
			if axis >= 0:
				fv = Vector3.ONE
				fv[axis] = f
			em.set_from_base(base, modal.sv, func(x): return pivot + (x - pivot) * fv)
	_refresh_overlay()

func _modal_confirm() -> void:
	modal = {}
	if mode == "pose":
		_rebuild_pose_sliders()
	_say("Done.", TH.OK)

func _modal_cancel() -> void:
	if modal.is_empty():
		return
	if mode == "pose":
		var skel = _skel()
		if skel and pose_bone >= 0:
			skel.set_bone_pose_rotation(pose_bone, modal.base_rot)
		_refresh_pose_overlay()
	elif em != null and modal.has("base"):
		em.set_positions(modal.base)
		if history.size() > 0:
			history.pop_back()
		_refresh_overlay()
	modal = {}
	_say("Cancelled.")

func wants_right_click() -> bool:
	return not modal.is_empty()

# =============================================================== SCULPT

func _props_sculpt() -> void:
	var s = _section("Sculpt brushes", "sculpt")
	if em == null:
		_note(s, "Select a MeshInstance3D to sculpt.", TH.WARN)
		return
	if em.active_shape >= 0:
		_note(s, "Sculpting shape key '%s'." % em.shapes[em.active_shape].name, TH.TEAL)
	var g = _grid(s, 2)
	var grp = ButtonGroup.new()
	for k in [["draw", "Draw", "brush"], ["smooth", "Smooth", "sphere"], ["inflate", "Inflate", "scale"], ["grab", "Grab", "move"]]:
		var b = _btn(k[1], k[2], func(): sculpt_brush = k[0], TH.ORANGE)
		b.toggle_mode = true
		b.button_group = grp
		b.button_pressed = sculpt_brush == k[0]
		g.add_child(b)
	_slider(s, "Radius", 0.01, 0.5, 0.005, brush_radius, func(v): brush_radius = v)
	_slider(s, "Strength", 0.01, 1.0, 0.01, brush_strength, func(v): brush_strength = v)
	_check(s, "X symmetry", sym_x, func(v): sym_x = v)
	_note(s, "Radius is a fraction of the mesh size. Hold Ctrl to invert Draw / Inflate.")
	var s2 = _section("Session", "apply")
	_session_buttons(s2)

func _mesh_ray(pos: Vector2) -> Array:
	var xf = em_source.global_transform
	var inv = xf.affine_inverse()
	var r = view.ray(pos)
	var o = inv * r[0]
	var d = (inv.basis * r[1]).normalized()
	var hit = em.raycast(o, d, _display_positions())
	return [hit[0], hit[1], o, d]

func _brush_world_radius() -> float:
	return brush_radius * em.aabb().size.length()

func _update_brush_px(pos: Vector2) -> void:
	if em == null or not is_instance_valid(em_source):
		view.brush_px = 0.0
		return
	var hit = _mesh_ray(pos)
	var c = em.aabb().get_center()
	if hit[0] >= 0:
		c = hit[1]
	var g = em_source.global_transform * c
	var rw = _brush_world_radius() * em_source.global_transform.basis.get_scale().x
	view.brush_px = rw / maxf(view.world_per_pixel(g), 1e-6)

func _sculpt_dab(pos: Vector2, ctrl: bool) -> void:
	var hit = _mesh_ray(pos)
	if hit[0] < 0:
		return
	var r = _brush_world_radius()
	if mode == "weights":
		if weight_bone < 0:
			_warn("Pick a bone in the list first.")
			return
		em.weight_dab(hit[1], r, brush_strength, weight_bone, "subtract" if ctrl and weight_mode == "add" else weight_mode)
	else:
		em.sculpt_dab(sculpt_brush, hit[1], r, brush_strength, ctrl, sym_x)
	_refresh_overlay()

# =============================================================== WEIGHTS

func _bind_names() -> Array:
	var out = []
	if em_source and em_source.skin:
		var skin = em_source.skin
		var sk = SU.find_skeleton(em_source)
		for b in skin.get_bind_count():
			var nm = String(skin.get_bind_name(b))
			if nm == "" and sk and skin.get_bind_bone(b) >= 0 and skin.get_bind_bone(b) < sk.get_bone_count():
				nm = sk.get_bone_name(skin.get_bind_bone(b))
			out.append(nm if nm != "" else "bind %d" % b)
	else:
		var sk2 = SU.find_skeleton(em_source)
		if sk2:
			for i in sk2.get_bone_count():
				out.append(sk2.get_bone_name(i))
	return out

func _props_weights() -> void:
	var s = _section("Weight paint", "weights")
	if em == null:
		_note(s, "Select a skinned (or to-be-skinned) MeshInstance3D.", TH.WARN)
		return
	var names = _bind_names()
	if names.is_empty():
		_note(s, "No skeleton found for this mesh. Parent it under a Skeleton3D or select a character mesh.", TH.WARN)
	_note(s, ("Skin: %d binds." % names.size()) if em_source.skin else "Mesh has no Skin yet - 'Auto weights' creates one from the skeleton rest pose.", TH.TEXT)
	var filt = LineEdit.new()
	filt.placeholder_text = "Filter bones…"
	s.add_child(filt)
	var list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 200)
	s.add_child(list)
	var fill = func(f: String):
		list.clear()
		for i in names.size():
			if f == "" or String(names[i]).to_lower().contains(f.to_lower()):
				var idx = list.add_item(names[i], IC.get_icon("bone", 14))
				list.set_item_metadata(idx, i)
				list.set_item_icon_modulate(idx, TH.BLUE)
				if i == weight_bone:
					list.select(idx)
	fill.call("")
	filt.text_changed.connect(func(t): fill.call(t))
	list.item_selected.connect(func(i):
		weight_bone = int(list.get_item_metadata(i))
		_refresh_overlay()
		_say("Painting weights for %s." % names[weight_bone]))
	var grp = ButtonGroup.new()
	var h = HBoxContainer.new()
	s.add_child(h)
	for k in [["add", "Add", "add"], ["subtract", "Subtract", "remove"], ["smooth", "Smooth", "sphere"]]:
		var b = _btn(k[1], k[2], func(): weight_mode = k[0], TH.ORANGE)
		b.toggle_mode = true
		b.button_group = grp
		b.button_pressed = weight_mode == k[0]
		h.add_child(b)
	_slider(s, "Radius", 0.01, 0.5, 0.005, brush_radius, func(v): brush_radius = v)
	_slider(s, "Strength", 0.01, 1.0, 0.01, brush_strength, func(v): brush_strength = v)
	var legend = HBoxContainer.new()
	s.add_child(legend)
	for w in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var cr = ColorRect.new()
		cr.color = TH.heat(w)
		cr.custom_minimum_size = Vector2(54, 10)
		cr.tooltip_text = "weight %.2f" % w
		legend.add_child(cr)
	var s2 = _section("Bind", "bone")
	s2.add_child(_btn("Auto weights from bones (envelope)", "weights", _auto_weights, TH.TEAL, "Nearest-bone envelope weights; creates a Skin from the rest pose if needed"))
	var s3 = _section("Session", "apply")
	_session_buttons(s3)

func _auto_weights() -> void:
	var sk = SU.find_skeleton(em_source)
	if sk == null:
		_warn("No Skeleton3D for this mesh.")
		return
	_push_undo()
	var to_mesh = em_source.global_transform.affine_inverse() * sk.global_transform
	var segs = []
	var bind_bones = []
	if em_source.skin:
		for b in em_source.skin.get_bind_count():
			var bi = em_source.skin.get_bind_bone(b)
			if bi < 0:
				bi = sk.find_bone(em_source.skin.get_bind_name(b))
			bind_bones.append(bi)
	else:
		for i in sk.get_bone_count():
			bind_bones.append(i)
	for b in bind_bones.size():
		var bi = bind_bones[b]
		if bi < 0:
			continue
		var head = sk.get_bone_global_rest(bi).origin
		var kids = sk.get_bone_children(bi)
		var tail = head
		if kids.size() > 0:
			for k in kids:
				tail += sk.get_bone_global_rest(k).origin
			tail = (tail - head) / float(kids.size())
		else:
			var par = sk.get_bone_parent(bi)
			var ln = 0.05
			if par >= 0:
				ln = head.distance_to(sk.get_bone_global_rest(par).origin) * 0.6
			tail = head + sk.get_bone_global_rest(bi).basis.y.normalized() * ln
		segs.append([b, to_mesh * head, to_mesh * tail])
	em.auto_weights(segs)
	if em_source.skin == null:
		var skin = sk.create_skin_from_rest_transforms()
		ur.create_action("CHoMU: Create Skin", UndoRedo.MERGE_DISABLE, em_source)
		ur.add_do_property(em_source, "skin", skin)
		ur.add_undo_property(em_source, "skin", null)
		ur.add_do_property(em_source, "skeleton", em_source.get_path_to(sk))
		ur.add_undo_property(em_source, "skeleton", em_source.skeleton)
		ur.commit_action()
	_refresh_overlay()
	_say("Auto weights from %d bones. Press 'Apply to scene' to bind." % segs.size(), TH.OK)
	_rebuild_props()

# =============================================================== SHAPE KEYS

func _props_shapes() -> void:
	var s = _section("Shape keys (blend shapes)", "shapes")
	if em == null:
		_note(s, "Select a MeshInstance3D.", TH.WARN)
		return
	var basis_btn = _btn("Basis%s" % ("  (editing)" if em.active_shape < 0 else ""), "key", func():
		em.active_shape = -1
		_refresh_overlay()
		_rebuild_props(), TH.BLUE if em.active_shape < 0 else TH.GREY)
	s.add_child(basis_btn)
	for i in em.shapes.size():
		var row = VBoxContainer.new()
		s.add_child(row)
		var h = HBoxContainer.new()
		row.add_child(h)
		var le = LineEdit.new()
		le.text = em.shapes[i].name
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_submitted.connect(func(t): em.shapes[i].name = t)
		le.focus_exited.connect(func(): em.shapes[i].name = le.text)
		h.add_child(le)
		var eb = Button.new()
		eb.icon = IC.get_icon("sculpt", 16)
		eb.tooltip_text = "Sculpt this key"
		eb.add_theme_color_override("icon_normal_color", TH.ORANGE if em.active_shape == i else TH.GREY)
		eb.pressed.connect(func():
			em.active_shape = i
			_set_mode("sculpt"))
		h.add_child(eb)
		var rb = Button.new()
		rb.icon = IC.get_icon("delete", 16)
		rb.tooltip_text = "Remove key"
		rb.add_theme_color_override("icon_normal_color", TH.GREY)
		rb.pressed.connect(func():
			_push_undo()
			em.remove_shape(i)
			_refresh_overlay()
			_rebuild_props())
		h.add_child(rb)
		_slider(row, "Value", 0.0, 1.0, 0.01, em.shapes[i].w, func(v):
			em.shapes[i].w = v
			if is_instance_valid(em_source) and em_source.mesh and em_source.find_blend_shape_by_name(StringName(em.shapes[i].name)) >= 0:
				em_source.set_blend_shape_value(em_source.find_blend_shape_by_name(StringName(em.shapes[i].name)), v)
			_refresh_overlay())
	var g = _grid(s, 2)
	g.add_child(_btn("New key", "add", func():
		_push_undo()
		var i = em.add_shape("Key %d" % (em.shapes.size() + 1), false)
		em.active_shape = i
		_say("Added '%s' - now sculpting it." % em.shapes[i].name, TH.OK)
		_set_mode("sculpt"), TH.TEAL, "Copy of the basis, then sculpt it"))
	g.add_child(_btn("Key from preview", "key", func():
		_push_undo()
		em.add_shape("Mix %d" % (em.shapes.size() + 1), true)
		_rebuild_props(), TH.TEAL, "Bake the current slider mix into a new key"))
	_note(s, "Keys are written as blend shapes on 'Apply to scene'. Scene sliders follow when names match.")
	var s2 = _section("Session", "apply")
	_session_buttons(s2)

# =============================================================== UV

func _props_uv() -> void:
	var s = _section("UV unwrap", "uv")
	if em == null:
		_note(s, "Select a MeshInstance3D.", TH.WARN)
		return
	_note(s, "Uses the engine's built-in xatlas (ArrayMesh.lightmap_unwrap).", TH.TEXT)
	s.add_child(_btn("One-click unwrap → UV1", "uv", _uv_unwrap.bind(true), TH.ORANGE, "Replace the texture UVs with an automatic xatlas unwrap"))
	s.add_child(_btn("Generate UV2 for lightmaps (scene mesh)", "uv", _uv_unwrap.bind(false), TH.TEAL, "Keeps UV1, writes UV2 for LightmapGI"))
	var s2 = _section("UV layout", "uv")
	uv_canvas = Control.new()
	uv_canvas.custom_minimum_size = Vector2(300, 300)
	uv_canvas.draw.connect(_draw_uv)
	s2.add_child(uv_canvas)
	var s3 = _section("Session", "apply")
	_session_buttons(s3)

func _draw_uv() -> void:
	if uv_canvas == null or em == null:
		return
	var sz = uv_canvas.size
	var side = minf(sz.x, sz.y)
	uv_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(side, side)), TH.BG)
	for i in 9:
		var t = side * i / 8.0
		uv_canvas.draw_line(Vector2(t, 0), Vector2(t, side), Color(TH.LINE, 0.6), 1.0)
		uv_canvas.draw_line(Vector2(0, t), Vector2(side, t), Color(TH.LINE, 0.6), 1.0)
	var lines = PackedVector2Array()
	var limit = mini(em.faces.size(), 15000)
	for fi in limit:
		var u: PackedVector2Array = em.fuv[fi]
		for k in u.size():
			var a = u[k]
			var b = u[(k + 1) % u.size()]
			lines.append(Vector2(fposmod(a.x, 1.0001), fposmod(a.y, 1.0001)) * side)
			lines.append(Vector2(fposmod(b.x, 1.0001), fposmod(b.y, 1.0001)) * side)
	if lines.size() > 0:
		uv_canvas.draw_multiline(lines, Color(TH.TEAL, 0.7), 1.0)
	uv_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(side, side)), TH.LINE, false, 1.0)

func _uv_unwrap(to_uv1: bool) -> void:
	if em == null:
		return
	if not to_uv1:
		var src = em_source.mesh
		var am: ArrayMesh
		if src is ArrayMesh:
			am = src.duplicate(true)
		else:
			am = ArrayMesh.new()
			for si in src.get_surface_count():
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(si))
				am.surface_set_material(si, src.surface_get_material(si))
		var err = am.lightmap_unwrap(Transform3D.IDENTITY, 0.05)
		if err != OK:
			_warn("lightmap_unwrap failed (error %d). Meshes with blend shapes or skinning may be refused." % err)
			return
		SU.set_prop(ur, "CHoMU: Generate UV2", em_source, "mesh", am)
		_say("UV2 generated on %s (undoable)." % em_source.name, TH.OK)
		return
	if em.shapes.size() > 0:
		_warn("Unwrap to UV1 is skipped for meshes with shape keys (xatlas rebuilds vertices).")
		return
	_push_undo()
	var built = em.build_mesh()
	var err2 = built.lightmap_unwrap(Transform3D.IDENTITY, 0.05)
	if err2 != OK:
		history.pop_back()
		_warn("lightmap_unwrap failed (error %d)." % err2)
		return
	var out = ArrayMesh.new()
	for si in built.get_surface_count():
		var arr = built.surface_get_arrays(si)
		if arr[Mesh.ARRAY_TEX_UV2] != null:
			arr[Mesh.ARRAY_TEX_UV] = arr[Mesh.ARRAY_TEX_UV2]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, built.surface_get_material(si))
	var smooth = em.smooth_shading
	em.load_mesh(out)
	em.smooth_shading = smooth
	_refresh_overlay()
	_say("Unwrapped with xatlas: %d faces. Apply to scene to keep it." % em.faces.size(), TH.OK)

# =============================================================== MODIFIERS

func _props_modifiers() -> void:
	var s = _section("Modifier stack", "modifiers")
	if em == null:
		_note(s, "Select a MeshInstance3D.", TH.WARN)
		return
	if mod_stack.is_empty():
		_note(s, "Empty. Add a modifier below - the view shows the result live.")
	for i in mod_stack.size():
		var md: Dictionary = mod_stack[i]
		var pc = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", TH.flat(TH.PANEL3, 6, TH.LINE, 1, 6))
		s.add_child(pc)
		var v = VBoxContainer.new()
		pc.add_child(v)
		var h = HBoxContainer.new()
		v.add_child(h)
		var ic = TextureRect.new()
		ic.texture = IC.get_icon({"Mirror": "mirror", "Array": "array", "Subdivision": "subdivide"}[md.type], 16)
		ic.modulate = TH.ORANGE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(ic)
		var cb = CheckBox.new()
		cb.text = md.type
		cb.button_pressed = md.get("enabled", true)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.toggled.connect(func(x):
			md.enabled = x
			_refresh_overlay())
		h.add_child(cb)
		for act in [["▲", -1], ["▼", 1]]:
			var mb = Button.new()
			mb.text = act[0]
			mb.pressed.connect(func():
				var j = i + act[1]
				if j >= 0 and j < mod_stack.size():
					var tmp = mod_stack[i]
					mod_stack[i] = mod_stack[j]
					mod_stack[j] = tmp
					_rebuild_props()
					_refresh_overlay())
			h.add_child(mb)
		var rb = Button.new()
		rb.icon = IC.get_icon("delete", 14)
		rb.add_theme_color_override("icon_normal_color", TH.GREY)
		rb.pressed.connect(func():
			mod_stack.remove_at(i)
			_rebuild_props()
			_refresh_overlay())
		h.add_child(rb)
		match md.type:
			"Mirror":
				_option(v, "Axis", ["X", "Y", "Z"], ["X", "Y", "Z"][int(md.get("axis", 0))], func(x):
					md.axis = ["X", "Y", "Z"].find(x)
					_refresh_overlay())
				_spin(v, "Merge dist", 0.0, 1.0, 0.0005, md.get("merge", 0.001), func(x):
					md.merge = x
					_refresh_overlay())
			"Array":
				_spin(v, "Count", 1, 50, 1, md.get("count", 3), func(x):
					md.count = int(x)
					_refresh_overlay())
				var off: Vector3 = md.get("offset", Vector3(1.1, 0, 0))
				for k in 3:
					_spin(v, "Rel. offset " + ["X", "Y", "Z"][k], -10, 10, 0.05, off[k], func(x):
						var o2: Vector3 = md.get("offset", Vector3(1.1, 0, 0))
						o2[k] = x
						md.offset = o2
						_refresh_overlay())
			"Subdivision":
				_spin(v, "Levels", 0, 3, 1, md.get("levels", 1), func(x):
					md.levels = int(x)
					_refresh_overlay())
	var g = _grid(s, 3)
	g.add_child(_btn("Mirror", "mirror", func(): _add_mod({"type": "Mirror", "axis": 0, "merge": 0.001, "enabled": true}), TH.ORANGE))
	g.add_child(_btn("Array", "array", func(): _add_mod({"type": "Array", "count": 3, "offset": Vector3(1.1, 0, 0), "enabled": true}), TH.ORANGE))
	g.add_child(_btn("Subdiv", "subdivide", func(): _add_mod({"type": "Subdivision", "levels": 1, "enabled": true}), TH.ORANGE))
	s.add_child(_btn("Bake stack into the edit mesh", "bake", func():
		if mod_stack.is_empty():
			return
		_push_undo()
		var ev = em.evaluate(mod_stack)
		var smooth = em.smooth_shading
		em.restore(ev.snapshot())
		em.smooth_shading = smooth
		mod_stack.clear()
		_rebuild_props()
		_refresh_overlay()
		_say("Modifiers baked: %d verts, %d faces." % [em.verts.size(), em.faces.size()], TH.OK), TH.GREY))
	_note(s, "Catmull-Clark on a 10k-face character is slow in GDScript; use it on block-out meshes.")
	var s2 = _section("Session", "apply")
	_session_buttons(s2)

func _add_mod(md: Dictionary) -> void:
	if md.type == "Subdivision" and em.faces.size() > 20000:
		_warn("Mesh too dense for live subdivision (%d faces)." % em.faces.size())
		return
	mod_stack.append(md)
	_rebuild_props()
	_refresh_overlay()

# =============================================================== viewport input routing

func vp_event(e: InputEvent, v) -> bool:
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		return _key(e as InputEventKey)
	if e is InputEventMouseMotion:
		var mm = e as InputEventMouseMotion
		if not modal.is_empty():
			_modal_update()
			return true
		if mode in ["sculpt", "weights"] and em != null:
			_update_brush_px(mm.position)
			if not stroke.is_empty():
				if stroke.get("grab", false):
					var wpp = view.world_per_pixel(em_source.global_transform * stroke.hit)
					var dm = mm.position - stroke.start
					var dw = (view.cam.global_transform.basis.x * dm.x - view.cam.global_transform.basis.y * dm.y) * wpp
					em.grab_update(em_source.global_transform.basis.inverse() * dw, sym_x)
					_refresh_overlay()
				else:
					_sculpt_dab(mm.position, mm.ctrl_pressed)
			view.hud.queue_redraw()
			return true
		if mode == "edit" and not click.is_empty():
			if click.start.distance_to(mm.position) > 6.0:
				view.box_rect = Rect2(click.start, mm.position - click.start)
				view.hud.queue_redraw()
			return true
		return false
	if e is InputEventMouseButton:
		var mb = e as InputEventMouseButton
		if not modal.is_empty():
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_modal_confirm()
				return true
			if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				_modal_cancel()
				return true
			return true
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		match mode:
			"edit":
				if em == null:
					return false
				if mb.pressed:
					click = {"start": mb.position, "shift": mb.shift_pressed}
				else:
					if click.is_empty():
						return true
					if view.box_rect.size.length() > 6.0:
						_box_select(view.box_rect, click.shift)
					else:
						_pick_edit(mb.position, click.shift)
					view.box_rect = Rect2()
					view.hud.queue_redraw()
					click = {}
				return true
			"sculpt", "weights":
				if em == null:
					return false
				if mb.pressed:
					_push_undo()
					var hit = _mesh_ray(mb.position)
					if hit[0] < 0:
						history.pop_back()
						return true
					if mode == "sculpt" and sculpt_brush == "grab":
						var n = em.grab_begin(hit[1], _brush_world_radius(), sym_x)
						stroke = {"grab": true, "hit": hit[1], "start": mb.position, "n": n}
					else:
						stroke = {"grab": false}
						_sculpt_dab(mb.position, mb.ctrl_pressed)
				else:
					stroke = {}
				return true
			"pose":
				if mb.pressed:
					var b = _pick_bone(mb.position)
					if b >= 0:
						pose_bone = b
						var skel = _skel()
						_say("Bone: %s" % skel.get_bone_name(b))
						_rebuild_props()
						_refresh_pose_overlay()
				return true
	return false

func _key(k: InputEventKey) -> bool:
	var code = k.keycode
	if not modal.is_empty():
		match code:
			KEY_X, KEY_Y, KEY_Z:
				modal.axis = {KEY_X: 0, KEY_Y: 1, KEY_Z: 2}[code]
				_modal_update()
				return true
			KEY_ENTER, KEY_KP_ENTER:
				_modal_confirm()
				return true
			KEY_ESCAPE:
				_modal_cancel()
				return true
		return true
	if mode in MESH_MODES and em != null and k.ctrl_pressed and code == KEY_Z:
		if k.shift_pressed:
			_redo()
		else:
			_undo()
		return true
	match mode:
		"edit":
			if em == null:
				return false
			match code:
				KEY_1:
					em.set_sel_mode(EM.SEL_VERT); _rebuild_props(); _refresh_overlay(); return true
				KEY_2:
					em.set_sel_mode(EM.SEL_EDGE); _rebuild_props(); _refresh_overlay(); return true
				KEY_3:
					em.set_sel_mode(EM.SEL_FACE); _rebuild_props(); _refresh_overlay(); return true
				KEY_A:
					em.select_all(not k.alt_pressed); _refresh_overlay(); return true
				KEY_I:
					if k.ctrl_pressed:
						em.select_invert(); _refresh_overlay()
					else:
						_run_op(func(): return em.inset(inset_t))
					return true
				KEY_L:
					em.select_linked(); _refresh_overlay(); return true
				KEY_G, KEY_R, KEY_S:
					_modal_start({KEY_G: "G", KEY_R: "R", KEY_S: "S"}[code]); return true
				KEY_E:
					_run_op(func(): return em.extrude(extrude_dist))
					_modal_start("G")
					return true
				KEY_X, KEY_DELETE:
					_run_op(func(): return em.delete_selected()); return true
				KEY_M:
					_run_op(func(): return em.merge_at_center()); return true
				KEY_F:
					_run_op(func(): return em.make_face()); return true
		"sculpt":
			match code:
				KEY_1:
					sculpt_brush = "draw"; _rebuild_props(); return true
				KEY_2:
					sculpt_brush = "smooth"; _rebuild_props(); return true
				KEY_3:
					sculpt_brush = "inflate"; _rebuild_props(); return true
				KEY_4:
					sculpt_brush = "grab"; _rebuild_props(); return true
				KEY_BRACKETLEFT:
					brush_radius = maxf(0.01, brush_radius * 0.85); _update_brush_px(view.mouse_pos); view.hud.queue_redraw(); return true
				KEY_BRACKETRIGHT:
					brush_radius = minf(0.5, brush_radius * 1.15); _update_brush_px(view.mouse_pos); view.hud.queue_redraw(); return true
		"weights":
			match code:
				KEY_BRACKETLEFT:
					brush_radius = maxf(0.01, brush_radius * 0.85); _update_brush_px(view.mouse_pos); view.hud.queue_redraw(); return true
				KEY_BRACKETRIGHT:
					brush_radius = minf(0.5, brush_radius * 1.15); _update_brush_px(view.mouse_pos); view.hud.queue_redraw(); return true
		"pose":
			match code:
				KEY_R:
					_modal_start("R"); return true
				KEY_K:
					_key_pose(false); return true
	return false

# =============================================================== automation hooks (used by the screenshot test)

func debug_select_edit_faces(face_ids: Array) -> void:
	if em == null:
		return
	em.set_sel_mode(EM.SEL_FACE)
	em.sel_f.clear()
	for f in face_ids:
		if f < em.faces.size():
			em.sel_f[f] = true
	_rebuild_props()
	_refresh_overlay()

func debug_set_orbit(yaw_r: float, pitch_r: float, dist_mul: float) -> void:
	view.yaw = yaw_r
	view.pitch = pitch_r
	view.dist *= dist_mul
	view._update_cam()
