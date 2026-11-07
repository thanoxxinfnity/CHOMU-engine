extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/rope_cable_verlet_integration.gd")

func run(t: Node) -> void:
	var rope = Impl.new()
	
	# Setup a simple 3-point vertical rope
	var points = [
		{"pos": Vector3(0, 10, 0), "pinned": true},
		{"pos": Vector3(0, 5, 0), "pinned": false},
		{"pos": Vector3(0, 0, 0), "pinned": false}
	]
	var constraints = [
		{"p1": 0, "p2": 1, "stiffness": 1.0},
		{"p1": 1, "p2": 2, "stiffness": 1.0}
	]
	rope.setup(points, constraints)
	
	# Test 1: Gravity effect
	rope.step(0.1)
	var pos_after_1 = rope.get_positions()
	t.check("S-27 Gravity pulls points down", pos_after_1[2].y < 0.0, "Point 2 should fall under gravity")
	t.check("S-27 Pinned point stays", pos_after_1[0].is_equal_approx(Vector3(0, 10, 0)), "Point 0 must remain at (0,10,0)")
	
	# Test 2: Constraint length maintenance
	for i in range(20):
		rope.step(0.016)
	
	var pos_final = rope.get_positions()
	var dist = pos_final[0].distance_to(pos_final[1])
	t.check("S-27 Constraint length maintained", abs(dist - 5.0) < 0.1, "Distance between p0 and p1 should be ~5.0")
	
	# Test 3: External force
	var initial_x = pos_final[2].x
	rope.apply_force(2, Vector3(100, 0, 0))
	rope.step(0.016)
	var pos_forced = rope.get_positions()
	t.check("S-27 External force moves point", pos_forced[2].x > initial_x, "Point 2 should move in +X direction")
	
	# Test 4: Save/Load state
	var state = rope.save_state()
	var rope2 = Impl.new()
	# Now load_state handles constraints internally
	rope2.load_state(state)
	
	var pos_saved = rope2.get_positions()
	t.check("S-27 State restoration", pos_saved[2].is_equal_approx(pos_forced[2]), "Restored point 2 position should match")
