extends Node
## Global game state (autoload "Game").
## Touch controls write into the input fields below; Player / Car read them
## together with keyboard / gamepad actions so desktop testing also works.

signal quality_changed(level: int)
signal settings_changed
signal action(name: String)          # "enter", "horn", "pause", "camera"

const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
const SETTINGS_PATH := "user://settings.cfg"
const WORLD_SCENE := "res://scenes/World.tscn"
const MENU_SCENE := "res://scenes/MainMenu.tscn"
const LOADING_SCENE := "res://scenes/Loading.tscn"

# ---- settings (persisted) ----
var quality: int = 1
var cam_sensitivity: float = 1.0
var tilt_steering: bool = false
var show_fps: bool = false
var master_volume: float = 0.8

# ---- per-frame virtual input (filled by TouchControls / DemoDirector) ----
var move := Vector2.ZERO          # x = right, y = back (same as Input.get_vector)
var look_delta := Vector2.ZERO    # pixels dragged since last camera update
var btn := {"jump": false, "sprint": false, "gas": false, "brake": false,
		"left": false, "right": false, "handbrake": false}

# ---- runtime references ----
var player: Node3D
var player_car: Node3D
var camera_rig: Node3D
var day_night: Node
var world: Node3D
var driving := false
var near_car := false
var cam_yaw := 0.0                # current camera yaw (radians), for movement + minimap

# ---- demo / autopilot (for gameplay recording: run with  -- --demo) ----
var demo := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a == "--demo":
			demo = true
	_setup_input_map()
	load_settings()
	if demo:
		quality = 2

func _setup_input_map() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "enter_car": [KEY_F, KEY_E],
		"horn": [KEY_H], "pause": [KEY_ESCAPE, KEY_P], "handbrake": [KEY_CTRL],
	}
	for action_name in map:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for k in map[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action_name, ev)
	var pads := {"jump": JOY_BUTTON_A, "enter_car": JOY_BUTTON_Y, "sprint": JOY_BUTTON_LEFT_STICK, "pause": JOY_BUTTON_START}
	for action_name in pads:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pads[action_name]
		InputMap.action_add_event(action_name, jb)

func get_move_vector() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	v += move
	if v.length() > 1.0:
		v = v.normalized()
	return v

func is_btn(name: String) -> bool:
	match name:
		"jump": return btn.jump or Input.is_action_pressed("jump")
		"sprint": return btn.sprint or Input.is_action_pressed("sprint")
		"gas": return btn.gas or Input.is_action_pressed("move_forward")
		"brake": return btn.brake or Input.is_action_pressed("move_back")
		"left": return btn.left or Input.is_action_pressed("move_left")
		"right": return btn.right or Input.is_action_pressed("move_right")
		"handbrake": return btn.handbrake or Input.is_action_pressed("handbrake")
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("enter_car"):
		emit_signal("action", "enter")
	elif event.is_action_pressed("horn"):
		emit_signal("action", "horn")
	elif event.is_action_pressed("pause"):
		emit_signal("action", "pause")

func reset_virtual_input() -> void:
	move = Vector2.ZERO
	look_delta = Vector2.ZERO
	for k in btn:
		btn[k] = false

# ---------------- settings ----------------
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		quality = int(cfg.get_value("graphics", "quality", default_quality()))
		cam_sensitivity = float(cfg.get_value("controls", "sensitivity", 1.0))
		tilt_steering = bool(cfg.get_value("controls", "tilt", false))
		show_fps = bool(cfg.get_value("display", "fps", false))
		master_volume = float(cfg.get_value("audio", "volume", 0.8))
	else:
		quality = default_quality()
	apply_volume()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("controls", "sensitivity", cam_sensitivity)
	cfg.set_value("controls", "tilt", tilt_steering)
	cfg.set_value("display", "fps", show_fps)
	cfg.set_value("audio", "volume", master_volume)
	cfg.save(SETTINGS_PATH)

func default_quality() -> int:
	# Phones start on Medium, desktops on High.
	return 1 if OS.has_feature("mobile") else 2

func set_quality(q: int) -> void:
	quality = clampi(q, 0, 3)
	save_settings()
	emit_signal("quality_changed", quality)

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.001)))

func is_forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"

func goto_world() -> void:
	get_tree().change_scene_to_file(LOADING_SCENE)

func goto_menu() -> void:
	get_tree().paused = false
	driving = false
	reset_virtual_input()
	get_tree().change_scene_to_file(MENU_SCENE)
