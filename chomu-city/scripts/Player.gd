extends CharacterBody3D
## Third-person player: camera-relative movement, sprint, jump,
## AnimationTree state machine (idle/walk/run blend + jump + fall), footsteps.

const WALK_SPEED := 2.8
const RUN_SPEED := 7.0
const JUMP_VELOCITY := 6.0
const GRAVITY := 18.0
const ACCEL := 10.0
const HEIGHT := 1.75

var active := true
var model: Node3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var _step_timer := 0.0
var _steps: Array[AudioStream] = []
var _step_player: AudioStreamPlayer3D
var _was_on_floor := true
var _jump_held := false
var speed_now := 0.0

func _ready() -> void:
	Game.player = self
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = HEIGHT
	cs.shape = cap
	cs.position.y = HEIGHT * 0.5
	add_child(cs)
	_build_model()
	for i in 5:
		var s := Util.load_audio("res://assets/audio/step_%d.ogg" % i)
		if s:
			_steps.append(s)
	_step_player = AudioStreamPlayer3D.new()
	_step_player.volume_db = -6.0
	_step_player.unit_size = 4.0
	add_child(_step_player)

func _build_model() -> void:
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	var path := Util.pick_model("player", Assets.PLAYER_MODEL)
	var m := Util.instance_model(path)
	model.add_child(m)
	var ab := Util.local_aabb(m)
	var s := HEIGHT / maxf(ab.size.y, 0.01)
	m.scale = Vector3.ONE * s
	m.position.y = -ab.position.y * s
	anim_player = Util.find_anim_player(m)
	if anim_player == null:
		return
	Util.set_loop(anim_player, ["idle", "walk", "sprint", "fall", "drive"])
	var sm := AnimationNodeStateMachine.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = RUN_SPEED
	for pair in [["idle", 0.0], ["walk", WALK_SPEED], ["sprint", RUN_SPEED]]:
		var an := AnimationNodeAnimation.new()
		an.animation = pair[0]
		loco.add_blend_point(an, pair[1], -1, pair[0])
	sm.add_node("loco", loco, Vector2(200, 100))
	for nm in ["jump", "fall"]:
		var an := AnimationNodeAnimation.new()
		an.animation = nm if anim_player.has_animation(nm) else "idle"
		sm.add_node(nm, an, Vector2(400, 100 if nm == "jump" else 250))
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", "loco", start)
	for pair in [["loco", "jump"], ["jump", "fall"], ["fall", "loco"], ["loco", "fall"], ["jump", "loco"]]:
		var tr := AnimationNodeStateMachineTransition.new()
		tr.xfade_time = 0.15
		sm.add_transition(pair[0], pair[1], tr)
	anim_tree = AnimationTree.new()
	anim_tree.tree_root = sm
	m.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	anim_tree.active = true
	playback = anim_tree.get("parameters/playback")

func set_active(on: bool) -> void:
	active = on
	visible = on
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = not on
	set_physics_process(on)
	velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not active:
		return
	var iv := Game.get_move_vector()
	var yaw := Game.cam_yaw
	var dir := Vector3(iv.x, 0, iv.y).rotated(Vector3.UP, yaw)
	var mag := clampf(iv.length(), 0.0, 1.0)
	var sprint := Game.is_btn("sprint")
	var target_speed := (RUN_SPEED if sprint else WALK_SPEED * (0.6 + 0.4 * mag) * 1.0) * mag
	if mag > 0.05 and dir.length() > 0.001:
		dir = dir.normalized()
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.lerp(dir * target_speed, clampf(ACCEL * delta, 0.0, 1.0))
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		var jp := Game.is_btn("jump")
		if jp and not _jump_held:
			velocity.y = JUMP_VELOCITY
			if playback:
				playback.travel("jump")
		_jump_held = jp
	else:
		velocity.y -= GRAVITY * delta
		_jump_held = Game.is_btn("jump")
	move_and_slide()
	speed_now = Vector3(velocity.x, 0, velocity.z).length()
	if speed_now > 0.3 and model:
		var face := atan2(velocity.x, velocity.z)
		model.rotation.y = lerp_angle(model.rotation.y, face, clampf(12.0 * delta, 0.0, 1.0))
	_update_anim()
	_footsteps(delta)
	if global_position.y < -20.0:
		global_position = Vector3(global_position.x, 3.0, global_position.z)
		velocity = Vector3.ZERO

func _update_anim() -> void:
	if anim_tree == null:
		return
	anim_tree.set("parameters/loco/blend_position", speed_now)
	var cur := playback.get_current_node()
	var on_floor := is_on_floor()
	if on_floor:
		if cur == "fall" or (cur == "jump" and velocity.y <= 0.0):
			playback.travel("loco")
	else:
		if cur == "loco" and velocity.y < -2.5:
			playback.travel("fall")
		elif cur == "jump" and velocity.y < -0.5:
			playback.travel("fall")
	_was_on_floor = on_floor

func _footsteps(delta: float) -> void:
	if not is_on_floor() or speed_now < 0.8 or _steps.is_empty():
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.28 if speed_now > 4.0 else 0.45
		_step_player.stream = _steps[randi() % _steps.size()]
		_step_player.pitch_scale = randf_range(0.9, 1.1)
		_step_player.play()

func teleport(p: Vector3, face_yaw := 0.0) -> void:
	global_position = p
	velocity = Vector3.ZERO
	if model:
		model.rotation.y = face_yaw
