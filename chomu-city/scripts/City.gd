extends Node3D
## Procedural city: 400 x 400 m road grid (6 x 6 roads, 25 blocks), sidewalks,
## buildings (Kenney City Kits), street lights (MultiMesh + pooled lights),
## trees, props and collision. Everything is generated at load time.

const CELL := 80.0
const ROAD_HALF := 7.0
const SIDEWALK := 4.0
const N_BLOCKS := 5
const HALF := 200.0             # half city size (outer road centre lines at +-200)
const CURB_H := 0.16
const LANE := 4.7               # traffic lane offset from road centre (right-hand traffic)
const LAMP_SCALE := 10.0

var roads: Array[float] = []    # centre-line coordinates of roads (both axes)
var lamp_bulbs: PackedVector3Array = PackedVector3Array()
var _bulb_mat: StandardMaterial3D
var _lights: Array[OmniLight3D] = []
var _light_timer := 0.0
var _night := 0.0
var _building_geoms: Array[Node] = []
var _rng := RandomNumberGenerator.new()
var _concrete_mat: StandardMaterial3D
var _grass_mat: StandardMaterial3D

func _ready() -> void:
	_rng.seed = 7
	for i in N_BLOCKS + 1:
		roads.append(-HALF + CELL * i)
	_make_materials()
	_build_ground()
	_build_blocks()
	_build_buildings()
	_build_street_lights()
	_build_trees()
	_build_props()
	_build_bounds()
	Game.quality_changed.connect(apply_quality)
	apply_quality(Game.quality)

# ------------------------------------------------------------------ materials
func _make_materials() -> void:
	_concrete_mat = StandardMaterial3D.new()
	_concrete_mat.albedo_texture = load("res://assets/textures/concrete.jpg")
	_concrete_mat.normal_enabled = true
	_concrete_mat.normal_texture = load("res://assets/textures/concrete_n.jpg")
	_concrete_mat.normal_scale = 0.7
	_concrete_mat.uv1_triplanar = true
	_concrete_mat.uv1_world_triplanar = true
	_concrete_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	_concrete_mat.albedo_color = Color(0.85, 0.85, 0.85)
	_concrete_mat.roughness = 0.9
	_concrete_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_grass_mat = StandardMaterial3D.new()
	_grass_mat.albedo_texture = load("res://assets/textures/grass.jpg")
	_grass_mat.uv1_triplanar = true
	_grass_mat.uv1_world_triplanar = true
	_grass_mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
	_grass_mat.roughness = 1.0
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.albedo_color = Color(1.0, 0.95, 0.8)
	_bulb_mat.emission_enabled = true
	_bulb_mat.emission = Color(1.0, 0.82, 0.55)
	_bulb_mat.emission_energy_multiplier = 0.0
	_bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

# ------------------------------------------------------------------ ground
func _build_ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1200, 1200)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/ground.gdshader")
	sm.set_shader_parameter("asphalt_tex", load("res://assets/textures/asphalt.jpg"))
	sm.set_shader_parameter("asphalt_nrm", load("res://assets/textures/asphalt_n.jpg"))
	sm.set_shader_parameter("grass_tex", load("res://assets/textures/grass.jpg"))
	sm.set_shader_parameter("cell", CELL)
	sm.set_shader_parameter("road_half", ROAD_HALF)
	sm.set_shader_parameter("city_half", HALF)
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Ground"
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)

# ------------------------------------------------------------------ blocks / sidewalks
func block_center(i: int, j: int) -> Vector3:
	return Vector3(-HALF + CELL * 0.5 + CELL * i, 0, -HALF + CELL * 0.5 + CELL * j)

func block_kind(i: int, j: int) -> String:
	if (i == 0 or i == 4) and (j == 0 or j == 4):
		return "suburban"
	if i == 3 and j == 1:
		return "park"
	if absi(i - 2) + absi(j - 2) <= 1:
		return "downtown"
	return "commercial"

