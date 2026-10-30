extends Node3D
## NPC pedestrians walking sidewalk loops around blocks with walk animation.
## Far-away pedestrians pause their animation to save CPU.

const SPEED := 1.35

class Ped:
	var node: Node3D
	var anim: AnimationPlayer
	var path: PackedVector3Array
	var seg := 0
	var t := 0.0
	var speed := 1.3
	var idle := 0.0

var peds: Array = []

func setup(city: Node, count := 18) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for n in count:
		var i := rng.randi() % 5
		var j := rng.randi() % 5
		var p := Ped.new()
		p.path = city.sidewalk_loop(i, j, rng.randf() < 0.5)
		# small sideways offset so pedestrians don't walk in a single file
		var off := rng.randf_range(-0.8, 0.8)
		var c: Vector3 = city.block_center(i, j)
		for k in p.path.size():
			p.path[k] += (p.path[k] - c).normalized() * off
		p.seg = rng.randi() % 4
		p.t = rng.randf()
		p.speed = SPEED * rng.randf_range(0.8, 1.2)
		var root := Node3D.new()
		add_child(root)
		var m := Util.instance_model(Assets.CHARACTERS[n % Assets.CHARACTERS.size()])
		var ab := Util.local_aabb(m)
		var h := rng.randf_range(1.6, 1.8)
		var s := h / maxf(ab.size.y, 0.01)
		m.scale = Vector3.ONE * s
		root.add_child(m)
		Util.set_visibility_range(m, 110.0)
		p.node = root
		p.anim = Util.find_anim_player(m)
		if p.anim:
			Util.set_loop(p.anim, ["walk", "idle"])
			p.anim.play("walk")
			p.anim.speed_scale = p.speed / 1.3
		peds.append(p)
		_place(p, 1.0)

func _place(p: Ped, delta: float) -> void:
	var a: Vector3 = p.path[p.seg]
	var b: Vector3 = p.path[(p.seg + 1) % p.path.size()]
	var pos := a.lerp(b, p.t)
	p.node.global_position = pos
	var dir := b - a
	var yaw := atan2(dir.x, dir.z)
	p.node.rotation.y = lerp_angle(p.node.rotation.y, yaw, clampf(6.0 * delta, 0.0, 1.0))

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var cp := cam.global_position if cam else Vector3.ZERO
	var threat := Vector3(9999, 0, 9999)
	if Game.driving and Game.player_car:
		threat = Game.player_car.global_position
	for p in peds:
		var far: bool = p.node.global_position.distance_squared_to(cp) > 120.0 * 120.0
		if p.anim:
			p.anim.active = not far
		# step aside / wait if the player's car is right next to them
		if p.node.global_position.distance_to(threat) < 4.0:
			if p.anim and p.anim.current_animation != "idle":
				p.anim.play("idle")
			continue
		elif p.anim and p.anim.current_animation != "walk":
			p.anim.play("walk")
		var a: Vector3 = p.path[p.seg]
		var b: Vector3 = p.path[(p.seg + 1) % p.path.size()]
		var l: float = maxf(a.distance_to(b), 0.01)
		p.t += p.speed * delta / l
		if p.t >= 1.0:
			p.t -= 1.0
			p.seg = (p.seg + 1) % p.path.size()
		if not far or Engine.get_process_frames() % 10 == 0:
			_place(p, delta * (1.0 if not far else 10.0))

func positions() -> Array:
	var out := []
	for p in peds:
		out.append(p.node.global_position)
	return out
