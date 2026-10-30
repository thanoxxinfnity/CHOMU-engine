extends Control
## Main menu: branding, Play / Settings / Quit.

var _menu_box: VBoxContainer
var _settings: PanelContainer
var _play_btn: Button
var _t := 0.0
var _title: Label
var _bg: TextureRect

func _ready() -> void:
	theme = Util.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color(0.149, 0.161, 0.184)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)

	_bg = TextureRect.new()
	_bg.texture = load("res://splash.png")
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.modulate = Color(1, 1, 1, 0.35)
	add_child(_bg)

	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.035, 0.05, 0.95))
	grad.set_color(1, Color(0.03, 0.035, 0.05, 0.1))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)

	_menu_box = VBoxContainer.new()
	_menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_box.add_theme_constant_override("separation", 18)
	margin.add_child(_menu_box)

	var logo_row := HBoxContainer.new()
	logo_row.add_theme_constant_override("separation", 22)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.custom_minimum_size = Vector2(110, 110)
	logo_row.add_child(logo)
	var tv := VBoxContainer.new()
	_title = Util.label("CHOMU CITY", 76, Color.WHITE)
	tv.add_child(_title)
	tv.add_child(Util.label("open-world demo  ·  v0.1", 24, Util.ACCENT))
	logo_row.add_child(tv)
	_menu_box.add_child(logo_row)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	_menu_box.add_child(spacer)

	_play_btn = Util.button("PLAY", 380, 84)
	_play_btn.add_theme_font_size_override("font_size", 34)
	_play_btn.pressed.connect(_on_play)
	_menu_box.add_child(_play_btn)
	var settings_btn := Util.button("SETTINGS", 380, 72)
	settings_btn.pressed.connect(_on_settings)
	_menu_box.add_child(settings_btn)
	var quit_btn := Util.button("QUIT", 380, 72)
	quit_btn.pressed.connect(func(): get_tree().quit())
	_menu_box.add_child(quit_btn)

	var foot := Util.label("Made with CHoMU Engine  ·  Assets: Kenney (CC0), Poly Haven (CC0), OpenGameArt (CC0)", 18, Color(1, 1, 1, 0.45))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	foot.position = Vector2(-20, -40)
	foot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(foot)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_settings = preload("res://scripts/SettingsPanel.gd").new()
	_settings.visible = false
	_settings.closed.connect(_on_settings_closed)
	center.add_child(_settings)

	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.6)

func _process(delta: float) -> void:
	_t += delta
	_bg.position.x = sin(_t * 0.15) * 20.0 - 20.0
	if Game.demo and _t > 3.2 and _play_btn and not _play_btn.disabled:
		_play_btn.disabled = true
		_play_btn.add_theme_stylebox_override("disabled", _play_btn.get_theme_stylebox("pressed"))
		get_tree().create_timer(0.5).timeout.connect(_on_play)

func _on_play() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.35)
	tw.tween_callback(Game.goto_world)

func _on_settings() -> void:
	_menu_box.visible = false
	_settings.visible = true

func _on_settings_closed() -> void:
	_settings.visible = false
	_menu_box.visible = true