func _build_blocks() -> void:
	var size := CELL - ROAD_HALF * 2.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size, CURB_H, size)
	var inner := BoxMesh.new()
	inner.size = Vector3(size - SIDEWALK * 2.0, 0.02, size - SIDEWALK * 2.0)
	var body := StaticBody3D.new()
	body.name = "Sidewalks"
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	for i in N_BLOCKS:
		for j in N_BLOCKS:
			var c := block_center(i, j)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = _concrete_mat
			mi.position = c + Vector3(0, CURB_H * 0.5, 0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			var kind := block_kind(i, j)
			if kind == "park" or kind == "suburban":
				var g := MeshInstance3D.new()
				g.mesh = inner
				g.material_override = _grass_mat
				g.position = c + Vector3(0, CURB_H + 0.011, 0)
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(g)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = c + Vector3(0, CURB_H * 0.5, 0)
			body.add_child(cs)

# ------------------------------------------------------------------ buildings
func _place_building(path: String, pos: Vector3, yaw: float, footprint: float, max_scale := 40.0) -> void:
	var node := Util.instance_model(path)
	var ab := Util.local_aabb(node)
	var fp := maxf(ab.size.x, ab.size.z)
	var s := minf(footprint / maxf(fp, 0.01), max_scale)
	node.scale = Vector3.ONE * s
	node.rotation.y = yaw
	node.position = pos + Vector3(0, CURB_H, 0)
	add_child(node)
	_building_geoms.append(node)
	var body := StaticBody3D.new()
	body.position = node.position
	body.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ab.size * s
	cs.shape = box
	cs.position = ab.get_center() * s
	body.add_child(cs)
	add_child(body)

func _build_buildings() -> void:
	var q := (CELL - ROAD_HALF * 2.0) * 0.5 - SIDEWALK   # lot half size (29 m)
	for i in N_BLOCKS:
		for j in N_BLOCKS:
			var c := block_center(i, j)
			var kind := block_kind(i, j)
			if kind == "park":
				continue
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					var face_x := _rng.randf() < 0.5
					var yaw: float
					if face_x:
						yaw = PI * 0.5 * sx
					else:
						yaw = 0.0 if sz > 0 else PI
					var pos := c + Vector3(sx * q * 0.5, 0, sz * q * 0.5)
					match kind:
						"downtown":
							_place_building(Assets.DOWNTOWN[_rng.randi() % Assets.DOWNTOWN.size()], pos, yaw, 22.0)
						"suburban":
							_place_building(Assets.SUBURBAN[_rng.randi() % Assets.SUBURBAN.size()], pos, yaw, 15.0)
						_:
							_place_building(Assets.COMMERCIAL[_rng.randi() % Assets.COMMERCIAL.size()], pos, yaw, 21.0)

# ------------------------------------------------------------------ street lights
func _near_intersection(t: float) -> bool:
	for r in roads:
		if absf(t - r) < ROAD_HALF + 5.0:
			return true
	return false

func _build_street_lights() -> void:
	var lamp_scene := Util.instance_model(Assets.STREET_LIGHT)
	var lamp_mesh := Util.first_mesh(lamp_scene)
	lamp_scene.free()
	var xforms: Array[Transform3D] = []
	var head_local := Vector3(0, 0.585, -0.19) * LAMP_SCALE
	for r in roads:
		for k in N_BLOCKS:
			for off in [20.0, 60.0]:
				var t: float = -HALF + CELL * k + off
				for side in [-1.0, 1.0]:
					var lat: float = r + side * (ROAD_HALF + 1.4)
					# road along X at z = r
					var yaw_x := 0.0 if side > 0 else PI
					var p1 := Vector3(t, CURB_H, lat)
					xforms.append(Transform3D(Basis(Vector3.UP, yaw_x).scaled(Vector3.ONE * LAMP_SCALE), p1))
					lamp_bulbs.append(p1 + Basis(Vector3.UP, yaw_x) * head_local)
					# road along Z at x = r
					var yaw_z := PI * 0.5 if side > 0 else -PI * 0.5
					var p2 := Vector3(lat, CURB_H, t)
					xforms.append(Transform3D(Basis(Vector3.UP, yaw_z).scaled(Vector3.ONE * LAMP_SCALE), p2))
					lamp_bulbs.append(p2 + Basis(Vector3.UP, yaw_z) * head_local)
	_add_pole_colliders(xforms, 0.18, 6.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lamp_mesh
	mm.instance_count = xforms.size()
	for idx in xforms.size():
		mm.set_instance_transform(idx, xforms[idx])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "StreetLights"
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# glowing bulbs
	var bulb := SphereMesh.new()
	bulb.radius = 0.32
	bulb.height = 0.3
	bulb.radial_segments = 8
	bulb.rings = 4
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	bm.mesh = bulb
	bm.instance_count = lamp_bulbs.size()
	for idx in lamp_bulbs.size():
		bm.set_instance_transform(idx, Transform3D(Basis(), lamp_bulbs[idx] + Vector3(0, -0.12, 0)))
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = bm
	bmi.material_override = _bulb_mat
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bmi)
	# pooled real lights that follow the camera at night
	for n in 8:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.8, 0.55)
		l.omni_range = 15.0
		l.light_energy = 0.0
		l.omni_attenuation = 1.2
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append(l)

