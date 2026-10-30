extends Node3D
## Smooth third-person / chase camera with SpringArm3D collision.
## Swipe (touch) or mouse drag orbits; auto-follows behind the car while driving.

var target: Node3D
var yaw := 0.0
var pitch := -0.32
var pitch_node: Node3D
var arm: SpringArm3D
var camera: Camera3D
var _idle_look := 10.0
var _arm_len := 4.2
var _fov := 70.0

func _ready() -> void:
	Game.camera_rig = self
	pitch_node = Node3D.new()
	add_child(pitch_node)
	arm = SpringArm3D.new()
	arm.spring_length = _arm_len
	arm.margin = 0.25
	arm.collision_mask = 1
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	arm.shape = sphere
	pitch_node.add_child(arm)
	camera = Camera3D.new()
	camera.fov = _fov
	camera.near = 0.08
	camera.far = 460.0
	camera.current = true
	arm.add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	# Desktop convenience: right mouse drag also orbits (touch is handled by TouchControls)
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		Game.look_delta += event.relative

func _process(delta: float) -> void:
	if target == null:
		return
	var driving := Game.driving
	# orbit input
	var ld := Game.look_delta
	Game.look_delta = Vector2.ZERO
	var sens := 0.0045 * Game.cam_sensitivity
	if ld.length_squared() > 0.0:
		yaw -= ld.x * sens
		pitch = clampf(pitch - ld.y * sens, -1.2, 0.35)
		_idle_look = 0.0
	else:
		_idle_look += delta
	# gamepad right stick
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() > 0.2:
		yaw -= rs.x * 2.5 * delta * Game.cam_sensitivity
		pitch = clampf(pitch - rs.y * 1.5 * delta, -1.2, 0.35)
		_idle_look = 0.0

	var focus: Vector3
	if driving and target.has_method("forward_dir"):
		var fwd: Vector3 = target.forward_dir()
		var spd: float = target.get_speed_kmh() if target.has_method("get_speed_kmh") else 0.0
		focus = target.global_position + Vector3(0, 1.4, 0)
		if _idle_look > 1.2 and spd > 5.0:
			var want := atan2(-fwd.x, -fwd.z)     # camera behind the car
			yaw = lerp_angle(yaw, want, clampf(2.5 * delta, 0.0, 1.0))
			pitch = lerpf(pitch, -0.22, clampf(1.5 * delta, 0.0, 1.0))
		_arm_len = lerpf(_arm_len, 7.0 + clampf(spd / 30.0, 0.0, 2.5), clampf(3.0 * delta, 0.0, 1.0))
		_fov = lerpf(_fov, 70.0 + clampf(spd / 6.0, 0.0, 16.0), clampf(2.0 * delta, 0.0, 1.0))
	else:
		focus = target.global_position + Vector3(0, 1.55, 0)
		# gentle auto-follow behind the player when running and not touching the camera
		var pv: Vector3 = target.velocity if "velocity" in target else Vector3.ZERO
		var hv := Vector3(pv.x, 0, pv.z)
		if _idle_look > 1.0 and hv.length() > 1.5:
			var want := atan2(-hv.x, -hv.z)
			yaw = lerp_angle(yaw, want, clampf(1.2 * delta, 0.0, 1.0))
		_arm_len = lerpf(_arm_len, 4.2, clampf(3.0 * delta, 0.0, 1.0))
		_fov = lerpf(_fov, 70.0, clampf(2.0 * delta, 0.0, 1.0))
	global_position = global_position.lerp(focus, clampf(14.0 * delta, 0.0, 1.0)) if global_position.distance_to(focus) < 15.0 else focus
	rotation = Vector3(0, yaw, 0)
	pitch_node.rotation = Vector3(pitch, 0, 0)
	arm.spring_length = _arm_len
	camera.fov = _fov
	Game.cam_yaw = yaw

func snap_to_target() -> void:
	if target:
		global_position = target.global_position + Vector3(0, 1.5, 0)

func set_excludes(bodies: Array) -> void:
	arm.clear_excluded_objects()
	for b in bodies:
		if b is CollisionObject3D:
			arm.add_excluded_object(b.get_rid())
