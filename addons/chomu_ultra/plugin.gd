@tool
extends EditorPlugin
## CHoMU Ultra editor plugin.
## Toolbar: [Apply CHoMU Ultra] [preset picker]. One click writes the preset's project settings (renderer, AA,
## 3D scaling, shadows, GI/reflection quality), updates the open 3D scene (WorldEnvironment, sun, ChomuPost layer)
## with Undo support, and backs up the old settings (Project > Tools > CHoMU Ultra: Restore previous settings).
## Also registers the "ChomuUltraBoot" autoload so the game applies chomu_ultra/runtime_preset ("Auto") at start.

const Presets = preload("res://addons/chomu_ultra/presets.gd")
const Api = preload("res://addons/chomu_ultra/chomu_ultra.gd")
const PostLayer = preload("res://addons/chomu_ultra/post/chomu_post_layer.gd")
const BACKUP := "res://addons/chomu_ultra/.previous_settings.cfg"
const AUTOLOAD := "ChomuUltraBoot"
const AUTOLOAD_PATH := "res://addons/chomu_ultra/boot.gd"

# UI palette (no pink / magenta / rose): slate, amber, teal, blue.
const C_BG := Color("121722")
const C_LINE := Color("2a3348")
const C_TEXT := Color("eef1f7")
const C_AMBER := Color("ffb02e")
const C_TEAL := Color("2bb3c0")

var _bar: HBoxContainer
var _btn: Button
var _pick: OptionButton
var _busy := false

func _enable_plugin() -> void:
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD):
		add_autoload_singleton(AUTOLOAD, AUTOLOAD_PATH)

func _disable_plugin() -> void:
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD):
		remove_autoload_singleton(AUTOLOAD)

func _enter_tree() -> void:
	_register_settings()
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 2)
	_btn = Button.new()
	_btn.text = "Apply CHoMU Ultra"
	_btn.tooltip_text = "One click: apply the selected CHoMU Ultra preset to the project settings and the open 3D scene."
	var th := EditorInterface.get_editor_theme()
	if th and th.has_icon("Environment", "EditorIcons"):
		_btn.icon = th.get_icon("Environment", "EditorIcons")
	_style(_btn)
	_btn.pressed.connect(_on_apply_pressed)
	_bar.add_child(_btn)
	_pick = OptionButton.new()
	_pick.tooltip_text = "Preset the button applies"
	for i in Presets.ORDER.size():
		_pick.add_item(Presets.ORDER[i], i)
		_pick.set_item_tooltip(i, str(Presets.info()[Presets.ORDER[i]].desc))
	var cur := str(ProjectSettings.get_setting(Presets.PRESET_SETTING, "Mobile Ultra"))
	_pick.select(max(Presets.ORDER.find(cur), 0))
	_pick.item_selected.connect(func(i: int): ProjectSettings.set_setting(Presets.PRESET_SETTING, Presets.ORDER[i]))
	_bar.add_child(_pick)
	add_control_to_container(CONTAINER_TOOLBAR, _bar)
	for p in Presets.ORDER:
		add_tool_menu_item("CHoMU Ultra: Apply %s" % p, apply_preset.bind(p))
	add_tool_menu_item("CHoMU Ultra: Restore previous settings", restore_previous)
	add_tool_menu_item("CHoMU Ultra: Show device tier", _print_tier)

func _exit_tree() -> void:
	for p in Presets.ORDER:
		remove_tool_menu_item("CHoMU Ultra: Apply %s" % p)
	remove_tool_menu_item("CHoMU Ultra: Restore previous settings")
	remove_tool_menu_item("CHoMU Ultra: Show device tier")
	if is_instance_valid(_bar):
		remove_control_from_container(CONTAINER_TOOLBAR, _bar)
		_bar.queue_free()

