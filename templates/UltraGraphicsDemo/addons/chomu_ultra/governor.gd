extends Node
## CHoMU Ultra adaptive governor.
## Every `sample_seconds` it measures the real frame rate. If it stays below `target_fps * tolerance` for
## `bad_samples_needed` samples in a row it lowers the 3D render scale by `step`; once at `min_scale` it drops
## to the next lower preset (Mobile Ultra -> Medium -> Low). It never steps back up on its own (no ping-pong);
## call reset() after a heavy scene ends if you want it to try higher quality again.

signal stepped_down(what: String)

@export var target_fps := 60.0
@export var tolerance := 0.88
@export var sample_seconds := 2.0
@export var bad_samples_needed := 2
@export var min_scale := 0.6
@export var step := 0.05
@export var allow_preset_drop := true
@export var warmup_seconds := 4.0

var _acc := 0.0
var _frames := 0
var _bad := 0
var _cool := 0.0

func _ready() -> void:
	_cool = warmup_seconds
	process_mode = Node.PROCESS_MODE_ALWAYS

func reset() -> void:
	_bad = 0
	_acc = 0.0
	_frames = 0
	_cool = warmup_seconds

func _process(delta: float) -> void:
	if _cool > 0.0:
		_cool -= delta
		return
	_acc += delta
	_frames += 1
	if _acc < sample_seconds:
		return
	var fps := float(_frames) / _acc
	_acc = 0.0
	_frames = 0
	# A frame cap (Engine.max_fps) below target would look like "slow": respect the cap.
	var goal := target_fps
	if Engine.max_fps > 0:
		goal = minf(goal, float(Engine.max_fps))
	_bad = _bad + 1 if fps < goal * tolerance else 0
	if _bad >= bad_samples_needed:
		_bad = 0
		_cool = 3.0
		_step_down(fps)

func _step_down(fps: float) -> void:
	var vp := get_viewport()
	if vp.scaling_3d_scale - step >= min_scale - 0.001:
		vp.scaling_3d_scale = snappedf(vp.scaling_3d_scale - step, 0.01)
		stepped_down.emit("scale %.2f (%.0f fps)" % [vp.scaling_3d_scale, fps])
		print("CHoMU Ultra governor: %.0f fps -> render scale %.2f" % [fps, vp.scaling_3d_scale])
		return
	if not allow_preset_drop:
		return
	var api: GDScript = load("res://addons/chomu_ultra/chomu_ultra.gd")
	var presets: GDScript = load("res://addons/chomu_ultra/presets.gd")
	var cur := str(api.get("current_preset"))
	if cur == "" or cur == "Low":
		return
	var lower := str(presets.call("lower_of", cur))
	api.call("apply", lower)
	stepped_down.emit("preset %s (%.0f fps)" % [lower, fps])
	print("CHoMU Ultra governor: %.0f fps -> preset %s" % [fps, lower])
