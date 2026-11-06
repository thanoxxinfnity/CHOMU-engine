extends Node
## ChomuReplay (autoload) - F-68 deterministic replay.
## Records, per physics tick, the state of every tracked InputMap action plus
## optional custom values (mouse look, analog sticks), and the RNG seed. Playback
## re-seeds the RNG and injects the same action states at the start of each
## physics tick (this node runs at physics priority -1000, before gameplay).
## Gameplay calls ChomuReplay.checksum(value) each tick; during playback the
## recorded checksums are compared and the first divergent tick is reported
## (desync forensics, F-37-lite).
##
## Determinism contract for your game: put gameplay in _physics_process, draw
## randomness only from ChomuReplay.rng (or global randf after the reseed),
## read analog values through get_custom(), and keep physics_ticks_per_second fixed.

signal recording_started(seed: int)
signal playback_started(seed: int, frames: int)
signal playback_finished(matched: bool)
signal desync(frame: int, expected: int, got: int)

enum Mode { IDLE, RECORDING, PLAYBACK }

var mode: int = Mode.IDLE
var rng := RandomNumberGenerator.new()
var seed_value := 0
var frame := -1
var frames: Array = []       ## per tick: {"a": {action: strength}, "c": {key: value}}
var checksums: PackedInt64Array = PackedInt64Array()
var tracked_actions: Array[StringName] = []
var include_ui_actions := false
var desync_frame := -1
var _pressed_by_us := {}
var _cur := {}

func _ready() -> void:
	process_physics_priority = -1000
	process_priority = -1000
	process_mode = Node.PROCESS_MODE_ALWAYS

func _collect_actions() -> void:
	tracked_actions.clear()
	for a in InputMap.get_actions():
		if not include_ui_actions and String(a).begins_with("ui_"):
			continue
		tracked_actions.append(a)

func start_recording(p_seed: int = -1, actions: Array[StringName] = []) -> void:
	if actions.is_empty():
		_collect_actions()
	else:
		tracked_actions = actions.duplicate()
	seed_value = p_seed if p_seed >= 0 else int(Time.get_ticks_usec() % 2147483647)
	_reseed()
	frames.clear()
	checksums.clear()
	frame = -1
	desync_frame = -1
	mode = Mode.RECORDING
	recording_started.emit(seed_value)

func stop() -> void:
	if mode == Mode.PLAYBACK:
		_release_all()
		playback_finished.emit(desync_frame < 0)
	mode = Mode.IDLE

func start_playback() -> void:
	if frames.is_empty():
		push_warning("ChomuReplay: nothing recorded")
		return
	_reseed()
	frame = -1
	desync_frame = -1
	mode = Mode.PLAYBACK
	playback_started.emit(seed_value, frames.size())

func _reseed() -> void:
	seed(seed_value)
	rng.seed = seed_value
	rng.state = 0
	rng.seed = seed_value

func is_recording() -> bool:
	return mode == Mode.RECORDING

func is_playing() -> bool:
	return mode == Mode.PLAYBACK

func _physics_process(_delta: float) -> void:
	match mode:
		Mode.RECORDING:
			frame += 1
			var acts := {}
			for a in tracked_actions:
				if Input.is_action_pressed(a):
					acts[a] = Input.get_action_strength(a)
			_cur = {"a": acts, "c": {}}
			frames.append(_cur)
		Mode.PLAYBACK:
			frame += 1
			if frame >= frames.size():
				stop()
				return
			_cur = frames[frame]
			var acts: Dictionary = _cur["a"]
			for a in tracked_actions:
				if acts.has(a):
					Input.action_press(a, float(acts[a]))
					_pressed_by_us[a] = true
				elif _pressed_by_us.has(a):
					Input.action_release(a)
					_pressed_by_us.erase(a)

func _release_all() -> void:
	for a in _pressed_by_us:
		Input.action_release(a)
	_pressed_by_us.clear()

## Custom per-tick value (e.g. mouse delta). Records while recording, returns the
## recorded value during playback, and passes `live` through otherwise.
func custom(key: String, live: Variant) -> Variant:
	match mode:
		Mode.RECORDING:
			if not _cur.is_empty():
				(_cur["c"] as Dictionary)[key] = live
			return live
		Mode.PLAYBACK:
			if not _cur.is_empty():
				return (_cur["c"] as Dictionary).get(key, live)
	return live

## Feed gameplay state each tick (position, hp...). Returns the hash used.
func checksum(value: Variant) -> int:
	var h := hash(var_to_str(value))
	if mode == Mode.RECORDING:
		while checksums.size() < frame:
			checksums.append(0)
		if checksums.size() == frame:
			checksums.append(h)
		else:
			checksums[frame] = h
	elif mode == Mode.PLAYBACK and frame >= 0 and frame < checksums.size():
		if checksums[frame] != h and desync_frame < 0:
			desync_frame = frame
			desync.emit(frame, checksums[frame], h)
	return h

func frame_count() -> int:
	return frames.size()

func save_to(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_var({"version": 1, "seed": seed_value, "actions": tracked_actions, "frames": frames, "checksums": checksums,
		"tps": Engine.physics_ticks_per_second})
	return OK

func load_from(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return FileAccess.get_open_error()
	var d: Dictionary = f.get_var()
	seed_value = d["seed"]
	tracked_actions.clear()
	for a in d["actions"]:
		tracked_actions.append(StringName(a))
	frames = d["frames"]
	checksums = d["checksums"]
	if int(d.get("tps", Engine.physics_ticks_per_second)) != Engine.physics_ticks_per_second:
		push_warning("ChomuReplay: recorded at a different physics tick rate; playback will not match")
	return OK
