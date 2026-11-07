extends RefCounted
const Impl := preload("res://addons/chomu_systems/physics/bone_chain.gd")

func run(t: Node) -> void:
	t.check("F-55 pick_mode tier 0", Impl.pick_mode(0) == "bone_chain", "tier 0 -> bone_chain")
	t.check("F-55 pick_mode tier 1", Impl.pick_mode(1) == "bone_chain", "tier 1 -> bone_chain")
	t.check("F-55 pick_mode tier 2", Impl.pick_mode(2) == "soft_body", "tier 2 -> soft_body")
	t.check("F-55 pick_mode tier 3", Impl.pick_mode(3) == "soft_body", "tier 3 -> soft_body")
	
	var chain = Impl.new()
	t.add_child(chain)
	
	var joints: Array[Node3D] = []
	for i in range(5):
		var joint = Node3D.new()
		joint.name = "joint_%d" % i
		t.add_child(joint)
		joint.position = Vector3(0, 5.0 - i, 0)
		joints.append(joint)
	
	chain.set_joints(joints)
	chain.gravity = Vector3(0, -9.81, 0)
	chain.damping = 0.02
	chain.stiffness = 0.0
	chain.constraint_iterations = 10
	chain.anchor_root = true
	
	await t.physics_frames(120)
	
	var positions = chain.get_joint_positions()
	var lengths_ok = true
	for i in range(1, positions.size()):
		var len = (positions[i] - positions[i - 1]).length()
		var error = abs(len - 1.0) / 1.0
		if error > 0.02:
			lengths_ok = false
			break
	t.check("F-55 segment lengths within 2%", lengths_ok, "all segments ~1.0 unit after fall")
	
	t.check("F-55 root anchored", positions[0].distance_to(Vector3(0, 5.0, 0)) < 0.01, "root at (0,5,0)")
	
	chain.stiffness = 1.0
	chain.gravity = Vector3.ZERO
	await t.physics_frames(30)
	
	positions = chain.get_joint_positions()
	var rest_ok = true
	for i in range(positions.size()):
		var expected = Vector3(0, 5.0 - i, 0)
		if positions[i].distance_to(expected) > 0.05:
			rest_ok = false
			break
	t.check("F-55 stiffness 1 returns to rest", rest_ok, "joints back at rest positions")
	
	chain.stiffness = 0.0
	chain.gravity = Vector3.ZERO
	
	var collider_center = Node3D.new()
	collider_center.name = "collider"
	t.add_child(collider_center)
	collider_center.position = Vector3(0, 3.5, 0)
	chain.add_collider(collider_center, 1.5)
	
	for i in range(1, 4):
		chain._curr_positions[i] = Vector3(0, 3.5, 0)
		chain._prev_positions[i] = Vector3(0, 3.5, 0)
	
	await t.physics_frames(10)
	
	positions = chain.get_joint_positions()
	var collider_ok = true
	for i in range(1, 4):
		var dist = positions[i].distance_to(Vector3(0, 3.5, 0))
		if dist < 1.49:
			collider_ok = false
			break
	t.check("F-55 sphere collider pushes joints out", collider_ok, "joints outside radius 1.5")
	
	chain.queue_free()
	for j in joints:
		j.queue_free()
	collider_center.queue_free()