func _style(b: Button) -> void:
	var mk := func(bg: Color, border: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = border
		s.set_border_width_all(1)
		s.set_corner_radius_all(6)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 3
		s.content_margin_bottom = 3
		return s
	b.add_theme_stylebox_override("normal", mk.call(C_BG, C_AMBER.darkened(0.2)))
	b.add_theme_stylebox_override("hover", mk.call(C_BG.lightened(0.08), C_AMBER))
	b.add_theme_stylebox_override("pressed", mk.call(C_AMBER.darkened(0.55), C_AMBER))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", C_AMBER.lightened(0.2))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("icon_normal_color", C_AMBER)

func _register_settings() -> void:
	var defs := [
		[Presets.PRESET_SETTING, TYPE_STRING, PROPERTY_HINT_ENUM, ",".join(Presets.ORDER), "Mobile Ultra"],
		[Presets.RUNTIME_PRESET, TYPE_STRING, PROPERTY_HINT_ENUM, "Auto," + ",".join(Presets.ORDER), "Auto"],
		[Presets.APPLY_ON_START, TYPE_BOOL, PROPERTY_HINT_NONE, "", true],
		[Presets.ADAPTIVE, TYPE_BOOL, PROPERTY_HINT_NONE, "", true],
		[Presets.TARGET_FPS, TYPE_INT, PROPERTY_HINT_RANGE, "30,120,1", 60],
		[Presets.TONEMAPPER, TYPE_STRING, PROPERTY_HINT_ENUM, ",ACES,AgX", ""],
	]
	for d in defs:
		if not ProjectSettings.has_setting(d[0]):
			ProjectSettings.set_setting(d[0], d[4])
		ProjectSettings.set_initial_value(d[0], d[4])
		ProjectSettings.add_property_info({"name": d[0], "type": d[1], "hint": d[2], "hint_string": d[3]})
		ProjectSettings.set_as_basic(d[0], true)

func _on_apply_pressed() -> void:
	apply_preset(Presets.ORDER[max(_pick.selected, 0)])

func _print_tier() -> void:
	var d := Api.detect()
	print("CHoMU Ultra device tier (this machine): ", d)

# ------------------------------------------------------------------------------------------- apply

func apply_preset(preset: String) -> void:
	if _busy or not Presets.ORDER.has(preset):
		return
	_busy = true
	var s := Presets.project_settings_for(preset)
	var old_renderer := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	var bk := ConfigFile.new()
	for k in s:
		bk.set_value("settings", k.replace("/", "|"), ProjectSettings.get_setting(k) if ProjectSettings.has_setting(k) else null)
	bk.set_value("meta", "preset", str(ProjectSettings.get_setting(Presets.PRESET_SETTING, "")))
	bk.save(BACKUP)
	for k in s:
		ProjectSettings.set_setting(k, s[k])
	ProjectSettings.set_setting(Presets.PRESET_SETTING, preset)
	var err := ProjectSettings.save()
	var msg := "CHoMU Ultra: %s written to project settings%s." % [preset, "" if err == OK else " (save failed: %d)" % err]
	var scene_msg := apply_to_edited_scene(preset)
	if scene_msg != "":
		msg += " " + scene_msg
	var new_renderer := str(s.get("rendering/renderer/rendering_method", old_renderer))
	if new_renderer != old_renderer:
		msg += " Renderer changed to %s: restart the editor (Project > Reload Current Project) to see it." % new_renderer
	if is_instance_valid(_pick):
		_pick.select(Presets.ORDER.find(preset))
	print(msg)
	_busy = false

## Updates the open scene with undo/redo. Uses the preset's target renderer to decide which features to enable.
func apply_to_edited_scene(preset: String) -> String:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or not (root is Node3D):
		return "Open a 3D scene and press again to add/update its WorldEnvironment, sun and post layer."
	var renderer := str(Presets.info()[preset].renderer)
	var e := Presets.env_for(preset, renderer, str(ProjectSettings.get_setting(Presets.TONEMAPPER, "")))
	var ur := get_undo_redo()
	ur.create_action("CHoMU Ultra: %s" % preset, UndoRedo.MERGE_DISABLE, root)
	var we := Api.find_first(root, "WorldEnvironment") as WorldEnvironment
	var parts: Array[String] = []
	if we and we.environment:
		var env := we.environment
		for k in e:
			if k in env:
				ur.add_do_property(env, k, e[k])
				ur.add_undo_property(env, k, env.get(k))
		if env.sky:
			ur.add_do_property(env.sky, "radiance_size", Presets.sky_radiance_for(preset))
			ur.add_undo_property(env.sky, "radiance_size", env.sky.radiance_size)
		parts.append("WorldEnvironment updated")
	else:
		var env := Api.make_default_environment()
		for k in e:
			if k in env:
				env.set(k, e[k])
		env.sky.radiance_size = Presets.sky_radiance_for(preset) as Sky.RadianceSize
		if we:
			ur.add_do_property(we, "environment", env)
			ur.add_undo_property(we, "environment", null)
		else:
			we = WorldEnvironment.new()
			we.name = "WorldEnvironment"
			we.environment = env
			_add_node(ur, root, we)
		parts.append("WorldEnvironment added")
	var sun := Api.find_first(root, "DirectionalLight3D") as DirectionalLight3D
	if sun:
		var sd := Presets.sun_for(preset, renderer)
		for k in sd:
			if k in sun:
				ur.add_do_property(sun, k, sd[k])
				ur.add_undo_property(sun, k, sun.get(k))
		parts.append("sun tuned")
	var post := Presets.post_for(preset)
	var layer := root.get_node_or_null("ChomuPost")
	if layer == null and bool(post.get("enabled", false)):
		layer = PostLayer.new()
		layer.name = "ChomuPost"
		layer.set("params", post)
		_add_node(ur, root, layer)
		parts.append("ChomuPost layer added")
	elif layer != null:
		ur.add_do_method(layer, "configure", post)
		ur.add_undo_method(layer, "configure", (layer.get("params") as Dictionary).duplicate())
		parts.append("post %s" % ("on" if post.enabled else "off"))
	ur.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	return "Scene: " + ", ".join(parts) + " (Ctrl+Z to undo)."

func _add_node(ur: EditorUndoRedoManager, root: Node, n: Node) -> void:
	ur.add_do_method(root, "add_child", n, true)
	ur.add_do_method(n, "set_owner", root)
	ur.add_do_reference(n)
	ur.add_undo_method(root, "remove_child", n)

func restore_previous() -> void:
	var bk := ConfigFile.new()
	if bk.load(BACKUP) != OK:
		print("CHoMU Ultra: nothing to restore.")
		return
	for key in bk.get_section_keys("settings"):
		var k := key.replace("|", "/")
		var v = bk.get_value("settings", key)
		if v == null:
			ProjectSettings.clear(k)
		else:
			ProjectSettings.set_setting(k, v)
	var prev := str(bk.get_value("meta", "preset", ""))
	if prev != "":
		ProjectSettings.set_setting(Presets.PRESET_SETTING, prev)
	ProjectSettings.save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))
	print("CHoMU Ultra: previous project settings restored. Scene changes: use Ctrl+Z.")