func set_night(f: float) -> void:
	_night = f
	_bulb_mat.emission_energy_multiplier = f * 6.0
	_bulb_mat.albedo_color = Color(1, 0.95, 0.8).lerp(Color(1, 0.9, 0.6), f)

func _process(delta: float) -> void:
	_light_timer -= delta
	if _light_timer > 0.0:
		return
	_light_timer = 0.25
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var on := _night > 0.05
	var cp := cam.global_position
	if not on:
		for l in _lights:
			l.visible = false
		return
	# pick the 8 closest bulbs (simple partial selection)
	var best: Array = []
	for idx in lamp_bulbs.size():
		var d := cp.distance_squared_to(lamp_bulbs[idx])
		if d > 90.0 * 90.0:
			continue
		if best.size() < _lights.size():
			best.append([d, idx])
			best.sort_custom(func(a, b): return a[0] < b[0])
		elif d < best[-1][0]:
			best[-1] = [d, idx]
			best.sort_custom(func(a, b): return a[0] < b[0])
	for n in _lights.size():
		var l := _lights[n]
		if n < best.size():
			l.visible = true
			l.global_position = lamp_bulbs[best[n][1]] + Vector3(0, -0.6, 0)
			l.light_energy = 2.2 * _night
		else:
			l.visible = false

# ------------------------------------------------------------------ trees & props
## Thin cylinder colliders (layer 8: hit by player/cars, ignored by the camera arm).
func _add_pole_colliders(xforms: Array, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	add_child(body)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	for xf in xforms:
		var p: Vector3 = xf.origin
		if absf(p.x) > HALF + 12.0 or absf(p.z) > HALF + 12.0:
			continue
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = p + Vector3(0, height * 0.5, 0)
		body.add_child(cs)

func _multimesh(path: String, xforms: Array, shadows := true) -> void:
	if xforms.is_empty():
		return
	var scene := Util.instance_model(path)
	var mesh := Util.first_mesh(scene)
	scene.free()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for idx in xforms.size():
		mm.set_instance_transform(idx, xforms[idx])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _tree_xf(p: Vector3, base := 10.0) -> Transform3D:
	var s := base * _rng.randf_range(0.8, 1.25)
	return Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p)

func _build_trees() -> void:
	var large: Array = []
	var small: Array = []
	var planters: Array = []
	for r in roads:
		for k in N_BLOCKS:
			var t: float = -HALF + CELL * k + 40.0
			for side in [-1.0, 1.0]:
				var lat: float = r + side * (ROAD_HALF + SIDEWALK - 1.0)
				if absf(lat) > HALF:   # outer side of the ring roads has no sidewalk
					continue
				large.append(_tree_xf(Vector3(t, CURB_H, lat)))
				large.append(_tree_xf(Vector3(lat, CURB_H, t)))
				planters.append(Transform3D(Basis().scaled(Vector3.ONE * 4.0), Vector3(t + 10.0, CURB_H, lat)))
				planters.append(Transform3D(Basis().scaled(Vector3.ONE * 4.0), Vector3(lat, CURB_H, t - 10.0)))
	# park block
	var pc := block_center(3, 1)
	for n in 26:
		var p := pc + Vector3(_rng.randf_range(-26, 26), CURB_H, _rng.randf_range(-26, 26))
		if _rng.randf() < 0.6:
			large.append(_tree_xf(p, 11.0))
		else:
			small.append(_tree_xf(p, 10.0))
	# suburban yards
	for bi in [[0, 0], [4, 4], [0, 4], [4, 0]]:
		var c := block_center(bi[0], bi[1])
		for n in 6:
			small.append(_tree_xf(c + Vector3(_rng.randf_range(-27, 27), CURB_H, _rng.randf_range(-27, 27)), 9.0))
	# tree belt outside the city (hides the edge of the world)
	for n in 140:
		var a := _rng.randf() * TAU
		var dist := _rng.randf_range(222.0, 300.0)
		var p := Vector3(cos(a), 0, sin(a)) * dist
		p.x = clampf(p.x, -300, 300)
		p.z = clampf(p.z, -300, 300)
		large.append(_tree_xf(p, _rng.randf_range(12.0, 18.0)))
	_add_pole_colliders(large, 0.3, 3.0)
	_multimesh(Assets.TREE_LARGE, large)
	_multimesh(Assets.TREE_SMALL, small)
	_multimesh(Assets.PLANTER, planters, false)

