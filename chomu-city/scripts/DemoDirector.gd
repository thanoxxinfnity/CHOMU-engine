extends Node
## Scripted autopilot used for the gameplay recording (run with  -- --demo).
## Feeds the same virtual inputs the touch controls use, so everything shown
## is the real game logic: walking, running, jumping, entering + driving the car,
## and the day -> night transition (time sped up while driving).

var t := 0.0
var phase := "intro"
var world: Node
var route: PackedVector3Array
var wp := 3
var _captions := {}
var _shots := [8.0, 34.0, 62.0]
var _shot_i := 0
var end_time := 74.0
var _exit_t := -1.0

func _ready() -> void:
	world = get_parent()
	process_priority = -10
	route = world.city.lane_loop(2, 1, 4, 3, true)

func _caption(key: String, text: String, secs := 3.0) -> void:
	if _captions.has(key):
		return
	_captions[key] = true
	world.hud.show_caption(text, secs)

func _walk_to(target: Vector3, run: bool) -> float:
	var p: Vector3 = world.player.global_position
	var d := target - p
	d.y = 0.0
	var dist := d.length()
	if dist < 0.6:
		Game.move = Vector2.ZERO
		return dist
	var dir := d.normalized().rotated(Vector3.UP, -Game.cam_yaw)
	Game.move = Vector2(dir.x, dir.z) * (1.0 if run else 0.75)
	Game.btn.sprint = run
	return dist

func _physics_process(delta: float) -> void:
	t += delta
	if int(t * 60.0) % 150 == 0:
		print("[demo] t=%.1f phase=%s player=%s car=%s kmh=%.0f hour=%.2f wp=%d up=%.2f" % [t, phase, world.player.global_position.snapped(Vector3.ONE * 0.1), world.car.global_position.snapped(Vector3.ONE * 0.1), world.car.get_speed_kmh(), world.day_night.hour, wp, world.car.global_basis.y.y])
	if _shot_i < _shots.size() and t >= _shots[_shot_i]:
		_shot_i += 1
		var img := get_viewport().get_texture().get_image()
		if img:
			img.save_png("user://screenshot_%d.png" % _shot_i)
	match phase:
		"intro":
			_caption("hi", "CHOMU CITY  -  open-world demo", 3.5)
			# cinematic orbit that ends behind the player
			Game.camera_rig.yaw = lerpf(-2.6, 0.0, smoothstep(0.0, 4.0, t))
			Game.camera_rig.pitch = lerpf(-0.12, -0.3, smoothstep(0.0, 4.0, t))
			if t > 4.0:
				phase = "walk"
		"walk":
			_caption("walk", "Walking the streets", 2.5)
			if _walk_to(Vector3(-30.0, 0, 52.0), false) < 1.0 or t > 11.0:
				phase = "run"
		"run":
			_caption("run", "Sprint + jump", 2.5)
			Game.btn.jump = fmod(t, 3.0) < 0.15 and t > 13.0
			if _walk_to(Vector3(-30.0, 0, 24.0), true) < 1.2 or t > 19.5:
				phase = "to_car"
				Game.btn.jump = false
		"to_car":
			_caption("car", "Hop in!", 2.0)
			var door: Vector3 = world.car.global_position + world.car.global_basis.x * 1.8
			if _walk_to(door, true) < 1.4 or t > 27.0:
				Game.move = Vector2.ZERO
				Game.btn.sprint = false
				Game.emit_signal("action", "enter")
				phase = "drive"
				world.car.autopilot = true
				world.day_night.time_scale = 1.8
		"drive":
			_caption("drive", "Driving  -  watch the sun go down", 3.0)
			_drive(delta)
			if world.day_night.is_night():
				_caption("night", "Night falls - street lights on", 3.0)
			if world.day_night.hour > 20.3 or world.day_night.hour < 6.0:
				world.day_night.time_scale = 0.3
			if t > 62.0:
				phase = "park"
		"park":
			Game.btn.gas = false
			Game.btn.brake = true
			world.car.autopilot_steer = 0.0
			if world.car.get_speed_kmh() < 3.0:
				Game.btn.brake = false
				Game.emit_signal("action", "enter")
				phase = "outro"
				_exit_t = t
		"outro":
			_caption("outro", "Chomu City v0.1  -  CHoMU Engine", 4.0)
			Game.look_delta.x += 1.6
			var p: Vector3 = world.player.global_position
			_walk_to(p + world.car.global_basis.x * 5.0, false)
			if t - _exit_t > 2.0:
				Game.move = Vector2.ZERO
			if t > end_time:
				get_tree().quit()

func _route_point(seg: int, dist_along: float) -> Vector3:
	# walk forward along the route polyline from segment seg
	var n := route.size()
	var k := seg
	var d := dist_along
	for guard in n + 1:
		var a: Vector3 = route[k % n]
		var b: Vector3 = route[(k + 1) % n]
		var l := a.distance_to(b)
		if d <= l:
			return a.lerp(b, d / l)
		d -= l
		k += 1
	return route[k % n]

func _drive(_delta: float) -> void:
	var car: VehicleBody3D = world.car
	var n := route.size()
	var a: Vector3 = route[wp % n]
	var b: Vector3 = route[(wp + 1) % n]
	var ab := b - a
	ab.y = 0.0
	var pos := car.global_position
	pos.y = 0.0
	var proj := clampf((pos - a).dot(ab.normalized()), 0.0, ab.length())
	if proj >= ab.length() - 0.5:
		wp = (wp + 1) % n
		return
	var speed := car.linear_velocity.length()
	var look := 7.0 + speed * 0.6
	var target := _route_point(wp, proj + look)
	var local := car.global_transform.affine_inverse() * target
	var ang := atan2(local.x, local.z)          # >0 means target on the left
	car.autopilot_steer = clampf(ang * 2.4, -1.0, 1.0)
	var to_corner := ab.length() - proj
	var want := 17.0 if to_corner > 40.0 else 7.0
	# brake for traffic ahead
	for p in world.traffic.positions():
		var lp: Vector3 = car.global_transform.affine_inverse() * p
		if lp.z > 0.0 and lp.z < 16.0 and absf(lp.x) < 2.6:
			want = 0.0
	Game.btn.gas = speed < want
	Game.btn.brake = speed > want + 2.5
