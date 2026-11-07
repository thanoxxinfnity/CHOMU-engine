extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/character_controller_slope_sliding.gd")

func run(t: Node) -> void:
	var system := Impl.new()
	
	# Test 1: Flat ground should not cause sliding
	var vel1 := Vector3.ZERO
	var normal_flat := Vector3.UP
	vel1 = system.calculate_velocity(0.016, vel1, normal_flat, true)
	t.check("S-66 flat ground no slide", vel1 == Vector3.ZERO, "Character should not slide on flat ground")
	t.check("S-66 flat ground state", system.state.is_sliding == false, "State should not be sliding")

	# Test 2: Steep slope should trigger sliding
	var vel2 := Vector3.ZERO
	# 45 degree slope (approx)
	var normal_steep := Vector3(0.707, 0.707, 0).normalized() 
	# Run for a few frames to accumulate velocity
	for i in range(10):
		vel2 = system.calculate_velocity(0.1, vel2, normal_steep, true)
	
	t.check("S-66 steep slope slide", vel2.length() > 0, "Character should have acquired velocity on steep slope")
	t.check("S-66 steep slope state", system.state.is_sliding == true, "State should be sliding")
	t.check("S-66 slide direction", vel2.dot(Vector3.UP) <= 0, "Slide velocity should be pointing downwards or horizontal")

	# Test 3: Walkable slope should not slide
	var vel3 := Vector3.ZERO
	# Very slight slope (e.g. 10 degrees)
	var normal_shallow := Vector3(0.17, 0.98, 0).normalized()
	vel3 = system.calculate_velocity(0.1, vel3, normal_shallow, true)
	t.check("S-66 shallow slope no slide", vel3 == Vector3.ZERO, "Character should not slide on shallow slope")

	# Test 4: Air state should reset sliding
	system.state.is_sliding = true
	system.state.slide_velocity = Vector3(10, 0, 10)
	var vel4 := Vector3.ZERO
	vel4 = system.calculate_velocity(0.1, vel4, Vector3.UP, false) # is_grounded = false
	t.check("S-66 air reset slide", system.state.is_sliding == false, "Sliding should stop when not grounded")
	t.check("S-66 air velocity reset", system.state.slide_velocity == Vector3.ZERO, "Slide velocity should be zeroed in air")

	# Test 5: Save/Load state
	var system2 := Impl.new()
	system.state.slide_velocity = Vector3(1, 2, 3)
	system.state.is_sliding = true
	var data := system.save_state()
	system2.load_state(data)
	t.check("S-66 save state vel", system2.state.slide_velocity == Vector3(1, 2, 3), "Loaded velocity should match")
	t.check("S-66 save state bool", system2.state.is_sliding == true, "Loaded sliding state should match")
