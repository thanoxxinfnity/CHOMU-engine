extends VehicleBody3D
## Drivable car (VehicleBody3D). Builds itself from a Kenney Car Kit GLB:
## the model's wheel-* nodes are re-parented onto VehicleWheel3D nodes so they spin/steer.
## Forward is +Z (positive engine_force drives +Z, positive steering turns left).

@export var model_path := Assets.PLAYER_CAR
@export var target_width := 1.95
@export var max_engine_force := 5200.0
@export var max_brake := 28.0
@export var top_speed := 46.0            # m/s (~165 km/h)

var driven := false
var throttle := 0.0
var steer_input := 0.0
var _steer := 0.0
var _flip_timer := 0.0
var _engine: AudioStreamPlayer3D
var _sfx: AudioStreamPlayer3D
var _headlights: Array[SpotLight3D] = []
var _tail_mat: StandardMaterial3D
var model: Node3D
var wheels: Array[VehicleWheel3D] = []
var autopilot_steer := 0.0               # used by DemoDirector
var autopilot := false

func _ready() -> void:
	Game.player_car = self
	add_to_group("vehicle")
	mass = 1150.0
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.28, 0.1)
	angular_damp = 0.6
	linear_damp = 0.05
	continuous_cd = true
	can_sleep = false
	_build()
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = Util.load_audio(Assets.SFX.engine, true)
	_engine.volume_db = -8.0
	_engine.unit_size = 6.0
	add_child(_engine)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.unit_size = 8.0
	add_child(_sfx)
	Game.action.connect(_on_action)

func _build() -> void:
	model = Util.instance_model(Util.pick_model("hero_car", model_path))
	add_child(model)
	var body_node: Node3D = null
	var wheel_nodes: Array[Node3D] = []
	for c in model.get_children():
		if c is Node3D:
			if String(c.name).begins_with("wheel"):
				wheel_nodes.append(c)
			elif String(c.name) == "body":
				body_node = c
	var ab := Util.local_aabb(body_node if body_node else model)
	if body_node:
		ab = body_node.transform * Util.local_aabb(body_node)
	var s := target_width / maxf(ab.size.x, 0.01)
	model.scale = Vector3.ONE * s
	# collision box for the body, raised above the wheels
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var size := ab.size * s
	box.size = Vector3(size.x * 0.96, size.y * 0.62, size.z * 0.98)
	cs.shape = box
	cs.position = ab.get_center() * s + Vector3(0, size.y * 0.12, 0)
	add_child(cs)
	# wheels
	var rest := 0.18
	for wn in wheel_nodes:
		var w := VehicleWheel3D.new()
		var center := wn.position * s
		var wab := Util.local_aabb(wn)
		var radius := maxf(wab.size.y * 0.5 * s, 0.25)
		w.position = center + Vector3(0, rest + 0.1, 0)
		w.wheel_radius = radius
		w.wheel_rest_length = rest
		w.suspension_travel = 0.22
		w.suspension_stiffness = 55.0
		w.suspension_max_force = 12000.0
		w.damping_compression = 2.2
		w.damping_relaxation = 3.0
		w.wheel_roll_influence = 0.04
		var front := center.z > 0.0
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_friction_slip = 3.2 if front else 2.9
		add_child(w)
		var xf := wn.transform
		model.remove_child(wn)
		w.add_child(wn)
		wn.transform = Transform3D(xf.basis.scaled(Vector3.ONE * s), Vector3.ZERO)
		wheels.append(w)
	# tail lights (emissive) + headlights
	_tail_mat = StandardMaterial3D.new()
	_tail_mat.albedo_color = Color(0.5, 0.02, 0.02)
	_tail_mat.emission_enabled = true
	_tail_mat.emission = Color(1, 0.05, 0.03)
	_tail_mat.emission_energy_multiplier = 0.4
	var half_w := size.x * 0.5
	var back_z := ab.position.z * s
	var front_z := ab.end.z * s
	for sx in [-1.0, 1.0]:
		var tl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.38, 0.12, 0.04)
		tl.mesh = bm
		tl.material_override = _tail_mat
		tl.position = Vector3(sx * (half_w - 0.3), ab.get_center().y * s + 0.05, back_z - 0.02)
		tl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tl)
		var hl := SpotLight3D.new()
		hl.position = Vector3(sx * (half_w - 0.35), ab.get_center().y * s, front_z + 0.05)
		hl.rotation = Vector3(deg_to_rad(-6), PI, 0)    # spot shines along -Z, so flip to +Z
		hl.spot_range = 30.0
		hl.spot_angle = 32.0
		hl.light_energy = 0.0
		hl.light_color = Color(1, 0.95, 0.85)
		hl.shadow_enabled = false
		hl.visible = false
		add_child(hl)
		_headlights.append(hl)

