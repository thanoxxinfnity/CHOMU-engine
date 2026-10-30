extends CanvasLayer
## In-game HUD: touch controls, minimap, clock, speedometer, prompts, pause + settings.

var touch: Control
var minimap: Control
var clock_label: Label
var speed_panel: PanelContainer
var speed_label: Label
var gear_label: Label
var prompt: Label
var fps_label: Label
var caption: Label
var pause_root: Control
var pause_menu: VBoxContainer
var settings: PanelContainer
var fade: ColorRect

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Util.make_theme()
	add_child(root)

	touch = preload("res://scripts/TouchControls.gd").new()
	root.add_child(touch)

	minimap = preload("res://scripts/Minimap.gd").new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-250, 20)
	root.add_child(minimap)

	var top := HBoxContainer.new()
	top.position = Vector2(115, 26)
	top.add_theme_constant_override("separation", 18)
	root.add_child(top)
	clock_label = Util.label("16:30", 34, Color.WHITE)
	clock_label.add_theme_constant_override("outline_size", 8)
	clock_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	top.add_child(clock_label)
	var city_lbl := Util.label("CHOMU CITY", 22, Util.ACCENT)
	city_lbl.add_theme_constant_override("outline_size", 6)
	city_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	top.add_child(city_lbl)
	fps_label = Util.label("", 20, Color(0.7, 1, 0.7))
	top.add_child(fps_label)

	speed_panel = PanelContainer.new()
	var sp_style := StyleBoxFlat.new()
	sp_style.bg_color = Color(0.05, 0.06, 0.08, 0.6)
	sp_style.set_corner_radius_all(18)
	sp_style.set_content_margin_all(12)
	speed_panel.add_theme_stylebox_override("panel", sp_style)
	speed_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	speed_panel.position = Vector2(-90, -150)
	speed_panel.custom_minimum_size = Vector2(180, 100)
	var spv := VBoxContainer.new()
	spv.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_panel.add_child(spv)
	speed_label = Util.label("0", 54, Color.WHITE)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spv.add_child(speed_label)
	gear_label = Util.label("km/h", 18, Util.ACCENT)
	gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spv.add_child(gear_label)
	speed_panel.visible = false
	root.add_child(speed_panel)

	prompt = Util.label("", 26, Color.WHITE)
	prompt.add_theme_constant_override("outline_size", 8)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-300, -60)
	prompt.custom_minimum_size = Vector2(600, 40)
	root.add_child(prompt)

	caption = Util.label("", 30, Color.WHITE)
	caption.add_theme_constant_override("outline_size", 10)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	caption.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(-400, 90)
	caption.custom_minimum_size = Vector2(800, 40)
	root.add_child(caption)

	# pause overlay
	pause_root = Control.new()
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.visible = false
	root.add_child(pause_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(center)
	var stack := Control.new()
	center.add_child(stack)
	var pm_panel := PanelContainer.new()
	center.add_child(pm_panel)
	pause_menu = VBoxContainer.new()
	pause_menu.add_theme_constant_override("separation", 14)
	pm_panel.add_child(pause_menu)
	pause_menu.add_child(Util.label("PAUSED", 44, Util.ACCENT))
	var resume := Util.button("Resume", 380, 74)
	resume.pressed.connect(func(): set_paused(false))
	pause_menu.add_child(resume)
	var set_btn := Util.button("Settings", 380, 74)
	set_btn.pressed.connect(func(): pm_panel.visible = false; settings.visible = true)
	pause_menu.add_child(set_btn)
	var menu_btn := Util.button("Main Menu", 380, 74)
	menu_btn.pressed.connect(func(): Game.goto_menu())
	pause_menu.add_child(menu_btn)
	var quit_btn := Util.button("Quit", 380, 74)
	quit_btn.pressed.connect(func(): get_tree().quit())
	pause_menu.add_child(quit_btn)
	settings = preload("res://scripts/SettingsPanel.gd").new()
	settings.visible = false
	settings.closed.connect(func(): settings.visible = false; pm_panel.visible = true)
	center.add_child(settings)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 0.8)

	Game.action.connect(_on_action)
	Game.settings_changed.connect(_refresh_settings)
	_refresh_settings()

func _refresh_settings() -> void:
	fps_label.visible = Game.show_fps

func _on_action(a: String) -> void:
	if a == "pause":
		set_paused(not get_tree().paused)

func set_paused(on: bool) -> void:
	get_tree().paused = on
	pause_root.visible = on
	touch.visible = not on
	touch.release_all()
	if not on:
		settings.visible = false
		pause_menu.get_parent().visible = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not get_tree().paused and not Game.demo:
			set_paused(true)

func show_caption(text: String, secs := 3.0) -> void:
	caption.text = text
	caption.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_property(caption, "modulate:a", 0.0, 0.6)

func _process(_d: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	minimap.position = Vector2(vs.x - 250, 20)
	speed_panel.position = Vector2(vs.x * 0.5 - 90, vs.y - 150)
	prompt.position = Vector2(vs.x * 0.5 - 300, vs.y - 60)
	caption.position = Vector2(vs.x * 0.5 - 400, 96)
	if Game.day_night:
		clock_label.text = Game.day_night.clock_text()
	fps_label.text = "%d FPS · %s" % [Engine.get_frames_per_second(), Game.QUALITY_NAMES[Game.quality]]
	speed_panel.visible = Game.driving
	if Game.driving and Game.player_car:
		var kmh: float = Game.player_car.get_speed_kmh()
		speed_label.text = "%d" % int(kmh)
		var fs: float = Game.player_car.forward_speed()
		gear_label.text = "km/h  ·  " + ("R" if fs < -0.5 else ("N" if kmh < 1.0 else "D%d" % mini(int(absf(fs) / 13.0) + 1, 5)))
	if Game.driving:
		prompt.text = ""
	elif Game.near_car:
		prompt.text = "Tap ENTER to drive  (F on keyboard)"
	else:
		prompt.text = ""
