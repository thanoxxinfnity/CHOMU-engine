extends Node3D
## AI traffic: kinematic cars (AnimatableBody3D) driving lane loops around blocks,
## slowing for corners and stopping for cars / the player ahead.

const CRUISE := 11.0
const CORNER := 5.5

class TrafficCar:
	var body: AnimatableBody3D
	var path: PackedVector3Array
	var seg_len: PackedFloat32Array
	var total := 0.0
	var s := 0.0
	var speed := 0.0
	var wheels: Array[Node3D] = []
	var wait := 0.0
	var engine: AudioStreamPlayer3D

var cars: Array = []
var city: Node

func setup(c: Node) -> void:
	city = c
	var loops := [
		[0, 0, 5, 5, true], [0, 0, 5, 5, false],
		[1, 1, 4, 4, true], [1, 1, 4, 4, false],
		[2, 2, 3, 3, true], [0, 2, 3, 5, false],
		[2, 0, 5, 3, true], [1, 0, 3, 2, false],
		[3, 3, 5, 5, true], [0, 3, 2, 5, true],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var idx := 0
	for lp in loops:
		var path: PackedVector3Array = city.lane_loop(lp[0], lp[1], lp[2], lp[3], lp[4])
		var count := 2 if (lp[2] - lp[0]) >= 3 else 1
		for n in count:
			var tc := _make_car(Assets.TRAFFIC_CARS[idx % Assets.TRAFFIC_CARS.size()], path)
			idx += 1
			tc.s = tc.total * (float(n) / count) + rng.randf() * 20.0
			_place(tc, 0.0)
			cars.append(tc)

func _make_car(model_path: String, path: PackedVector3Array) -> TrafficCar:
	var tc := TrafficCar.new()
	tc.path = path
	tc.seg_len = PackedFloat32Array()
	for k in path.size():
		var l := path[k].distance_to(path[(k + 1) % path.size()])
		tc.seg_len.append(l)
		tc.total += l
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = 4
	body.collision_mask = 0
	add_child(body)
	var m := Util.instance_model(model_path)
	var ab := Util.local_aabb(m)
	var sc := 1.95 / maxf(ab.size.x, 0.01)
	m.scale = Vector3.ONE * sc
	body.add_child(m)
	for c in m.get_children():
		if String(c.name).begins_with("wheel"):
			tc.wheels.append(c)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ab.size * sc * Vector3(0.95, 0.8, 0.97)
	cs.shape = box
	cs.position = ab.get_center() * sc + Vector3(0, 0.1, 0)
	body.add_child(cs)
	Util.set_visibility_range(m, 260.0)
	var eng := AudioStreamPlayer3D.new()
	eng.stream = Util.load_audio(Assets.SFX.engine, true)
	eng.volume_db = -16.0
	eng.unit_size = 3.0
	eng.max_distance = 35.0
	eng.pitch_scale = randf_range(0.7, 0.9)
	body.add_child(eng)
	tc.engine = eng
	tc.body = body
	return tc

func _point_at(tc: TrafficCar, s: float) -> Vector3:
	s = fposmod(s, tc.total)
	for k in tc.path.size():
		if s <= tc.seg_len[k]:
			return tc.path[k].lerp(tc.path[(k + 1) % tc.path.size()], s / tc.seg_len[k])
		s -= tc.seg_len[k]
	return tc.path[0]

func _dist_to_corner(tc: TrafficCar) -> float:
	var s := fposmod(tc.s, tc.total)
	for k in tc.path.size():
		if s <= tc.seg_len[k]:
			return tc.seg_len[k] - s
		s -= tc.seg_len[k]
	return 999.0

func _place(tc: TrafficCar, delta: float) -> void:
	var p := _point_at(tc, tc.s)
	var ahead := _point_at(tc, tc.s + 5.0)
	var behind := _point_at(tc, tc.s - 2.0)
	var dir := (ahead - behind)
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var b := Basis.looking_at(-dir.normalized(), Vector3.UP)   # +Z forward
	var cur := tc.body.global_transform
	var new_basis := b if delta == 0.0 else cur.basis.slerp(b, clampf(8.0 * delta, 0.0, 1.0)).orthonormalized()
	tc.body.global_transform = Transform3D(new_basis, Vector3(p.x, 0.0, p.z))

func _physics_process(delta: float) -> void:
	var player_pos := Vector3(9999, 0, 9999)
	if Game.driving and Game.player_car:
		player_pos = Game.player_car.global_position
	elif Game.player:
		player_pos = Game.player.global_position
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam else Vector3.ZERO
	for tc in cars:
		var pos: Vector3 = tc.body.global_position
		var fwd: Vector3 = tc.body.global_basis.z
		var target := CRUISE
		if _dist_to_corner(tc) < 14.0:
			target = CORNER
		# obstacle check
		var blocked := false
		for other in cars:
			if other == tc:
				continue
			var to: Vector3 = other.body.global_position - pos
			var d := to.length()
			if d < 11.0 and d > 0.1 and fwd.dot(to / d) > 0.6:
				blocked = true
				break
		var tp := player_pos - pos
		var dp := tp.length()
		if dp < 10.0 and dp > 0.1 and fwd.dot(tp / dp) > 0.55:
			blocked = true
		if blocked:
			tc.wait += delta
			if tc.wait < 4.0:
				target = 0.0
		else:
			tc.wait = 0.0
		tc.speed = move_toward(tc.speed, target, delta * (9.0 if target < tc.speed else 3.5))
		tc.s += tc.speed * delta
		_place(tc, delta)
		for w in tc.wheels:
			w.rotate_x(tc.speed * delta / 0.42)
		var near := pos.distance_to(cam_pos) < 40.0
		if near and not tc.engine.playing:
			tc.engine.play()
		elif not near and tc.engine.playing:
			tc.engine.stop()
		if near:
			tc.engine.pitch_scale = 0.7 + tc.speed / CRUISE * 0.35

func positions() -> Array:
	var out := []
	for tc in cars:
		out.append(tc.body.global_position)
	return out