func _build_props() -> void:
	var tl: Array = []
	var dump: Array = []
	for i in range(1, 5):
		for j in range(1, 5):
			var x := roads[i]
			var z := roads[j]
			for c in [Vector2(1, 1), Vector2(-1, -1)]:
				var p := Vector3(x + c.x * (ROAD_HALF + 1.0), CURB_H, z + c.y * (ROAD_HALF + 1.0))
				tl.append(Transform3D(Basis(Vector3.UP, atan2(c.x, c.y)).scaled(Vector3.ONE * 10.0), p))
	for n in 18:
		var bi := _rng.randi() % N_BLOCKS
		var bj := _rng.randi() % N_BLOCKS
		var c := block_center(bi, bj)
		dump.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * 3.0), c + Vector3(_rng.randf_range(-30, 30), CURB_H, 31.0 * (1 if _rng.randf() < 0.5 else -1))))
	_multimesh(Assets.TRAFFIC_LIGHT, tl)
	_multimesh(Assets.DUMPSTER, dump)

func _build_bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "WorldBounds"
	add_child(body)
	var lim := HALF + ROAD_HALF + 6.0
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(2, 20, lim * 2.0) if d.x != 0 else Vector3(lim * 2.0, 20, 2)
		cs.shape = b
		cs.position = d * lim + Vector3(0, 10, 0)
		body.add_child(cs)

# ------------------------------------------------------------------ quality
func apply_quality(q: int) -> void:
	var ranges := [170.0, 260.0, 380.0, 520.0]
	for n in _building_geoms:
		Util.set_visibility_range(n, ranges[q], q >= 1)

# ------------------------------------------------------------------ helpers for AI
## Rectangle loop on road centre lines (indices into roads), as lane-offset waypoints.
func lane_loop(i0: int, j0: int, i1: int, j1: int, clockwise: bool) -> PackedVector3Array:
	var pts := [Vector3(roads[i0], 0, roads[j0]), Vector3(roads[i1], 0, roads[j0]),
		Vector3(roads[i1], 0, roads[j1]), Vector3(roads[i0], 0, roads[j1])]
	if not clockwise:
		pts.reverse()
	var out := PackedVector3Array()
	var n := pts.size()
	for k in n:
		var prev: Vector3 = pts[(k - 1 + n) % n]
		var cur: Vector3 = pts[k]
		var nxt: Vector3 = pts[(k + 1) % n]
		var d1 := (cur - prev).normalized()
		var d2 := (nxt - cur).normalized()
		var r1 := d1.cross(Vector3.UP)
		var r2 := d2.cross(Vector3.UP)
		out.append(cur + r1 * LANE + r2 * LANE)
	return out

## Sidewalk loop around block (i, j) for pedestrians.
func sidewalk_loop(i: int, j: int, clockwise: bool) -> PackedVector3Array:
	var c := block_center(i, j)
	var h := (CELL - ROAD_HALF * 2.0) * 0.5 - 1.8
	var pts := PackedVector3Array([c + Vector3(-h, CURB_H, -h), c + Vector3(h, CURB_H, -h),
		c + Vector3(h, CURB_H, h), c + Vector3(-h, CURB_H, h)])
	if not clockwise:
		pts.reverse()
	return pts
