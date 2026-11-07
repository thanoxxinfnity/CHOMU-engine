extends RefCounted

const Impl := preload("res://addons/chomu_systems/rendering/hlod.gd")

func run(t: Node) -> void:
	var hlod: ChomuHLOD = Impl.new()
	t.add_child(hlod)
	
	# Create three box MeshInstance3D children
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(2, 2, 2)
	
	var mi1: MeshInstance3D = MeshInstance3D.new()
	mi1.mesh = box_mesh.duplicate()
	mi1.position = Vector3(-5, 0, 0)
	hlod.add_child(mi1)
	
	var mi2: MeshInstance3D = MeshInstance3D.new()
	mi2.mesh = box_mesh.duplicate()
	mi2.position = Vector3(0, 0, 0)
	hlod.add_child(mi2)
	
	var mi3: MeshInstance3D = MeshInstance3D.new()
	mi3.mesh = box_mesh.duplicate()
	mi3.position = Vector3(5, 0, 0)
	hlod.add_child(mi3)
	
	# Build proxy
	hlod.build_proxy()
	await t.physics_frames(1)
	
	# Test 1: Proxy vertex count equals sum of originals (3 boxes * 24 verts = 72)
	# BoxMesh has 24 vertices (6 faces * 4 verts, no index sharing in Godot's BoxMesh)
	var expected_verts: int = 3 * 24
	var proxy_verts: int = hlod.get_proxy_vertex_count()
	t.check("F-16 proxy vertex count matches sum", proxy_verts == expected_verts,
		"proxy verts %d vs expected %d" % [proxy_verts, expected_verts])
	
	# Test 2: At distance < hlod_distance, level 0 (originals visible)
	hlod.hlod_distance = 50.0
	hlod.impostor_distance = 200.0
	hlod.update_lod(Vector3(0, 0, 0))  # dist = 0
	await t.physics_frames(1)
	t.check("F-16 level 0 at close distance", hlod.level() == 0,
		"level %d at dist 0" % hlod.level())
	
	# Test 3: At distance between hlod_distance and impostor_distance, level 1 (proxy)
	hlod.update_lod(Vector3(100, 0, 0))  # dist = 100
	await t.physics_frames(1)
	t.check("F-16 level 1 at mid distance", hlod.level() == 1,
		"level %d at dist 100" % hlod.level())
	
	# Test 4: At distance > impostor_distance, level 2 (impostor) if texture provided
	# Create a dummy texture for impostor
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 1))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	hlod.impostor_texture = tex
	hlod._build_impostor()
	
	hlod.update_lod(Vector3(300, 0, 0))  # dist = 300
	await t.physics_frames(1)
	t.check("F-16 level 2 at far distance with impostor", hlod.level() == 2,
		"level %d at dist 300" % hlod.level())
	
	# Test 5: Hysteresis - approaching hlod_distance from far side stays at level 1
	hlod.update_lod(Vector3(52, 0, 0))  # dist = 52, hlod_distance*(1+hys)=52.5, so 52 < 52.5 -> stay level 1
	await t.physics_frames(1)
	t.check("F-16 hysteresis holds level 1 at 52", hlod.level() == 1,
		"level %d at dist 52 (hysteresis)" % hlod.level())
	
	# Test 6: Hysteresis - going back below 47.5 switches to level 0
	hlod.update_lod(Vector3(40, 0, 0))  # dist = 40 < 47.5
	await t.physics_frames(1)
	t.check("F-16 hysteresis switches to level 0 at 40", hlod.level() == 0,
		"level %d at dist 40" % hlod.level())
	
	# Test 7: Hysteresis - at level 0, need dist > 52.5 to switch to level 1
	hlod.update_lod(Vector3(51, 0, 0))  # dist = 51 < 52.5
	await t.physics_frames(1)
	t.check("F-16 hysteresis holds level 0 at 51", hlod.level() == 0,
		"level %d at dist 51" % hlod.level())
	
	hlod.update_lod(Vector3(53, 0, 0))  # dist = 53 > 52.5
	await t.physics_frames(1)
	t.check("F-16 hysteresis switches to level 1 at 53", hlod.level() == 1,
		"level %d at dist 53" % hlod.level())
	
	# Test 8: Without impostor texture, far distance stays at proxy (level 1)
	var hlod2: ChomuHLOD = Impl.new()
	t.add_child(hlod2)
	var mi4: MeshInstance3D = MeshInstance3D.new()
	mi4.mesh = box_mesh.duplicate()
	hlod2.add_child(mi4)
	hlod2.hlod_distance = 50.0
	hlod2.impostor_distance = 200.0
	hlod2.build_proxy()
	await t.physics_frames(1)
	
	hlod2.update_lod(Vector3(300, 0, 0))
	await t.physics_frames(1)
	t.check("F-16 no impostor stays at level 1", hlod2.level() == 1,
		"level %d at dist 300 without impostor" % hlod2.level())
	
	# Cleanup
	hlod.queue_free()
	hlod2.queue_free()