func forward_dir() -> Vector3:
	return global_basis.z

func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6

func forward_speed() -> float:
	return linear_velocity.dot(global_basis.z)

func set_driven(on: bool) -> void:
	driven = on
	if on:
		_play(Assets.SFX.engine_start, -4.0)
		_engine.play()
	else:
		engine_force = 0.0
		_engine.stop()

func _on_action(a: String) -> void:
	if a == "horn" and driven:
		_play(Assets.SFX.horn, 0.0)

func play_door(open: bool) -> void:
	_play(Assets.SFX.door_open if open else Assets.SFX.door_close, -2.0)

func _play(path: String, vol: float) -> void:
	var s := Util.load_audio(path)
	if s:
		_sfx.stream = s
		_sfx.volume_db = vol
		_sfx.play()

func _physics_process(delta: float) -> void:
	var fs := forward_speed()
	var speed := linear_velocity.length()
	if driven:
		var gas := Game.is_btn("gas")
		var brk := Game.is_btn("brake")
		var steer_target := 0.0
		if autopilot:
			steer_target = autopilot_steer
		else:
			if Game.is_btn("left"):
				steer_target += 1.0
			if Game.is_btn("right"):
				steer_target -= 1.0
			if Game.tilt_steering and OS.has_feature("mobile"):
				var acc := Input.get_accelerometer()
				steer_target = clampf(-acc.y / 5.0, -1.0, 1.0) if absf(acc.y) > 0.6 else steer_target
		var max_steer := lerpf(0.6, 0.16, clampf(speed / 32.0, 0.0, 1.0))
		_steer = move_toward(_steer, steer_target * max_steer, delta * (2.2 if steer_target != 0.0 else 3.5))
		steering = _steer
		var ef := 0.0
		var br := 0.0
		if gas:
			ef = max_engine_force * clampf(1.0 - fs / top_speed, 0.0, 1.0)
			if fs < -1.0:
				br = max_brake
				ef = 0.0
		elif brk:
			if fs > 1.0:
				br = max_brake
			else:
				ef = -max_engine_force * 0.45 * clampf(1.0 + fs / 12.0, 0.0, 1.0)
		else:
			br = 1.2   # engine braking
		engine_force = ef
		brake = br
		var hb := Game.is_btn("handbrake")
		for w in wheels:
			if not w.use_as_steering:
				w.brake = 40.0 if hb else br
				w.wheel_friction_slip = 1.4 if hb else 2.9
		# engine sound pitch follows speed (simple 4-gear feel)
		var gear_speed := fmod(absf(fs), 13.0) / 13.0
		var gear := int(absf(fs) / 13.0)
		_engine.pitch_scale = 0.75 + gear_speed * 0.7 + gear * 0.08 + (0.15 if gas else 0.0)
		_engine.volume_db = -10.0 + (4.0 if gas else 0.0)
		_tail_mat.emission_energy_multiplier = 4.0 if br > 5.0 else (1.2 if _lights_on() else 0.3)
	else:
		engine_force = 0.0
		steering = move_toward(steering, 0.0, delta)
		brake = 6.0
	var night := _lights_on()
	for hl in _headlights:
		hl.visible = night and driven
		hl.light_energy = 3.0
	# auto-recover from flips
	if global_basis.y.dot(Vector3.UP) < 0.3 and speed < 2.0:
		_flip_timer += delta
		if _flip_timer > 2.0:
			reset_upright()
	else:
		_flip_timer = 0.0
	if global_position.y < -20.0:
		reset_upright()

func _lights_on() -> bool:
	return Game.day_night != null and Game.day_night.is_night()

func reset_upright() -> void:
	_flip_timer = 0.0
	var f := global_basis.z
	f.y = 0.0
	if f.length() < 0.1:
		f = Vector3.FORWARD
	var t := Transform3D(Basis.looking_at(-f.normalized(), Vector3.UP), global_position + Vector3(0, 1.5, 0))
	t.origin.y = maxf(t.origin.y, 1.5)
	global_transform = t
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
