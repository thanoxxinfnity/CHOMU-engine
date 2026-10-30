extends PanelContainer
## Reusable settings panel (used by Main Menu and Pause menu).

signal closed

var _quality_buttons: Array[Button] = []
var _sens_label: Label
var _vol_label: Label

func _ready() -> void:
	theme = Util.make_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(760, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	add_child(v)
	v.add_child(Util.label("SETTINGS", 40, Util.ACCENT))

	v.add_child(Util.label("Graphics preset", 24))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 10)
	v.add_child(qrow)
	for i in Game.QUALITY_NAMES.size():
		var b := Util.button(Game.QUALITY_NAMES[i], 165, 64)
		b.toggle_mode = true
		b.pressed.connect(_on_quality.bind(i))
		qrow.add_child(b)
		_quality_buttons.append(b)
	var hint := Util.label("Low = best battery  ·  Ultra = max effects (desktop extras: SSAO, volumetric fog)", 18, Color(1, 1, 1, 0.55))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(hint)

	_sens_label = Util.label("", 24)
	v.add_child(_sens_label)
	var sens := HSlider.new()
	sens.min_value = 0.3
	sens.max_value = 2.5
	sens.step = 0.05
	sens.value = Game.cam_sensitivity
	sens.custom_minimum_size = Vector2(0, 44)
	sens.value_changed.connect(func(val): Game.cam_sensitivity = val; _refresh())
	v.add_child(sens)

	_vol_label = Util.label("", 24)
	v.add_child(_vol_label)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Game.master_volume
	vol.custom_minimum_size = Vector2(0, 44)
	vol.value_changed.connect(func(val): Game.master_volume = val; Game.apply_volume(); _refresh())
	v.add_child(vol)

	var tilt := CheckButton.new()
	tilt.text = "Tilt steering (phone accelerometer)"
	tilt.button_pressed = Game.tilt_steering
	tilt.focus_mode = Control.FOCUS_NONE
	tilt.toggled.connect(func(on): Game.tilt_steering = on)
	v.add_child(tilt)

	var fps := CheckButton.new()
	fps.text = "Show FPS counter"
	fps.button_pressed = Game.show_fps
	fps.focus_mode = Control.FOCUS_NONE
	fps.toggled.connect(func(on): Game.show_fps = on; Game.emit_signal("settings_changed"))
	v.add_child(fps)

	var back := Util.button("Back", 300, 68)
	back.pressed.connect(_on_back)
	v.add_child(back)
	_refresh()

func _on_quality(i: int) -> void:
	Game.set_quality(i)
	_refresh()

func _on_back() -> void:
	Game.save_settings()
	Game.emit_signal("settings_changed")
	emit_signal("closed")

func _refresh() -> void:
	for i in _quality_buttons.size():
		_quality_buttons[i].button_pressed = (i == Game.quality)
	_sens_label.text = "Camera sensitivity: %.2f" % Game.cam_sensitivity
	_vol_label.text = "Volume: %d%%" % int(Game.master_volume * 100)
